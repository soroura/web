#!/bin/bash
# ============================================================
# Deploy Ahmed Sorour website to VPS
# ============================================================
# Usage:
#   1. scp the entire site/ folder to your VPS
#   2. ssh into your VPS
#   3. cd into the site/ folder
#   4. chmod +x deploy.sh
#   5. sudo ./deploy.sh
# ============================================================

set -e

SITE_DIR="/var/www/sorour"
DOMAIN="your-domain.com"   # <-- Replace with your domain or VPS IP

echo "=== Ahmed Sorour Site Deployment ==="
echo ""

# 1. Create site directory
echo "[1/5] Creating site directory..."
sudo mkdir -p "$SITE_DIR"

# 2. Copy all site files
echo "[2/5] Copying site files..."
sudo cp index.html experience.html projects.html education.html contact.html style.css "$SITE_DIR/"
sudo chown -R www-data:www-data "$SITE_DIR"
sudo chmod -R 755 "$SITE_DIR"

# 3. Set up Nginx config
echo "[3/5] Setting up Nginx..."
sudo cp nginx.conf /etc/nginx/sites-available/sorour
sudo ln -sf /etc/nginx/sites-available/sorour /etc/nginx/sites-enabled/sorour

# Remove default site if it exists (optional)
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
