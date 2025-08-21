# Current Production Configuration

## Nginx Configuration

### Enabled Sites
```bash
/etc/nginx/sites-enabled/
├── ai -> /etc/nginx/sites-available/ai
└── sai -> /etc/nginx/sites-available/sai  # ← SAI Configuration
```

### SAI Nginx Configuration
**File**: `/etc/nginx/sites-available/sai`

```nginx
server {
    listen 80;
    server_name sai.altermundi.net;
    # Redirect all HTTP requests to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name sai.altermundi.net;

    # SSL Certificate and Key from Let's Encrypt
    ssl_certificate /etc/letsencrypt/live/sai.altermundi.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sai.altermundi.net/privkey.pem;

    # SSL Settings for security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;

    # HSTS (HTTP Strict Transport Security)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # SAI Proxy API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:8003;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
    }

    # Base company webpage at root
    location / {
        root /var/www/sai;
        index index.html;
    }
}
```

## Directory Structure

### Current Production Layout
```
/var/www/sai/                    # Static website files
├── index.html                   # Spanish version
├── index-en.html                # English version  
├── images/                      # Website assets
├── robots.txt                   # SEO robots file
├── sitemap.xml                  # SEO sitemap
└── js/                          # JavaScript files
    └── session-manager.js       # Enhanced security (not yet active)

/opt/sai-proxy/                  # Node.js proxy server
├── proxy-server.js              # Current running server
├── proxy-server-enhanced.js     # Enhanced security version (ready for upgrade)
├── package.json                 # Dependencies
├── .env                         # Environment variables (secret)
├── config/                      # Configuration files
│   └── webhook.json            # Webhook configuration
└── node_modules/               # Node.js dependencies

/etc/systemd/system/
└── sai-proxy.service           # Systemd service configuration

/etc/nginx/sites-available/
├── sai                         # SAI nginx config (enabled)
├── ai                          # AI service config (enabled)  
└── firebot                     # Legacy config (disabled)

/var/backups/
├── sai-web/                    # Regular backups
└── pre-security-upgrade/       # Pre-deployment backup
    └── complete-backup-20250811-071742.tar.gz
```

## Service Configuration

### SAI Proxy Service
**File**: `/etc/systemd/system/sai-proxy.service`

```ini
[Unit]
Description=SAI Proxy Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/sai-proxy
Environment="NODE_ENV=production"
Environment="PORT=8003"
EnvironmentFile=/opt/sai-proxy/.env
ExecStart=/usr/bin/node proxy-server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Environment Variables
**File**: `/opt/sai-proxy/.env` (600 permissions, www-data:www-data)

```bash
NODE_ENV=production
PORT=8003
N8N_WEBHOOK_URL=https://[n8n-instance]/webhook/[webhook-id]
N8N_API_KEY=[secret-api-key]
```

## Current Status

### Active Services
- ✅ **nginx**: Running, serving SAI at root domain
- ✅ **sai-proxy**: Running on port 8003, processing form submissions
- ✅ **SSL/TLS**: Let's Encrypt certificates, auto-renewal enabled

### Security Status
- ✅ **API Key Hidden**: Completely server-side, never exposed to clients
- ⚠️ **Basic Security**: Current proxy has minimal security features
- 🔄 **Enhanced Ready**: `proxy-server-enhanced.js` available for upgrade

### Form Fields Active
- ✅ **All original fields**: Working as expected
- ✅ **New field**: `comentarios-adicionales` live on both language versions
- ✅ **Form submissions**: Processing successfully through n8n webhook

## Upgrade Path

### To Enable Enhanced Security
1. **Stop current service**: `systemctl stop sai-proxy`
2. **Install dependencies**: `cd /opt/sai-proxy && npm install express-rate-limit helmet cors uuid`
3. **Switch to enhanced**: `mv proxy-server.js proxy-server-basic.js && mv proxy-server-enhanced.js proxy-server.js`
4. **Update HTML**: Include session-manager.js in form pages
5. **Start service**: `systemctl start sai-proxy`

### Configuration Updates Made
- ✅ **Migration script**: Removed (temporal fix already applied manually)
- ✅ **Install script**: For fresh installations only
- ✅ **Documentation**: Reflects current production state

## Monitoring

### Health Checks
```bash
# Service status
systemctl status sai-proxy

# API health
curl http://localhost:8003/api/health

# Website accessibility  
curl -I https://sai.altermundi.net

# SSL certificate status
openssl s_client -servername sai.altermundi.net -connect sai.altermundi.net:443 -showcerts
```

### Log Locations
- **Proxy logs**: `journalctl -u sai-proxy -f`
- **Nginx access**: `/var/log/nginx/access.log`
- **Nginx errors**: `/var/log/nginx/error.log`
- **SSL renewals**: `journalctl -u certbot.timer`

## Key Changes Made

### ✅ Completed Updates
1. **Nginx config renamed**: `firebot` → `sai` (cleaner, purpose-specific)
2. **Removed legacy services**: Cleaned up unused proxy locations
3. **Added new form field**: `comentarios-adicionales` field live
4. **SEO improvements**: robots.txt and sitemap.xml deployed
5. **Enhanced security ready**: Files in place for future upgrade

### 📋 Documentation Fixed
- Migration scripts now reference correct nginx site name (`sai`)
- Installation scripts use proper configuration paths
- Deployment documentation reflects actual production setup

This configuration provides a clean, focused setup dedicated to the SAI project with proper security and maintainability.