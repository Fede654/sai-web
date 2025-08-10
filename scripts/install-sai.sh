#!/bin/bash

# SAI Website Installation/Update Script
# For deployment at sai.altermundi.net
# Repository: https://github.com/Fede654/sai-web

set -e  # Exit on error

# Configuration
REPO_URL="https://github.com/Fede654/sai-web.git"
WEB_ROOT="/var/www/sai"
PROXY_ROOT="/opt/sai-proxy"
BACKUP_DIR="/var/backups/sai-web"
NGINX_SITE="firebot"  # Nginx site config name
DOMAIN="sai.altermundi.net"
SERVICE_NAME="sai-proxy"
LOG_FILE="/var/log/sai-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
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

log "Starting SAI Website installation/update..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to backup current installation
backup_current() {
    if [ -d "$WEB_ROOT" ]; then
        local backup_name="sai-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        log "Creating backup: $backup_name"
        tar -czf "$BACKUP_DIR/$backup_name" -C "$(dirname $WEB_ROOT)" "$(basename $WEB_ROOT)" 2>/dev/null || true
        
        # Keep only last 5 backups
        ls -t "$BACKUP_DIR"/sai-backup-*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm
    fi
}

# Function to install dependencies
install_dependencies() {
    log "Checking and installing dependencies..."
    
    # Update package list
    apt-get update -qq
    
    # Install required packages
    local packages="git nginx nodejs npm curl"
    for pkg in $packages; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            log "Installing $pkg..."
            apt-get install -y -qq "$pkg"
        fi
    done
    
    # Install PM2 globally if not present
    if ! command -v pm2 &> /dev/null; then
        log "Installing PM2..."
        npm install -g pm2
    fi
}

# Function to setup repository and separate proxy
setup_repository() {
    # Setup static files
    if [ -d "$WEB_ROOT/.git" ]; then
        log "Updating existing repository..."
        cd "$WEB_ROOT"
        
        # Stash any local changes
        git stash save "Auto-stash before update $(date)" || true
        
        # Pull latest changes
        git fetch origin
        git checkout main || git checkout master
        git pull origin main || git pull origin master
        
        # Check if there were stashed changes
        if git stash list | grep -q "Auto-stash"; then
            warning "Local changes were stashed. Review with: git stash list"
        fi
    else
        log "Setting up website files..."
        
        # Backup existing directory if it exists
        if [ -d "$WEB_ROOT" ]; then
            backup_current
        fi
        
        # Create temp directory for cloning
        local temp_dir="/tmp/sai-web-$(date +%s)"
        git clone "$REPO_URL" "$temp_dir"
        
        # Copy static files to web root
        mkdir -p "$WEB_ROOT"
        cp -r "$temp_dir/static/"* "$WEB_ROOT/"
        
        # Setup proxy server in separate location
        if [ ! -d "$PROXY_ROOT" ]; then
            log "Setting up proxy server..."
            mkdir -p "$PROXY_ROOT"
            cp "$temp_dir/proxy-server.js" "$PROXY_ROOT/"
            cp "$temp_dir/package.json" "$PROXY_ROOT/"
            cp -r "$temp_dir/config" "$PROXY_ROOT/" 2>/dev/null || true
            cp -r "$temp_dir/scripts" "$PROXY_ROOT/" 2>/dev/null || true
        fi
        
        # Cleanup
        rm -rf "$temp_dir"
    fi
}

# Function to install Node.js dependencies
install_node_deps() {
    log "Installing Node.js dependencies for proxy server..."
    cd "$PROXY_ROOT"
    
    # Clean install to avoid conflicts
    rm -rf node_modules package-lock.json
    npm install --production
}

# Function to configure environment
configure_environment() {
    local env_file="$PROXY_ROOT/.env"
    
    if [ ! -f "$env_file" ]; then
        log "Creating .env file..."
        
        # Check if .env.example exists
        if [ -f "$WEB_ROOT/.env.example" ]; then
            cp "$WEB_ROOT/.env.example" "$env_file"
            warning "Please edit $env_file with your webhook credentials"
        else
            # Create basic .env
            cat > "$env_file" << EOF
# SAI Proxy Server Configuration
NODE_ENV=production
PORT=8003

# n8n Webhook Configuration (REQUIRED)
N8N_WEBHOOK_URL=
N8N_API_KEY=

# Optional: CORS settings
ALLOWED_ORIGINS=https://sai.altermundi.net,http://localhost:8080

# Optional: Rate limiting
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX=10
EOF
            warning "Created $env_file - MUST be configured with webhook credentials"
        fi
        
        # Set proper permissions
        chmod 600 "$env_file"
        chown www-data:www-data "$env_file"
    else
        log ".env file already exists, preserving current configuration"
    fi
}

# Function to configure webhook
configure_webhook() {
    log "Checking webhook configuration..."
    cd "$PROXY_ROOT"
    
    # Run configuration script if webhook.json doesn't exist
    if [ ! -f "config/webhook.json" ]; then
        warning "Webhook configuration missing. Run: npm run configure"
    else
        # Build configuration into HTML files
        npm run build || warning "Failed to build webhook configuration"
    fi
}

