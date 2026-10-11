# soroura.org — Project Context

Personal website for Ahmed Sorour. Static HTML + CSS, no build step, no JS framework.

## Stack

- Plain HTML files (one per page)
- Single `style.css` with CSS custom properties for theming
- Light/dark mode via `prefers-color-scheme`
- Hosted on a VPS: Cloudflare -> Nginx Proxy Manager -> `sorour-web` nginx container

## File structure

```
index.html       — homepage
about.html       — bio / timeline / beliefs
builds.html      — projects (SimReady, NAP)
writing.html     — field notes index
contact.html     — contact form
style.css        — all styles
nginx.conf       — server block for the sorour-web container
deploy.sh        — server-side deploy (runs on the VPS)
.woodpecker.yml  — CI: check on every push/PR, deploy on push to main
scripts/         — release-manifest, build, link check, upload, install
my-bw.jpeg       — author photo
favicon.svg / favicon.ico / apple-touch-icon.png
```

Pages share a nav and footer copy-pasted into each HTML file. There's no template engine.

## Design system (in style.css)

- Tokens defined as CSS variables under `:root` (light) and `@media (prefers-color-scheme: dark)`
- Accent color is red (`--accent: #dc2626` light, `#ef4444` dark) — used sparingly, mainly for links and the "ABOUT"-style section labels
- Display font: `DM Serif Display` (headlines)
- Body font: `Inter`
- Layout containers: `.container` (max 1080px) and `.container--narrow` (max 720px) for prose pages

## Deployment

**Push to `main` deploys.** Woodpecker (`pipeline.agozo.xyz`, repo `soroura/web`) runs:

1. `check` — `scripts/build-release.sh` assembles `build/release/site/` (only files matching `SITE_FILES` in `scripts/release-manifest.sh`, plus `version.txt` = commit SHA), then `scripts/check-site.sh` fails on any broken local link, missing `<title>`, or pages disagreeing on `style.css?v=`.
2. `deploy` — `scripts/ci-upload.sh` streams the release over plain OpenSSH to a `/tmp` staging dir, `install-release.sh` replaces the CI-owned paths in `/opt/web/`, and `deploy.sh` mirrors `site/` into `/var/www/sorour/` (`rsync --delete`, so deleted files disappear), keeps the `sorour-web` container serving it, and health-checks `127.0.0.1:8090`. The step ends by confirming `https://soroura.org/version.txt` shows the pushed SHA.

New pages and images deploy automatically (globs in `release-manifest.sh`). `*.md`, scripts and `.git` are never served.

**Which commit is live:** `curl https://soroura.org/version.txt`

**Run locally:** `sh scripts/build-release.sh && sh scripts/check-site.sh build/release/site`

**Redeploy by hand on the VPS** (no CI needed): `cd /opt/web && sh ./deploy.sh`

**Serving layer on the VPS (`root@217.76.56.188`):** system nginx is *not* used (inactive). Nginx Proxy Manager (proxy host for `soroura.org`) forwards to `217.76.56.188:8090` → container `sorour-web` (`nginx:1.29-alpine`), which mounts `/var/www/sorour` read-only and `/etc/sorour-web/default.conf` (installed from the repo's `nginx.conf`). `deploy.sh` recreates the container only if its spec (image, port, mounts) changes, rolling back to the previous container if the new one fails its health check; a config-only change just reloads nginx.

Don't push to `main` while a pipeline is running — the newer push cancels it.

## Cloudflare gotcha (critical)

**The site is behind Cloudflare with `cache-control: max-age=14400` on static assets.** This means after deploying CSS or image changes, browsers and Cloudflare edges will serve the OLD version for up to 4 hours.

**Fix: bump the version query string in every HTML's CSS link** when editing `style.css`:

```html
<link rel="stylesheet" href="style.css?v=2">  <!-- bump to ?v=3, ?v=4, etc. -->
```

Use a single `sed` to bump all pages at once:
```bash
sed -i '' 's|style.css?v=N|style.css?v=N+1|g' *.html
```

If you forget and need an immediate fix: purge Cloudflare cache via dashboard → Caching → Purge Everything.

## Conventions

- Keep nav identical across all HTML files (current items: Builds, Field Notes, About, Say Hello)
- The active page gets `class="active"` on its nav link
- Footer year is hardcoded — update once per year across all pages
- Voice and content tone is documented separately in `brand-voice-guidelines.md` — read it before writing copy
- Don't introduce a build step, framework, or JS bundler unless explicitly requested. The whole point is that this site is dead simple to edit and deploy.
