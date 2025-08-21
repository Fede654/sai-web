#!/bin/bash

# SAI Migration Script
# Migrates current deployment to git-based workflow and renames nginx config
# Run this ONCE on the production server to modernize the deployment

set -e

# Configuration
REPO_URL="https://github.com/Fede654/sai-web.git"
WEB_ROOT="/var/www/sai"
PROXY_ROOT="/opt/sai-proxy"
BACKUP_DIR="/var/backups/sai-web"
OLD_NGINX_SITE="firebot"
NEW_NGINX_SITE="sai"
DOMAIN="sai.altermundi.net"
SERVICE_NAME="sai-proxy"
LOG_FILE="/var/log/sai-migration.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   SAI Deployment Migration Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
info "This script will:"
echo "  1. Create comprehensive backup"
echo "  2. Rename nginx config from 'firebot' to 'sai.altermundi.net'"
echo "  3. Convert deployment to git-based workflow"
echo "  4. Consolidate proxy and static files"
echo "  5. Update all configurations"
echo ""
read -p "Continue with migration? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    exit 0
fi

# Create log file
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Step 1: Create comprehensive backup
log "Creating comprehensive backup before migration..."
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="pre-migration-backup-$TIMESTAMP.tar.gz"

# Backup everything related to SAI
tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    "$WEB_ROOT" \
    "$PROXY_ROOT" \
    "/etc/nginx/sites-available/$OLD_NGINX_SITE" \
    "/etc/systemd/system/$SERVICE_NAME.service" \
    2>/dev/null || true

log "Backup created: $BACKUP_DIR/$BACKUP_NAME"

# Step 2: Stop services during migration
log "Stopping services for migration..."
systemctl stop "$SERVICE_NAME" || warning "Service $SERVICE_NAME was not running"
sleep 2

# Step 3: Setup new directory structure with git
log "Setting up git-based deployment..."

# Create new unified directory structure
NEW_ROOT="/var/www/sai-new"
log "Creating new deployment at $NEW_ROOT..."

# Clone repository
git clone "$REPO_URL" "$NEW_ROOT"
cd "$NEW_ROOT"

# Copy existing configurations
log "Preserving existing configurations..."
if [ -f "$PROXY_ROOT/.env" ]; then
    cp "$PROXY_ROOT/.env" "$NEW_ROOT/.env"
    info "Copied .env configuration"
fi

if [ -f "$PROXY_ROOT/config/webhook.json" ]; then
    mkdir -p "$NEW_ROOT/config"
    cp "$PROXY_ROOT/config/webhook.json" "$NEW_ROOT/config/"
    info "Copied webhook configuration"
fi

# Step 4: Rename and update nginx configuration
log "Updating nginx configuration..."

# Create new nginx config
cat > "/etc/nginx/sites-available/$NEW_NGINX_SITE" << 'EOF'
# SAI (Sistema de Alerta de Incendios) - Production Configuration
# Managed by git deployment at /var/www/sai

