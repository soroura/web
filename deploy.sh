#!/bin/sh
# Publish a release and keep the sorour-web container serving it.
# Runs ON THE VPS as root, invoked by scripts/ci-upload.sh after the release
# has been installed into /opt/web. Safe to rerun by hand:
#
#     cd /opt/web && sh ./deploy.sh
#
# Serving path:
#   Cloudflare -> Nginx Proxy Manager -> :8090 -> sorour-web (nginx container)
#   -> WEBROOT, bind-mounted read-only. Only site files ever land in WEBROOT.
#
# Steps: validate the release -> nginx -t the new config -> mirror site/ into
# WEBROOT -> recreate the container if its spec changed (rolling back on
# failure), otherwise reload it -> health-check through the serving port.

set -eu

APP_DIR="${APP_DIR:-$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)}"
WEBROOT="${WEBROOT:-/var/www/sorour}"
CONF_DIR="${CONF_DIR:-/etc/sorour-web}"
CONTAINER="${CONTAINER:-sorour-web}"
IMAGE="${IMAGE:-nginx:1.29-alpine}"
HOST_PORT="${HOST_PORT:-8090}"
HEALTH="${HEALTH:-http://127.0.0.1:$HOST_PORT}"

SRC="$APP_DIR/site"
CONF_FILE="$CONF_DIR/default.conf"
# Any change here recreates the container; a config-only change just reloads.
SPEC="$IMAGE|$HOST_PORT|$WEBROOT|$CONF_FILE"

log() { echo "[deploy] $*"; }
die() { echo "[deploy] ERROR: $*" >&2; exit 1; }

dump_logs() {
  echo "----- containers -----"
  docker ps -a --filter "name=$CONTAINER" --format '{{.Names}}  {{.Status}}  {{.Ports}}' || true
  echo "----- $CONTAINER logs -----"
  docker logs --tail 40 "$CONTAINER" 2>&1 || true
}

# --- 1. Validate before touching anything -----------------------------------

for d in "$WEBROOT" "$CONF_DIR"; do
  case "$d" in
    /*) ;;
    *) die "path must be absolute: '$d'" ;;
  esac
  case "$d" in
    /|/root|/home|/etc|/usr|/var|/var/www|/srv|/tmp|/opt)
      die "refusing unsafe path: '$d'" ;;
  esac
done

for cmd in docker rsync curl; do
  command -v "$cmd" >/dev/null || die "$cmd is not installed"
done

# An empty or partial source would make rsync --delete wipe the live site.
[ -f "$SRC/index.html" ] || die "no $SRC/index.html - refusing to publish an incomplete release"
[ -f "$SRC/version.txt" ] || die "no $SRC/version.txt"
[ -f "$APP_DIR/nginx.conf" ] || die "no $APP_DIR/nginx.conf"
VERSION=$(cat "$SRC/version.txt")
log "Publishing release $VERSION"

# --- 2. Test the new nginx config in a throwaway container -------------------

log "Testing nginx.conf with $IMAGE..."
docker run --rm --entrypoint nginx \
  -v "$APP_DIR/nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
  -v "$SRC:/usr/share/nginx/html:ro" \
  "$IMAGE" -t -q \
  || die "nginx.conf failed nginx -t - live site untouched"

# --- 3. Mirror the site ------------------------------------------------------

mkdir -p "$WEBROOT" "$CONF_DIR"
log "Mirroring $SRC/ -> $WEBROOT/"
# --delete removes files dropped from the repo; --delay-updates swaps the new
# files in at the end instead of serving a half-copied tree.
rsync -a --delete --delay-updates --chmod=D755,F644 "$SRC/" "$WEBROOT/"

conf_changed=0
if ! cmp -s "$APP_DIR/nginx.conf" "$CONF_FILE"; then
  # Overwrite IN PLACE: the container bind-mounts this file's inode, so a
  # rm + cp would leave nginx reading the old, deleted file.
  cat "$APP_DIR/nginx.conf" > "$CONF_FILE"
  conf_changed=1
  log "nginx config updated"
fi

# --- 4. Container ------------------------------------------------------------

healthy() {
  served=""
  i=0
  while [ "$i" -lt 15 ]; do
    served=$(curl -fsS --max-time 3 "$HEALTH/version.txt" 2>/dev/null || true)
    [ "$served" = "$VERSION" ] && return 0
    i=$((i + 1))
    sleep 1
  done
  echo "[deploy] $HEALTH/version.txt served '${served:-nothing}', expected '$VERSION'" >&2
  return 1
}

run_container() {
  docker run -d --name "$CONTAINER" --restart unless-stopped \
    --label "sorour.spec=$SPEC" \
    -p "$HOST_PORT:80" \
    -v "$WEBROOT:/usr/share/nginx/html:ro" \
    -v "$CONF_FILE:/etc/nginx/conf.d/default.conf:ro" \
    "$IMAGE" >/dev/null
}

current=$(docker inspect -f '{{index .Config.Labels "sorour.spec"}}' "$CONTAINER" 2>/dev/null || echo absent)

if [ "$current" != "$SPEC" ]; then
  log "Container spec changed ('$current' -> '$SPEC') - recreating $CONTAINER"
  previous=""
  if docker inspect "$CONTAINER" >/dev/null 2>&1; then
    previous="$CONTAINER-previous"
    docker rm -f "$previous" >/dev/null 2>&1 || true
    docker stop "$CONTAINER" >/dev/null
    docker rename "$CONTAINER" "$previous"
  fi
  if run_container && healthy; then
    if [ -n "$previous" ]; then docker rm "$previous" >/dev/null; fi
    log "Container recreated"
  else
    dump_logs
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    if [ -n "$previous" ]; then
      docker rename "$previous" "$CONTAINER"
      docker start "$CONTAINER" >/dev/null
      die "new container failed its health check - previous container restored"
    fi
    die "new container failed its health check"
  fi
else
  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
    log "Container was stopped - starting it"
    docker start "$CONTAINER" >/dev/null
  elif [ "$conf_changed" = 1 ]; then
    log "Reloading nginx"
    docker exec "$CONTAINER" nginx -s reload
  fi
fi

# --- 5. Health check through the serving port --------------------------------

healthy || { dump_logs; die "health check failed"; }

curl -fsS --max-time 5 "$HEALTH/" | cmp -s - "$SRC/index.html" \
  || { dump_logs; die "served / differs from the release's index.html"; }

for path in .git/config deploy.sh nginx.conf CLAUDE.md; do
  code=$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "$HEALTH/$path")
  [ "$code" = "404" ] || die "/$path answers HTTP $code - only site files may be served"
done

log "Release $VERSION is live on $HEALTH"
