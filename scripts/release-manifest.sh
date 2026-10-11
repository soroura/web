# Single source of truth for what a release contains.
# Sourced by build-release.sh, ci-upload.sh and install-release.sh.
#
# SITE_FILES - globs evaluated at the repo root. Every match is published to the
#   webroot, so a new page or image deploys without editing this file. Anything
#   that does not match (*.md, scripts, .git) is never served.
SITE_FILES="*.html *.css *.png *.jpg *.jpeg *.webp *.gif *.svg *.ico robots.txt sitemap.xml"

# Files that must exist, or the build fails before anything reaches the server.
REQUIRED_FILES="index.html style.css robots.txt sitemap.xml"

# CI-owned paths inside TARGET (/opt/web on the VPS): removed and replaced on
# every deploy. Everything else under TARGET is VPS-owned and never touched.
RELEASE_PATHS="site deploy.sh nginx.conf scripts"
