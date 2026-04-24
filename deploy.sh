#!/bin/bash
# ============================================================
# Deploy Ahmed Sorour website to VPS
# ============================================================
# Usage:
#   1. SSH into your VPS
#   2. Clone the repo: git clone https://github.com/soroura/web.git
#   3. cd web
#   4. chmod +x deploy.sh
#   5. sudo ./deploy.sh
# ============================================================

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SITE_DIR="/var/www/sorour"
DOMAIN="soroura.org"

echo "=== Ahmed Sorour Site Deployment ==="
echo ""

# 1. Create site directory
echo "[1/5] Creating site directory..."
sudo mkdir -p "$SITE_DIR"

# 2. Sync site files from repo
echo "[2/5] Syncing site files..."
sudo rsync -a --delete \
  --exclude='.git/' \
  --exclude='deploy.sh' \
  --exclude='nginx.conf' \
  --exclude='DEPLOY.md' \
  --exclude='*.md' \
  "$REPO_DIR/" "$SITE_DIR/"
sudo chown -R www-data:www-data "$SITE_DIR"
sudo chmod -R 755 "$SITE_DIR"

# 3. Set up Nginx config
echo "[3/5] Setting up Nginx..."
# Replace placeholder domain in nginx.conf before copying
sed "s/your-domain.com/$DOMAIN/g" "$REPO_DIR/nginx.conf" | sudo tee /etc/nginx/sites-available/sorour > /dev/null
sudo ln -sf /etc/nginx/sites-available/sorour /etc/nginx/sites-enabled/sorour

# Remove default site if it exists
if [ -L /etc/nginx/sites-enabled/default ]; then
  echo "     Removing default Nginx site..."
  sudo rm /etc/nginx/sites-enabled/default
fi

# 4. Test Nginx config
echo "[4/5] Testing Nginx configuration..."
sudo nginx -t

# 5. Reload Nginx
echo "[5/5] Reloading Nginx..."
sudo systemctl reload nginx

echo ""
echo "=== Deployment complete ==="
echo "Site is live at http://$DOMAIN"
echo ""
echo "Next steps:"
echo "  - Point your domain DNS A record to this server IP"
echo "  - Run: sudo certbot --nginx -d $DOMAIN"
echo "    to enable HTTPS with Let's Encrypt"
echo ""
echo "To update later, run:"
echo "  cd $REPO_DIR && git pull && sudo ./deploy.sh"
