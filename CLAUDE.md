# soroura.org — Project Context

Personal website for Ahmed Sorour. Static HTML + CSS, no build step, no JS framework.

## Stack

- Plain HTML files (one per page)
- Single `style.css` with CSS custom properties for theming
- Light/dark themes: follows `prefers-color-scheme`, with a manual toggle in the nav (see Design system)
- Hosted on a VPS: Cloudflare -> Nginx Proxy Manager -> `sorour-web` nginx container

## File structure

```
index.html       — homepage
about.html       — bio / timeline / beliefs
builds.html      — public builds (PSFH, PSFPC, BEC Hub); the rest are tracked in the owner's vault and released one at a time
writing.html     — field notes index
contact.html     — Say Hello (LinkedIn; no form)
style.css        — all styles
nginx.conf       — server block for the sorour-web container
deploy.sh        — server-side deploy (runs on the VPS)
.woodpecker.yml  — CI: check on every push/PR, deploy on push to main
scripts/         — release-manifest, build, link check, upload, install
my-bw.jpeg       — author photo
favicon.svg / favicon.ico / apple-touch-icon.png
```

Pages share a nav and footer copy-pasted into each HTML file. There's no template engine.

## Design system (in style.css) — "Steel Blue", October 2026

- Tokens are CSS variables: `--bg --surface --surface-2 --ink --ink-2 --ink-3 --rule --accent --accent-ink --accent-soft --signal --signal-soft --on-accent`
- **Themes:** light tokens on `:root`; dark tokens under `@media (prefers-color-scheme: dark) :root:not([data-theme="light"])` AND `:root[data-theme="dark"]`. Default follows the system; the nav button `.theme-toggle` sets `data-theme` on `<html>` and stores it in `localStorage` (`theme`). A tiny inline script in every `<head>` applies the stored choice before paint (no flash). Every page carries the same head script, toggle button and bottom script; copy them from `index.html` when adding a page.
- Accent: steel blue (`#356b93` light, `#8cb6d6` dark), chosen by Ahmed 2026-10-11 over a green first version. Amber `--signal` only for "current" timeline items and keyboard focus. Avoid WHO's own light blue so the site never reads as a WHO page.
- Type: `Newsreader` (headlines, article body) + `IBM Plex Sans` (UI and body), loaded by a `<link>` in each page head. Plex has an Arabic sibling for a future `/ar/`.
- Signature element: the "distance line" under the home headline (Training to Practice), drawn once on load. Keep boldness there; no hover lifts, no arrow glyphs, no all-caps labels.
- `prefers-reduced-motion` disables animation and transitions.
- Layout containers: `.container` (max 1080px) and `.container--narrow` (max 700px) for prose pages.

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

- Keep nav identical across all HTML files (current items: Builds, Writing, About, Say Hello, plus the theme toggle)
- The active page gets `class="active"` on its nav link
- Footer year is hardcoded — update once per year across all pages
- Voice and content tone is documented separately in `brand-voice-guidelines.md` — read it before writing copy
- Don't introduce a build step, framework, or JS bundler unless explicitly requested. The whole point is that this site is dead simple to edit and deploy.
