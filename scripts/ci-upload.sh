#!/bin/sh
# Build, check, ship a release to the VPS, run deploy.sh there, then verify
# the public site serves the new commit. Executed BY the Woodpecker runner
# (or by hand from a laptop with SSH access), never on the server.
#
# Plain OpenSSH streaming a tar archive rather than the drone-scp plugin: that
# plugin dies mid-transfer with "ssh: handshake failed: EOF", and it can only
# copy files over the target, never remove stale ones.
#
#     DRY_RUN=1 TARGET=x SSH_OPTS=x REMOTE=x sh scripts/ci-upload.sh
#
# Expects from the environment: TARGET, SSH_OPTS, REMOTE.
# Optional: PUBLIC_URL (default https://soroura.org, empty to skip the check).

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/release-manifest.sh"

: "${TARGET:?TARGET is not set}"
: "${SSH_OPTS:?SSH_OPTS is not set}"
: "${REMOTE:?REMOTE is not set}"
PUBLIC_URL="${PUBLIC_URL-https://soroura.org}"

# Catches the Woodpecker brace-expansion failure early: REMOTE="@" means the
# VPS_USER/VPS_HOST secrets were never populated.
case "$REMOTE" in
  @*|*@) echo "REMOTE looks unpopulated ('$REMOTE') - check the VPS_USER/VPS_HOST secrets"; exit 1 ;;
esac

sh "$ROOT/scripts/build-release.sh"
sh "$ROOT/scripts/check-site.sh" "$ROOT/build/release/site"
cd "$ROOT/build/release"
VERSION=$(cat site/version.txt)

missing=""
for path in $RELEASE_PATHS; do
  [ -e "$path" ] || missing="$missing $path"
done
if [ -n "$missing" ]; then
  echo "Release paths missing from build/release:$missing"
  exit 1
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "DRY RUN - release $VERSION validates. Would upload:"
  for path in $RELEASE_PATHS; do echo "    $path"; done
  exit 0
fi

# ONE SSH handshake for the whole release (connection multiplexing). This VPS
# gets constant brute-force traffic and sshd randomly drops new connections
# under MaxStartups; the second of several quick connections was the one that
# failed on sibling projects (2026-09-28).
MUX_DIR=$(mktemp -d /tmp/ssh-mux.XXXXXX)
SSH_OPTS="$SSH_OPTS -o ControlMaster=auto -o ControlPath=$MUX_DIR/cm -o ControlPersist=600"
close_mux() {
  # shellcheck disable=SC2086
  ssh $SSH_OPTS -O exit "$REMOTE" >/dev/null 2>&1 || true
  rm -rf "$MUX_DIR"
}
trap close_mux EXIT

# Precondition probe, which also opens the master connection.
# Exit 0 = ready, 1 = host lacks prerequisites, 255 = the CONNECTION failed
# (retried: 3 attempts, 15 s apart).
echo "-> Checking the VPS has docker and rsync..."
attempt=1
while :; do
  rc=0
  # shellcheck disable=SC2086
  ssh $SSH_OPTS "$REMOTE" "command -v docker >/dev/null && command -v rsync >/dev/null" || rc=$?
  if [ "$rc" -eq 0 ]; then
    break
  elif [ "$rc" -eq 1 ]; then
    echo "The VPS is missing docker or rsync - see DEPLOY.md"
    exit 1
  elif [ "$attempt" -ge 3 ]; then
    echo "SSH connection to the VPS failed (exit $rc) after $attempt attempts - see the ssh error above."
    echo "If VPS_HOST is the public IP, note the Woodpecker agent runs ON this VPS: try 172.17.0.1."
    exit 1
  fi
  echo "   SSH connection failed (exit $rc), retrying in 15 s (attempt $attempt of 3)..."
  attempt=$((attempt + 1))
  sleep 15
done

echo "-> Creating staging directory on the VPS..."
# shellcheck disable=SC2086
STAGE=$(ssh $SSH_OPTS "$REMOTE" 'mktemp -d /tmp/sorour-release.XXXXXX')
[ -n "$STAGE" ] || { echo "Failed to create a staging directory"; exit 1; }
echo "   staging at $STAGE"

cleanup() {
  # shellcheck disable=SC2086
  ssh $SSH_OPTS "$REMOTE" "rm -rf '$STAGE'" >/dev/null 2>&1 || true
  close_mux
}
trap cleanup EXIT

echo "-> Streaming release $VERSION to the VPS..."
# shellcheck disable=SC2086
tar czf - $RELEASE_PATHS | ssh $SSH_OPTS "$REMOTE" "tar xzf - -C '$STAGE'"

echo "-> Installing release into $TARGET..."
# shellcheck disable=SC2086
ssh $SSH_OPTS "$REMOTE" "sh '$STAGE/scripts/install-release.sh' '$STAGE' '$TARGET'"

echo "-> Running deploy..."
# shellcheck disable=SC2086
ssh $SSH_OPTS "$REMOTE" "cd '$TARGET' && sh ./deploy.sh"

if [ -n "$PUBLIC_URL" ]; then
  echo "-> Verifying $PUBLIC_URL serves $VERSION..."
  served=""
  for i in 1 2 3 4 5 6; do
    # Unique query string so Cloudflare cannot answer from cache.
    served=$(curl -fsS --max-time 10 "$PUBLIC_URL/version.txt?ci=$VERSION-$i" 2>/dev/null || true)
    [ "$served" = "$VERSION" ] && break
    sleep 5
  done
  if [ "$served" != "$VERSION" ]; then
    echo "Public site serves '${served:-nothing}', expected '$VERSION'."
    echo "The origin passed its health check, so look at Nginx Proxy Manager / Cloudflare, not the deploy."
    exit 1
  fi
  echo "   public site is on $VERSION"
fi

echo "Release $VERSION complete"
