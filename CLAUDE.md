# soroura.org — Project Context

Personal website for Ahmed Sorour. Static HTML + CSS, no build step, no JS framework.

## Stack

- Plain HTML files (one per page)
- Single `style.css` with CSS custom properties for theming
- Light/dark mode via `prefers-color-scheme`
- Hosted on a VPS, served by Nginx, fronted by Cloudflare

## File structure

```
index.html       — homepage
about.html       — bio / timeline / beliefs
builds.html      — projects (SimReady, NAP)
writing.html     — field notes index
contact.html     — contact form
style.css        — all styles
nginx.conf       — Nginx site config (template)
deploy.sh        — deployment script
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

VPS: `root@217.76.56.188`. Repo lives at `/opt/web/`. Nginx serves from `/var/www/sorour/` (not directly from the repo).

**To deploy after local changes:**
```bash
git add . && git commit -m "..." && git push

# on VPS
cd /opt/web && git pull && sudo ./deploy.sh
```

`deploy.sh` uses `rsync` to mirror the repo into `/var/www/sorour/`, excluding `.git/`, `*.md`, `deploy.sh`, and `nginx.conf`. Any new HTML/CSS/image file is picked up automatically — no need to edit `deploy.sh` when adding files.

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

## Nginx config caveat

There's a sibling site config at `/etc/nginx/sites-enabled/psfh` that has broken SSL (listens on 443 with no cert). When this is broken, `nginx -t` fails and `sudo systemctl reload nginx` silently doesn't reload. If a deploy doesn't seem to take effect, check:

```bash
sudo nginx -t
```

If it fails for `psfh`, either fix that site's SSL or remove `/etc/nginx/sites-enabled/psfh` until it's needed.

## Conventions

- Keep nav identical across all HTML files (current items: Builds, Field Notes, About, Say Hello)
- The active page gets `class="active"` on its nav link
- Footer year is hardcoded — update once per year across all pages
- Voice and content tone is documented separately in `brand-voice-guidelines.md` — read it before writing copy
- Don't introduce a build step, framework, or JS bundler unless explicitly requested. The whole point is that this site is dead simple to edit and deploy.
