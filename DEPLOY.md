# Deployment Guide: Ahmed Sorour Website

A step-by-step guide to deploy this static website on a VPS (Ubuntu/Debian) with Nginx and SSL.

Repository: https://github.com/soroura/web


## Prerequisites

- A VPS running Ubuntu 22.04 or Debian 12 (any provider: DigitalOcean, Hetzner, Linode, Vultr, etc.)
- SSH access to your VPS (root or sudo user)
- A domain name pointed to your VPS IP (optional but recommended for SSL)


## 1. Initial VPS Setup

SSH into your server:

```bash
ssh root@217.76.56.188
```

Update packages and install essentials:

```bash
apt update && apt upgrade -y
apt install -y nginx certbot python3-certbot-nginx ufw git
```


## 2. Configure Firewall (UFW)

Allow SSH, HTTP, and HTTPS traffic:

```bash
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable
```

Verify:

```bash
ufw status
```

You should see OpenSSH, Nginx Full (v6) listed as ALLOW.


## 3. Clone the Repository

```bash
cd /opt
git clone https://github.com/soroura/web.git
cd web
```


## 4. Configure and Deploy

Edit the deploy script to set your domain (or use your VPS IP if you don't have a domain yet):

```bash
nano deploy.sh    # update DOMAIN="your-domain.com"
```

Then run:

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

The script will:
1. Create `/var/www/sorour/` and copy all HTML and CSS files
2. Generate the Nginx config with your domain and install it
3. Enable the site and reload Nginx


## 5. Verify the Site

Open your browser and visit:

```
http://YOUR_SERVER_IP
```

or if DNS is configured:

```
http://soroura.org
```

You should see the homepage. Click through all five pages (Home, Experience, Projects, Education, Contact) to confirm navigation works.


## 6. Set Up DNS

In your domain registrar's DNS settings, create an A record:

```
Type: A
Name: @  (or your subdomain)
Value: YOUR_SERVER_IP
TTL: 300
```

If you want `www` to also work:

```
Type: CNAME
Name: www
Value: your-domain.com
TTL: 300
```

DNS propagation typically takes 5 to 30 minutes.


## 7. Enable HTTPS with Let's Encrypt

Once DNS is pointing to your server:

```bash
sudo certbot --nginx -d your-domain.com
```

If you also set up `www`:

```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

Certbot will obtain a free SSL certificate, modify your Nginx config to serve HTTPS, and set up an HTTP to HTTPS redirect.

Verify auto-renewal works:

```bash
sudo certbot renew --dry-run
```

Certbot installs a systemd timer that renews certificates automatically before expiry.


## 8. Verify HTTPS

Visit:

```
https://your-domain.com
```

You should see the green padlock. All pages should load over HTTPS.


## Updating the Site

When you make changes locally:

1. Push your changes to GitHub:

```bash
git add .
git commit -m "Update site content"
git push
```

2. On your VPS, pull and redeploy:

```bash
cd /opt/web
git pull
sudo ./deploy.sh
```

That is it. Nginx serves static files directly, so changes appear as soon as the files are copied.


## File Structure on VPS

After deployment:

```
/opt/web/                            (git repo)
  index.html
  experience.html
  projects.html
  education.html
  contact.html
  style.css
  nginx.conf
  deploy.sh
  DEPLOY.md

/var/www/sorour/                     (served by Nginx)
  index.html
  experience.html
  projects.html
  education.html
  contact.html
  style.css

/etc/nginx/sites-available/sorour    (Nginx config)
/etc/nginx/sites-enabled/sorour      (symlink)
```


## Troubleshooting

**Nginx fails to start or reload**
```bash
sudo nginx -t
sudo journalctl -u nginx --no-pager -n 30
```

**Site shows default Nginx page**
Remove the default site if still enabled:
```bash
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl reload nginx
```

**Permission denied errors**
```bash
sudo chown -R www-data:www-data /var/www/sorour
sudo chmod -R 755 /var/www/sorour
```

**Certbot fails**
Make sure DNS is fully propagated (check with `dig your-domain.com`), port 80 is open, and Nginx is running.

**404 on subpages**
Confirm all HTML files are in `/var/www/sorour/` and the Nginx config has `try_files $uri $uri/ =404;`.

**git pull permission denied**
If you cloned as root but run as a regular user:
```bash
sudo chown -R $(whoami):$(whoami) /opt/web
```
