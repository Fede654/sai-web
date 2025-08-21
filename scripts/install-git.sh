#!/bin/bash

# SAI Git-Based Installation Script
# For fresh installations using git workflow
# Repository: https://github.com/Fede654/sai-web

set -e

# Configuration
REPO_URL="https://github.com/Fede654/sai-web.git"
WEB_ROOT="/var/www/sai"
BACKUP_DIR="/var/backups/sai-web"
NGINX_SITE="sai"
DOMAIN="sai.altermundi.net"
SERVICE_NAME="sai-proxy"
LOG_FILE="/var/log/sai-install.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

log "SAI Git-Based Installer v2.0"
log "============================="

# Install dependencies
log "Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq git nginx nodejs npm curl certbot python3-certbot-nginx

# Install PM2 if desired
if ! command -v pm2 &> /dev/null; then
    log "Installing PM2 for process management..."
    npm install -g pm2
fi

# Clone repository
if [ -d "$WEB_ROOT/.git" ]; then
    log "Updating existing repository..."
    cd "$WEB_ROOT"
    git pull origin main || git pull origin master
else
    log "Cloning repository..."
    [ -d "$WEB_ROOT" ] && mv "$WEB_ROOT" "${WEB_ROOT}.backup-$(date +%s)"
    git clone "$REPO_URL" "$WEB_ROOT"
fi

cd "$WEB_ROOT"

# Install Node.js dependencies
log "Installing Node.js dependencies..."
npm install --production

# Configure environment
if [ ! -f "$WEB_ROOT/.env" ]; then
    log "Creating .env file..."
    cat > "$WEB_ROOT/.env" << EOF
# SAI Proxy Server Configuration
NODE_ENV=production
PORT=8003

# n8n Webhook Configuration (REQUIRED - Edit these!)
N8N_WEBHOOK_URL=
N8N_API_KEY=

# Optional: CORS settings
ALLOWED_ORIGINS=https://sai.altermundi.net,http://localhost:8080

# Optional: Rate limiting
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX=10
EOF
    warning "Edit $WEB_ROOT/.env with your webhook credentials!"
fi

# Build webhook configuration
if [ -f "$WEB_ROOT/scripts/configure-webhook.js" ]; then
    log "Building webhook configuration..."
    cd "$WEB_ROOT"
    npm run build || warning "Failed to build webhook config"
fi

# Setup nginx
log "Configuring nginx..."
cat > "/etc/nginx/sites-available/$NGINX_SITE" << 'EOF'
# SAI Production Configuration
server {
    listen 80;
    listen [::]:80;
    server_name sai.altermundi.net;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sai.altermundi.net;

    # SSL (will be configured by certbot)
    # ssl_certificate /etc/letsencrypt/live/sai.altermundi.net/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/sai.altermundi.net/privkey.pem;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    root /var/www/sai/static;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://127.0.0.1:8003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location ~ /\. {
        deny all;
    }
    
    location ~ \.(env|json|md|sh|py)$ {
        deny all;
    }
}
EOF

# Enable nginx site
ln -sf "/etc/nginx/sites-available/$NGINX_SITE" "/etc/nginx/sites-enabled/"
nginx -t && systemctl reload nginx

# Setup systemd service
log "Creating systemd service..."
cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=SAI Proxy Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$WEB_ROOT
ExecStart=/usr/bin/node $WEB_ROOT/proxy-server.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/${SERVICE_NAME}.log
StandardError=append:/var/log/${SERVICE_NAME}.error.log
Environment=NODE_ENV=production
Environment=PORT=8003
EnvironmentFile=$WEB_ROOT/.env

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# Set permissions
log "Setting permissions..."
chown -R www-data:www-data "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT/scripts" -type f -name "*.sh" -exec chmod +x {} \;
chmod 600 "$WEB_ROOT/.env"

# Create update script
cat > "$WEB_ROOT/update.sh" << 'EOF'
#!/bin/bash
cd /var/www/sai
sudo -u www-data git pull origin main
sudo -u www-data npm install --production
sudo systemctl restart sai-proxy
echo "Update complete!"
EOF
chmod +x "$WEB_ROOT/update.sh"

# Setup SSL if not exists
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    log "Setting up SSL certificate..."
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email sai@altermundi.net || warning "SSL setup failed - run manually: certbot --nginx -d $DOMAIN"
fi

# Final checks
sleep 3
log "Installation complete! Checking status..."
echo ""
echo -e "${GREEN}Status:${NC}"
systemctl is-active nginx && echo "✓ Nginx: Active" || echo "✗ Nginx: Inactive"
systemctl is-active "$SERVICE_NAME" && echo "✓ Proxy: Active" || echo "✗ Proxy: Inactive"
[ -d "$WEB_ROOT/.git" ] && echo "✓ Git: Configured" || echo "✗ Git: Not configured"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Edit webhook configuration: nano $WEB_ROOT/.env"
echo "2. Configure webhook URL: cd $WEB_ROOT && npm run configure"
echo "3. Test deployment: cd $WEB_ROOT && npm run test-deployment"
echo "4. Future updates: $WEB_ROOT/update.sh"