server {
    listen 80;
    listen [::]:80;
    server_name sai.altermundi.net;

    # Redirect all HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sai.altermundi.net;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/sai.altermundi.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sai.altermundi.net/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' https: data:; font-src 'self' data:;" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Document Root
    root /var/www/sai/static;
    index index.html;
    
    # Main site
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # API Proxy to Node.js server
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
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Disable buffering for SSE
        proxy_buffering off;
    }
    
    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Security: Block access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Block access to sensitive files
    location ~ \.(env|json|md|sh|py|yml|yaml|git)$ {
        deny all;
        return 404;
    }
    
    # Specific allow for robots.txt and sitemap.xml
    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }
    
    location = /sitemap.xml {
        allow all;
        log_not_found off;
        access_log off;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF

log "Created new nginx configuration: $NEW_NGINX_SITE"

# Disable old config and enable new one
log "Switching nginx configuration..."
rm -f "/etc/nginx/sites-enabled/$OLD_NGINX_SITE"
ln -sf "/etc/nginx/sites-available/$NEW_NGINX_SITE" "/etc/nginx/sites-enabled/"

# Test nginx config
if nginx -t 2>/dev/null; then
    log "Nginx configuration is valid"
else
    error "Nginx configuration has errors. Please check manually."
fi

# Step 5: Update systemd service
log "Updating systemd service..."

cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=SAI Proxy Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/sai
ExecStart=/usr/bin/node /var/www/sai/proxy-server.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/${SERVICE_NAME}.log
StandardError=append:/var/log/${SERVICE_NAME}.error.log
Environment=NODE_ENV=production
Environment=PORT=8003
EnvironmentFile=/var/www/sai/.env

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
log "Systemd service updated"

# Step 6: Move to new structure
log "Migrating to new directory structure..."

# Remove old directories and create symlink for smooth transition
if [ -d "$WEB_ROOT" ]; then
    rm -rf "${WEB_ROOT}.old"
    mv "$WEB_ROOT" "${WEB_ROOT}.old"
fi

# Move new deployment to final location
mv "$NEW_ROOT" "$WEB_ROOT"

# Set up proper structure
cd "$WEB_ROOT"

# Install Node.js dependencies
log "Installing Node.js dependencies..."
npm install --production

# Step 7: Set proper permissions
log "Setting proper permissions..."
chown -R www-data:www-data "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$WEB_ROOT/scripts" -type f -name "*.sh" -exec chmod +x {} \;
find "$WEB_ROOT/scripts" -type f -name "*.js" -exec chmod +x {} \;
[ -f "$WEB_ROOT/.env" ] && chmod 600 "$WEB_ROOT/.env"
[ -f "$WEB_ROOT/config/webhook.json" ] && chmod 600 "$WEB_ROOT/config/webhook.json"

# Step 8: Restart services
log "Starting services..."
systemctl reload nginx
systemctl start "$SERVICE_NAME"
systemctl enable "$SERVICE_NAME"

sleep 3

# Step 9: Validate migration
log "Validating migration..."

ERRORS=0

# Check if services are running
if systemctl is-active --quiet nginx; then
    info "✓ Nginx is running"
else
    warning "✗ Nginx is not running"
    ERRORS=$((ERRORS + 1))
fi

if systemctl is-active --quiet "$SERVICE_NAME"; then
    info "✓ SAI Proxy service is running"
else
    warning "✗ SAI Proxy service is not running"
    ERRORS=$((ERRORS + 1))
fi

# Check if git repository is set up
if [ -d "$WEB_ROOT/.git" ]; then
    info "✓ Git repository is configured"
    cd "$WEB_ROOT"
    git remote -v
else
    warning "✗ Git repository not found"
    ERRORS=$((ERRORS + 1))
fi

# Check if website is accessible
if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1" | grep -q "301\|200"; then
    info "✓ Website is accessible"
else
    warning "✗ Website is not accessible"
    ERRORS=$((ERRORS + 1))
fi

# Check if API is responsive
if curl -s "http://127.0.0.1:8003/api/health" | grep -q "ok"; then
    info "✓ API proxy is responsive"
else
    warning "✗ API proxy is not responsive"
    ERRORS=$((ERRORS + 1))
fi

# Step 10: Cleanup old deployment (optional)
if [ $ERRORS -eq 0 ]; then
    log "Migration completed successfully!"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Migration Completed Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Old deployment backed up at:"
    echo "  - ${WEB_ROOT}.old"
    echo "  - $PROXY_ROOT (original proxy location)"
    echo ""
    echo "New configuration:"
    echo "  - Git repository: $WEB_ROOT"
    echo "  - Nginx config: /etc/nginx/sites-available/$NEW_NGINX_SITE"
    echo "  - Service: systemctl status $SERVICE_NAME"
    echo ""
    echo "To remove old files (after confirming everything works):"
    echo "  rm -rf ${WEB_ROOT}.old"
    echo "  rm -rf $PROXY_ROOT"
    echo "  rm /etc/nginx/sites-available/$OLD_NGINX_SITE"
    echo ""
    echo "Future updates can now use:"
    echo "  cd $WEB_ROOT && git pull"
    echo ""
else
    error "Migration completed with $ERRORS errors. Please check the logs: $LOG_FILE"
fi

# Create post-migration script for easy updates
cat > "$WEB_ROOT/update.sh" << 'EOF'
#!/bin/bash
# Quick update script for git-based deployment

cd /var/www/sai
git pull origin main
npm install --production
sudo systemctl restart sai-proxy
echo "Update complete!"
EOF
chmod +x "$WEB_ROOT/update.sh"

log "Created update.sh script for future updates"