# Function to setup systemd service
setup_systemd_service() {
    log "Setting up systemd service..."
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=SAI Proxy Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$PROXY_ROOT
ExecStart=/usr/bin/node $PROXY_ROOT/proxy-server.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/${SERVICE_NAME}.log
StandardError=append:/var/log/${SERVICE_NAME}.error.log
Environment=NODE_ENV=production
Environment=PORT=8003
EnvironmentFile=$PROXY_ROOT/.env

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    # Restart service
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Restarting $SERVICE_NAME service..."
        systemctl restart "$SERVICE_NAME"
    else
        log "Starting $SERVICE_NAME service..."
        systemctl start "$SERVICE_NAME"
    fi
    
    # Check service status
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Service $SERVICE_NAME is running"
    else
        warning "Service $SERVICE_NAME failed to start. Check: journalctl -u $SERVICE_NAME"
    fi
}

# Function to setup nginx
setup_nginx() {
    log "Configuring nginx..."
    
    local nginx_config="/etc/nginx/sites-available/$NGINX_SITE"
    
    # Check if configuration already exists (might be named firebot)
    if [ -f "$nginx_config" ]; then
        log "Nginx configuration already exists at $nginx_config"
        warning "Current nginx config preserved. Review manually if updates needed."
    else
        log "Creating nginx configuration..."
        cat > "$nginx_config" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL configuration (update paths as needed)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
    
    # Document root
    root $WEB_ROOT;
    index index.html;
    
    # Serve static files
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Proxy API requests to Node.js server
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
    }
    
    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Security: Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Deny access to sensitive files
    location ~ \.(env|json|md|sh|py)$ {
        deny all;
    }
}
EOF
        
        # Enable site
        ln -sf "$nginx_config" "/etc/nginx/sites-enabled/"
        
        warning "Nginx configuration created. Update SSL certificate paths if needed."
    else
        log "Nginx configuration already exists"
    fi
    
    # Test nginx configuration
    if nginx -t 2>/dev/null; then
        log "Nginx configuration is valid"
        systemctl reload nginx
    else
        warning "Nginx configuration has errors. Please review."
    fi
}

# Function to set proper permissions
set_permissions() {
    log "Setting proper permissions..."
    
    # Set ownership for web root
    chown -R www-data:www-data "$WEB_ROOT"
    
    # Set ownership for proxy root
    chown -R www-data:www-data "$PROXY_ROOT"
    
    # Set directory permissions
    find "$WEB_ROOT" -type d -exec chmod 755 {} \;
    find "$PROXY_ROOT" -type d -exec chmod 755 {} \;
    
    # Set file permissions
    find "$WEB_ROOT" -type f -exec chmod 644 {} \;
    find "$PROXY_ROOT" -type f -exec chmod 644 {} \;
    
    # Make scripts executable
    [ -d "$PROXY_ROOT/scripts" ] && find "$PROXY_ROOT/scripts" -type f -name "*.sh" -exec chmod +x {} \;
    [ -d "$PROXY_ROOT/scripts" ] && find "$PROXY_ROOT/scripts" -type f -name "*.js" -exec chmod +x {} \;
    
    # Protect sensitive files
    [ -f "$PROXY_ROOT/.env" ] && chmod 600 "$PROXY_ROOT/.env"
    [ -f "$PROXY_ROOT/config/webhook.json" ] && chmod 600 "$PROXY_ROOT/config/webhook.json"
}

# Function to run tests
run_tests() {
    log "Running deployment tests..."
    cd "$PROXY_ROOT"
    
    # Run validation script
    if [ -f "scripts/validate-deployment.sh" ]; then
        sudo -u www-data npm run validate || warning "Validation tests failed"
    fi
    
    # Test proxy server health
    sleep 3
    if curl -s "http://127.0.0.1:8003/api/health" | grep -q "ok"; then
        log "Proxy server health check passed"
    else
        warning "Proxy server health check failed"
    fi
}

# Function to display status
display_status() {
    echo ""
    log "==================== Installation Complete ===================="
    echo ""
    echo -e "${GREEN}Website Status:${NC}"
    echo "  - Static files: $WEB_ROOT"
    echo "  - Proxy server: $(systemctl is-active $SERVICE_NAME) at $PROXY_ROOT"
    echo "  - Nginx: $(systemctl is-active nginx)"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    
    if [ ! -f "$PROXY_ROOT/.env" ] || ! grep -q "N8N_WEBHOOK_URL=https" "$PROXY_ROOT/.env" 2>/dev/null; then
        echo "  1. Configure webhook credentials:"
        echo "     sudo nano $PROXY_ROOT/.env"
    fi
    
    if [ ! -f "$PROXY_ROOT/config/webhook.json" ]; then
        echo "  2. Configure webhook URL:"
        echo "     cd $PROXY_ROOT && sudo -u www-data npm run configure"
    fi
    
    if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "  3. Setup SSL certificate:"
        echo "     sudo certbot --nginx -d $DOMAIN"
    fi
    
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo "  - View logs: journalctl -u $SERVICE_NAME -f"
    echo "  - Test deployment: cd $PROXY_ROOT && npm run test-deployment"
    echo "  - Restart proxy: sudo systemctl restart $SERVICE_NAME"
    echo "  - Update website: sudo $0"
    echo ""
}

# Main installation flow
main() {
    log "SAI Website Installer v1.0"
    log "=========================="
    
    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Run installation steps
    backup_current
    install_dependencies
    setup_repository
    install_node_deps
    configure_environment
    configure_webhook
    set_permissions
    setup_systemd_service
    setup_nginx
    run_tests
    display_status
    
    log "Installation/update completed successfully!"
}

# Run main function
main "$@"