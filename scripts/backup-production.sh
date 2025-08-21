#!/bin/bash

# SAI Production Backup Script
# Creates comprehensive backup including nginx configuration

set -e

# Configuration
BACKUP_DIR="/var/backups/sai-web"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="sai-production-backup-$TIMESTAMP"
LOG_FILE="/var/log/sai-backup.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

log "Starting SAI production backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create comprehensive backup
log "Creating backup: $BACKUP_NAME.tar.gz"

# Files to backup
BACKUP_ITEMS=(
    "/var/www/sai"                              # Website files
    "/opt/sai-proxy"                            # Proxy server
    "/etc/nginx/sites-available/sai"            # Nginx configuration
    "/etc/systemd/system/sai-proxy.service"     # Systemd service
    "/etc/letsencrypt/live/sai.altermundi.net"  # SSL certificates
    "/etc/letsencrypt/renewal/sai.altermundi.net.conf" # SSL renewal config
)

# Create backup with exclusions
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    --exclude='*/node_modules' \
    --exclude='*/.git' \
    --exclude='*/logs/*.log' \
    "${BACKUP_ITEMS[@]}" \
    2>/dev/null || warning "Some files may not have been backed up"

# Create configuration-only backup
log "Creating configuration backup: $BACKUP_NAME-config.tar.gz"

CONFIG_ITEMS=(
    "/etc/nginx/sites-available/sai"
    "/etc/systemd/system/sai-proxy.service"
    "/opt/sai-proxy/.env"
    "/opt/sai-proxy/config/webhook.json"
    "/etc/letsencrypt/live/sai.altermundi.net"
    "/etc/letsencrypt/renewal/sai.altermundi.net.conf"
)

tar -czf "$BACKUP_DIR/$BACKUP_NAME-config.tar.gz" \
    "${CONFIG_ITEMS[@]}" \
    2>/dev/null || warning "Some config files may not exist"

# Generate backup report
cat > "$BACKUP_DIR/$BACKUP_NAME-report.txt" << EOF
SAI Production Backup Report
Generated: $(date)
Backup Name: $BACKUP_NAME

=== INCLUDED FILES ===
Website Files: /var/www/sai
Proxy Server: /opt/sai-proxy (excluding node_modules)
Nginx Config: /etc/nginx/sites-available/sai
Systemd Service: /etc/systemd/system/sai-proxy.service
SSL Certificates: /etc/letsencrypt/live/sai.altermundi.net
SSL Renewal Config: /etc/letsencrypt/renewal/sai.altermundi.net.conf

=== BACKUP FILES ===
Full Backup: $BACKUP_NAME.tar.gz
Config Only: $BACKUP_NAME-config.tar.gz
This Report: $BACKUP_NAME-report.txt

=== SYSTEM STATUS AT BACKUP TIME ===
EOF

# Add system status to report
{
    echo "Nginx Status: $(systemctl is-active nginx)"
    echo "SAI Proxy Status: $(systemctl is-active sai-proxy)"
    echo "SSL Certificate Expiry:"
    openssl x509 -in /etc/letsencrypt/live/sai.altermundi.net/cert.pem -noout -dates 2>/dev/null || echo "Certificate info unavailable"
    echo ""
    echo "Disk Usage:"
    df -h /var/www /opt
    echo ""
    echo "Active Connections:"
    ss -tn state established '( dport = :8003 or sport = :8003 )' | wc -l | xargs echo "SAI Proxy connections: "
} >> "$BACKUP_DIR/$BACKUP_NAME-report.txt"

# Get backup sizes
FULL_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)
CONFIG_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME-config.tar.gz" | cut -f1)

log "Backup completed successfully!"
echo ""
echo "Backup Details:"
echo "  Full backup: $BACKUP_NAME.tar.gz ($FULL_SIZE)"
echo "  Config backup: $BACKUP_NAME-config.tar.gz ($CONFIG_SIZE)"
echo "  Report: $BACKUP_NAME-report.txt"
echo ""

# Clean up old backups (keep last 10)
log "Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -t sai-production-backup-*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm
ls -t sai-production-backup-*-config.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm  
ls -t sai-production-backup-*-report.txt 2>/dev/null | tail -n +11 | xargs -r rm

REMAINING=$(ls -1 sai-production-backup-*.tar.gz 2>/dev/null | wc -l)
log "Backup cleanup complete. $REMAINING backup sets retained."

echo ""
echo "To restore from this backup:"
echo "  sudo tar -xzf $BACKUP_DIR/$BACKUP_NAME.tar.gz -C /"
echo "  sudo systemctl restart sai-proxy nginx"
echo ""
echo "To restore config only:"
echo "  sudo tar -xzf $BACKUP_DIR/$BACKUP_NAME-config.tar.gz -C /"