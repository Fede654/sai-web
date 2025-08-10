# SAI Website Deployment Scripts

## Overview

These scripts automate the deployment and maintenance of the SAI website at sai.altermundi.net.

## Scripts

### install-sai.sh
Complete installation and configuration script for new deployments or major updates.

**Features:**
- Installs all system dependencies (nginx, nodejs, npm, pm2)
- Clones/updates repository from GitHub
- Configures systemd service for proxy server
- Sets up nginx with SSL support
- Creates proper directory structure and permissions
- Automated backup before updates
- Health checks and validation

**Usage:**
```bash
# First time installation
sudo ./scripts/install-sai.sh

# Full reinstall/major update
sudo /var/www/sai.altermundi.net/scripts/install-sai.sh
```

### update-sai.sh
Lightweight script for routine updates from git repository.

**Features:**
- Quick git pull with automatic stashing
- Incremental dependency updates
- Service restart only when needed
- Minimal downtime
- Automatic backup
- Quick validation

**Usage:**
```bash
# Quick update from repository
sudo ./scripts/update-sai.sh

# Or from the server
sudo /var/www/sai.altermundi.net/scripts/update-sai.sh
```

## Server Deployment Guide

### Initial Setup

1. **Run installation script on server:**
```bash
# Download and run installer
wget https://raw.githubusercontent.com/Fede654/sai-web/main/scripts/install-sai.sh
sudo bash install-sai.sh
```

2. **Configure environment variables:**
```bash
sudo nano /var/www/sai.altermundi.net/.env
```

Add your n8n webhook credentials:
```
N8N_WEBHOOK_URL=https://your-n8n-instance.com/webhook/xxx
N8N_API_KEY=your-secret-key
```

3. **Configure webhook URL:**
```bash
cd /var/www/sai.altermundi.net
sudo -u www-data npm run configure
```

4. **Setup SSL certificate:**
```bash
sudo certbot --nginx -d sai.altermundi.net
```

### Routine Updates

For regular updates when new code is pushed to repository:

```bash
# Quick update
sudo /var/www/sai.altermundi.net/scripts/update-sai.sh
```

### Manual Operations

**Check service status:**
```bash
sudo systemctl status sai-proxy
```

**View logs:**
```bash
# Proxy server logs
journalctl -u sai-proxy -f

# Nginx access logs
tail -f /var/log/nginx/access.log

# Nginx error logs
tail -f /var/log/nginx/error.log
```

**Restart services:**
```bash
# Restart proxy server
sudo systemctl restart sai-proxy

# Restart nginx
sudo systemctl restart nginx
```

**Run tests:**
```bash
cd /var/www/sai.altermundi.net
sudo -u www-data npm run test-deployment
```

## Directory Structure

```
/var/www/sai.altermundi.net/
├── static/             # Static website files
│   ├── index.html      # Spanish version
│   ├── index-en.html   # English version
│   └── images/         # Assets
├── scripts/            # Utility scripts
├── config/             # Configuration files
│   └── webhook.json    # Webhook configuration
├── proxy-server.js     # Node.js proxy server
├── .env               # Environment variables (secret)
└── package.json       # Node.js dependencies
```

## Backup Management

Backups are automatically created before each update:
- Location: `/var/backups/sai-web/`
- Format: `sai-backup-YYYYMMDD-HHMMSS.tar.gz`
- Retention: Last 5 backups are kept

**Restore from backup:**
```bash
# List available backups
ls -la /var/backups/sai-web/

# Restore specific backup
sudo tar -xzf /var/backups/sai-web/sai-backup-20250809-120000.tar.gz -C /
sudo systemctl restart sai-proxy
```

## Troubleshooting

### Service won't start
```bash
# Check logs
journalctl -u sai-proxy -n 100

# Verify .env file exists and has credentials
sudo cat /var/www/sai.altermundi.net/.env

# Test configuration
cd /var/www/sai.altermundi.net
sudo -u www-data node proxy-server.js
```

### Nginx errors
```bash
# Test configuration
sudo nginx -t

# Check error log
sudo tail -f /var/log/nginx/error.log

# Verify SSL certificates
sudo certbot certificates
```

### Permission issues
```bash
# Reset permissions
sudo chown -R www-data:www-data /var/www/sai.altermundi.net
sudo find /var/www/sai.altermundi.net -type d -exec chmod 755 {} \;
sudo find /var/www/sai.altermundi.net -type f -exec chmod 644 {} \;
```

## Security Notes

- The `.env` file contains sensitive credentials and is protected with 600 permissions
- The proxy server runs as `www-data` user for security
- Nginx blocks access to sensitive files (`.env`, `.json`, `.md`, etc.)
- SSL/TLS is enforced for all production traffic
- Rate limiting is implemented in the proxy server

## Support

For issues or questions:
- Email: sai@altermundi.net
- Repository: https://github.com/Fede654/sai-web