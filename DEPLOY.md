# Deployment Guide: Ahmed Sorour Website

A step-by-step guide to deploy this static website on a VPS (Ubuntu/Debian) with Nginx and SSL.


## Prerequisites

- A VPS running Ubuntu 22.04 or Debian 12 (any provider: DigitalOcean, Hetzner, Linode, Vultr, etc.)
- SSH access to your VPS (root or sudo user)
- A domain name pointed to your VPS IP (optional but recommended for SSL)
- The `site/` folder from this project on your local machine


## 1. Initial VPS Setup

SSH into your server:

```bash
ssh root@YOUR_SERVER_IP
```

Update packages and install essentials:

```bash
apt update && apt upgrade -y
apt install -y nginx certbot python3-certbot-nginx ufw
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


## 3. Transfer Site Files to VPS

From your local machine (not the VPS), run:

```bash
scp -r site/ root@YOUR_SERVER_IP:/tmp/sorour-site/
```

This uploads the entire site folder to a temporary location on the server.


## 4. Deploy the Site

SSH back into your VPS and run the deploy script:

```bash
ssh root@YOUR_SERVER_IP
cd /tmp/sorour-site
chmod +x deploy.sh
```

Before running, edit `deploy.sh` and `nginx.conf` to replace `your-domain.com` with your actual domain or server IP:

```bash
nano deploy.sh    # update DOMAIN variable
nano nginx.conf   # update server_name
```

Then deploy:

```bash
sudo ./deploy.sh
```

The script will:
1. Create `/var/www/sorour/` and copy all HTML and CSS files
2. Install the Nginx config to `/etc/nginx/sites-available/sorour`
3. Enable the site and reload Nginx


## 5. Verify the Site

Open your browser and visit:

```
http://YOUR_SERVER_IP
```

or if DNS is configured:

```
http://your-domain.com
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

Certbot will:
- Obtain a free SSL certificate
- Automatically modify your Nginx config to serve HTTPS
- Set up HTTP to HTTPS redirect

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

When you make changes to the HTML or CSS files:

1. From your local machine:

```bash
scp site/*.html site/style.css root@YOUR_SERVER_IP:/var/www/sorour/
```

2. That is it. Nginx serves static files directly, so changes appear immediately. No restart needed.


## File Structure on VPS

After deployment:

```
/var/www/sorour/
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
sudo nginx -t          # shows config errors
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
