#!/bin/bash

# SAI Website Quick Update Script
# For pulling latest changes from repository
# This is a lightweight version for routine updates

set -e

# Configuration
WEB_ROOT="/var/www/sai"
PROXY_ROOT="/opt/sai-proxy"
SERVICE_NAME="sai-proxy"
BACKUP_DIR="/var/backups/sai-web"
REPO_URL="https://github.com/Fede654/sai-web.git"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

echo -e "${GREEN}Starting SAI website update...${NC}"

# Since the current deployment isn't git-based, we'll fetch updates differently
if [ ! -d "$PROXY_ROOT" ]; then
    echo -e "${RED}SAI proxy not found at $PROXY_ROOT${NC}"
    echo "Please run install-sai.sh first"
    exit 1
fi

# Create backup
echo "Creating backup..."
mkdir -p "$BACKUP_DIR"
BACKUP_NAME="sai-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    -C "$(dirname $WEB_ROOT)" "$(basename $WEB_ROOT)" \
    -C "$(dirname $PROXY_ROOT)" "$(basename $PROXY_ROOT)" 2>/dev/null || true
echo -e "${GREEN}Backup created: $BACKUP_NAME${NC}"

# Clone latest version to temp directory
echo "Fetching latest version from repository..."
TEMP_DIR="/tmp/sai-update-$(date +%s)"
git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

# Update static files
echo "Updating static files..."
rsync -av --delete "$TEMP_DIR/static/" "$WEB_ROOT/"

# Update proxy server files
echo "Updating proxy server..."
cp "$TEMP_DIR/proxy-server.js" "$PROXY_ROOT/"
cp "$TEMP_DIR/package.json" "$PROXY_ROOT/"
[ -d "$TEMP_DIR/scripts" ] && rsync -av "$TEMP_DIR/scripts/" "$PROXY_ROOT/scripts/"
[ -d "$TEMP_DIR/config" ] && rsync -av --exclude='webhook.json' "$TEMP_DIR/config/" "$PROXY_ROOT/config/"

# Check if package.json was updated
if ! diff -q "$TEMP_DIR/package.json" "$PROXY_ROOT/package.json" >/dev/null 2>&1; then
    echo "package.json updated, installing dependencies..."
    cd "$PROXY_ROOT"
    npm install --production
fi

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Set proper permissions
echo "Setting permissions..."
chown -R www-data:www-data "$WEB_ROOT"
chown -R www-data:www-data "$PROXY_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
find "$PROXY_ROOT" -type d -exec chmod 755 {} \;
find "$PROXY_ROOT" -type f -exec chmod 644 {} \;
[ -d "$PROXY_ROOT/scripts" ] && find "$PROXY_ROOT/scripts" -type f -name "*.sh" -exec chmod +x {} \;
[ -d "$PROXY_ROOT/scripts" ] && find "$PROXY_ROOT/scripts" -type f -name "*.js" -exec chmod +x {} \;
[ -f "$PROXY_ROOT/.env" ] && chmod 600 "$PROXY_ROOT/.env"
[ -f "$PROXY_ROOT/config/webhook.json" ] && chmod 600 "$PROXY_ROOT/config/webhook.json"

# Always restart service after update to apply changes
echo "Restarting proxy service..."
systemctl restart "$SERVICE_NAME"
sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}Service restarted successfully${NC}"
    else
        echo -e "${RED}Service failed to restart${NC}"
        echo "Check logs: journalctl -u $SERVICE_NAME -n 50"
    fi
fi

# Reload nginx if configuration might have changed
if nginx -t 2>/dev/null; then
    systemctl reload nginx
    echo "Nginx reloaded"
fi

# Run quick validation
if [ -f "$PROXY_ROOT/scripts/validate-deployment.sh" ]; then
    echo "Running validation tests..."
    cd "$PROXY_ROOT"
    sudo -u www-data bash scripts/validate-deployment.sh || echo -e "${YELLOW}Some tests failed${NC}"
fi

# Show summary
echo ""
echo -e "${GREEN}==================== Update Complete ====================${NC}"
echo ""
echo "Static files updated in: $WEB_ROOT"
echo "Proxy server updated in: $PROXY_ROOT"
echo ""
echo -e "${GREEN}Latest version deployed successfully!${NC}"

echo ""
echo "Commands:"
echo "  - View logs: journalctl -u $SERVICE_NAME -f"
echo "  - Test site: curl https://sai.altermundi.net"
echo "  - Rollback: tar -xzf $BACKUP_DIR/$BACKUP_NAME -C /"
echo "  - Restart proxy: sudo systemctl restart $SERVICE_NAME"