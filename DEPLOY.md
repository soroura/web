# Deployment: soroura.org

Push to `main`. Woodpecker CI builds, checks and deploys; nothing is run by hand.

## How a deploy works

```
git push (main)
  -> Woodpecker "check":  build-release.sh -> check-site.sh   (also runs on PRs)
  -> Woodpecker "deploy": ci-upload.sh
       ssh -> mktemp /tmp/sorour-release.XXXX
       tar stream: site/ deploy.sh nginx.conf scripts/
       install-release.sh  -> replaces those paths in /opt/web (nothing else)
       deploy.sh           -> nginx -t, rsync site/ -> /var/www/sorour,
                              keep container sorour-web serving it,
                              health-check 127.0.0.1:8090
       curl https://soroura.org/version.txt == commit SHA
```

| Path / name | What it is |
|---|---|
| `scripts/release-manifest.sh` | `SITE_FILES` globs (what gets served), `REQUIRED_FILES`, `RELEASE_PATHS` |
| `/opt/web/` | Last release: `site/`, `deploy.sh`, `nginx.conf`, `scripts/`. Other files there are leftovers and are ignored |
| `/var/www/sorour/` | Webroot: an exact mirror of `site/` |
| `/etc/sorour-web/default.conf` | Live nginx config, copied from the repo's `nginx.conf` |
| `sorour-web` | `nginx:1.29-alpine` container on port 8090, webroot mounted read-only |
| Nginx Proxy Manager | Terminates TLS for `soroura.org`, forwards to `217.76.56.188:8090` |

## Woodpecker secrets (repo settings)

| Secret | Value |
|---|---|
| `VPS_HOST` | VPS address. The agent runs on this VPS; if SSH to the public IP fails from CI, use `172.17.0.1` |
| `VPS_USER` | `root` |
| `VPS_SSH_KEY` | Private key whose public half is in `/root/.ssh/authorized_keys` |

## Common tasks

```bash
# Which commit is live?
curl https://soroura.org/version.txt

# Check the site locally before pushing
sh scripts/build-release.sh && sh scripts/check-site.sh build/release/site

# Deploy from a laptop with root SSH access (same path CI uses)
TARGET=/opt/web REMOTE=root@217.76.56.188 SSH_OPTS="-o BatchMode=yes" sh scripts/ci-upload.sh

# Re-run the last deploy on the VPS
ssh root@217.76.56.188 'cd /opt/web && sh ./deploy.sh'
```

## Troubleshooting

- **Deploy step fails at SSH** (`Connection closed`, `kex_exchange_identification`): `ci-upload.sh` already retries 3 times. If it still fails, set `VPS_HOST` to `172.17.0.1`, because a container on the VPS cannot reliably reach the VPS's own public IP.
- **`missing VPS deployment secret`**: a secret name doesn't match the UI exactly, or the secret isn't enabled for this event (push/manual).
- **Health check passes but the public check fails**: the origin is fine. Look at the Nginx Proxy Manager proxy host for `soroura.org` or at Cloudflare, not at the deploy.
- **CSS change not visible**: bump `style.css?v=N` on every page (`check-site.sh` fails if the pages disagree).
- **Container broken**: `docker logs sorour-web`. Rerunning `deploy.sh` recreates it if it's missing.
