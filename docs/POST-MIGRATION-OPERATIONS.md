# Post-Migration Operations Manual

## Overview

This document details the operational procedures for the SAI system after migrating to the git-based deployment model with consolidated directory structure.

## Daily Operations

### 1. Monitoring

#### Real-time Monitoring Dashboard
```bash
# Create monitoring script
cat > /usr/local/bin/sai-monitor << 'EOF'
#!/bin/bash
clear
echo "=== SAI System Monitor ==="
echo ""
echo "Services Status:"
systemctl is-active sai-proxy | xargs echo "Proxy Server: "
systemctl is-active nginx | xargs echo "Nginx: "
echo ""
echo "Resource Usage:"
systemctl status sai-proxy | grep Memory
echo ""
echo "Recent Submissions (last 10):"
journalctl -u sai-proxy | grep "Form submission" | tail -10
echo ""
echo "Active Connections:"
ss -tn state established '( dport = :8003 or sport = :8003 )' | wc -l | xargs echo "Proxy connections: "
echo ""
echo "Press Ctrl+C to exit"
EOF
chmod +x /usr/local/bin/sai-monitor

# Run monitor
sai-monitor
```

#### Check Service Health
```bash
# Quick health check
curl -s http://localhost:8003/api/health | jq '.'

# Full system status
systemctl status sai-proxy --no-pager
systemctl status nginx --no-pager

# Check last 50 log entries
journalctl -u sai-proxy -n 50 --no-pager
```

### 2. Routine Updates

#### Standard Update Procedure
```bash
# 1. Navigate to project directory
cd /var/www/sai

# 2. Check current status
git status
git branch -v

# 3. Pull latest changes
git pull origin main

# 4. Check if dependencies changed
git diff HEAD@{1} package.json

# 5. If package.json changed, update dependencies
npm install --production

# 6. Restart service
systemctl restart sai-proxy

# 7. Verify deployment
curl http://localhost:8003/api/health
```

#### Automated Update Script
```bash
# This script is created by migration at /var/www/sai/update.sh
#!/bin/bash
cd /var/www/sai
echo "Pulling latest changes..."
git pull origin main

echo "Installing dependencies..."
npm install --production

echo "Restarting service..."
sudo systemctl restart sai-proxy

echo "Checking health..."
sleep 2
curl -s http://localhost:8003/api/health | grep -q "ok" && echo "✓ Update successful!" || echo "✗ Health check failed!"
```

### 3. Configuration Management

#### Update Webhook Credentials
```bash
# Edit environment file
nano /var/www/sai/.env

# Update these values:
N8N_WEBHOOK_URL=https://your-new-n8n-instance.com/webhook/xxx
N8N_API_KEY=your-new-api-key

# Restart to apply changes
systemctl restart sai-proxy

# Verify new configuration
journalctl -u sai-proxy | tail -20
```

#### Update Webhook URL in HTML
```bash
cd /var/www/sai

# Method 1: Interactive configuration
npm run configure

# Method 2: Direct edit
nano config/webhook.json
# Then rebuild
npm run build
```

### 4. Backup Procedures

#### Manual Backup
```bash
# Create backup with timestamp
BACKUP_DIR="/var/backups/sai-web"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR

# Backup entire deployment
tar -czf "$BACKUP_DIR/sai-backup-$TIMESTAMP.tar.gz" \
    -C /var/www sai \
    --exclude='sai/node_modules' \
    --exclude='sai/.git'

# Backup configurations only
tar -czf "$BACKUP_DIR/sai-config-$TIMESTAMP.tar.gz" \
    /var/www/sai/.env \
    /var/www/sai/config/webhook.json \
    /etc/nginx/sites-available/sai.altermundi.net \
    /etc/systemd/system/sai-proxy.service

echo "Backup created: $BACKUP_DIR/sai-backup-$TIMESTAMP.tar.gz"
```

#### Automated Daily Backup (Cron)
```bash
# Add to root's crontab
crontab -e

# Add this line for daily 3 AM backup
0 3 * * * /usr/local/bin/sai-backup.sh

# Create backup script
cat > /usr/local/bin/sai-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/sai-web"
TIMESTAMP=$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# Create backup
tar -czf "$BACKUP_DIR/sai-daily-$TIMESTAMP.tar.gz" \
    -C /var/www sai \
    --exclude='sai/node_modules' \
    --exclude='sai/.git' \
    2>/dev/null

# Keep only last 7 daily backups
ls -t $BACKUP_DIR/sai-daily-*.tar.gz | tail -n +8 | xargs -r rm

# Log backup
echo "[$(date)] Daily backup completed: sai-daily-$TIMESTAMP.tar.gz" >> /var/log/sai-backup.log
EOF
chmod +x /usr/local/bin/sai-backup.sh
```

### 5. Log Management

#### View Logs
```bash
# Real-time proxy logs
journalctl -u sai-proxy -f

# Today's submissions
journalctl -u sai-proxy --since today | grep "Form submission"

# Error logs only
journalctl -u sai-proxy -p err --since yesterday

# Export logs for analysis
journalctl -u sai-proxy --since "2025-08-01" --until "2025-08-10" > /tmp/sai-logs.txt
```

#### Log Rotation
```bash
# Configure logrotate
cat > /etc/logrotate.d/sai-proxy << EOF
/var/log/sai-proxy*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload sai-proxy > /dev/null 2>&1 || true
    endscript
}
EOF
```

## Maintenance Tasks

### Weekly Maintenance

```bash
#!/bin/bash
# Weekly maintenance script

echo "=== SAI Weekly Maintenance ==="
echo ""

# 1. Check for updates
echo "1. Checking for updates..."
cd /var/www/sai
git fetch
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
if [ "$LOCAL" != "$REMOTE" ]; then
    echo "   Updates available! Run: cd /var/www/sai && ./update.sh"
else
    echo "   System is up to date"
fi

# 2. Check disk space
echo ""
echo "2. Disk usage:"
df -h / | tail -1

# 3. Check service uptime
echo ""
echo "3. Service uptime:"
systemctl status sai-proxy | grep Active

# 4. Count submissions this week
echo ""
echo "4. Submissions this week:"
journalctl -u sai-proxy --since "1 week ago" | grep -c "Form submission successful" | xargs echo "   Total: "

# 5. Check SSL certificate
echo ""
echo "5. SSL Certificate:"
echo -n "   Expires: "
echo | openssl s_client -servername sai.altermundi.net -connect sai.altermundi.net:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2

# 6. Test webhook connectivity
echo ""
echo "6. Webhook connectivity:"
curl -s http://localhost:8003/api/health | grep -q "ok" && echo "   ✓ API is responsive" || echo "   ✗ API is not responding"

echo ""
echo "Maintenance check complete!"
```

### Monthly Tasks

1. **Review and Clean Logs:**
```bash
# Archive old logs
tar -czf /var/backups/sai-logs-$(date +%Y%m).tar.gz /var/log/sai-proxy*.log.*.gz
rm /var/log/sai-proxy*.log.*.gz

# Clean old backups (keep last 3 months)
find /var/backups/sai-web -name "*.tar.gz" -mtime +90 -delete
```

2. **Security Updates:**
```bash
# Check for security updates
apt update
apt list --upgradable | grep -E "nginx|node|npm"

# Update if needed (carefully)
apt upgrade nginx nodejs npm
```

3. **Performance Review:**
```bash
# Generate performance report
cat > /tmp/sai-performance.sh << 'EOF'
#!/bin/bash
echo "SAI Performance Report - $(date)"
echo "================================"
echo ""
echo "Average response time (last 1000 requests):"
journalctl -u sai-proxy -n 1000 | grep "Form submission successful" | \
    awk '{print $NF}' | awk '{sum+=$1; count++} END {print sum/count "ms"}'
echo ""
echo "Peak hours (submissions by hour):"
journalctl -u sai-proxy --since "30 days ago" | grep "Form submission" | \
    awk '{print $3}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -5
echo ""
echo "Top locations (last 30 days):"
journalctl -u sai-proxy --since "30 days ago" | grep "Form submission from" | \
    awk -F"from " '{print $2}' | sort | uniq -c | sort -rn | head -10
EOF
bash /tmp/sai-performance.sh
```

## Troubleshooting Procedures

### Service Won't Start

```bash
# Step 1: Check for errors
journalctl -u sai-proxy -n 100 | grep -i error

# Step 2: Test configuration
cd /var/www/sai
node -c proxy-server.js  # Check syntax

# Step 3: Check port availability
lsof -i :8003
# If port is in use, kill the process or change port

# Step 4: Check permissions
ls -la /var/www/sai/.env
ls -la /var/www/sai/proxy-server.js
# Should be owned by www-data

# Step 5: Try manual start for debugging
su - www-data -s /bin/bash
cd /var/www/sai
NODE_ENV=development node proxy-server.js
```

### High Memory Usage

```bash
# Check current usage
ps aux | grep node | grep proxy

# Restart to clear memory
systemctl restart sai-proxy

# If persistent, check for memory leaks
# Install monitoring
npm install -g clinic
cd /var/www/sai
clinic doctor -- node proxy-server.js
```

### Webhook Failures

```bash
# Test webhook directly
source /var/www/sai/.env
curl -X POST "$N8N_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $N8N_API_KEY" \
  -d '{"test": true}'

# Check network connectivity
ping -c 4 $(echo $N8N_WEBHOOK_URL | cut -d/ -f3)

# Check DNS resolution
nslookup $(echo $N8N_WEBHOOK_URL | cut -d/ -f3)

# Test with proxy server's test endpoint
curl -X POST http://localhost:8003/api/test-webhook
```

## Emergency Procedures

### Complete Service Failure

```bash
# 1. Quick restore from backup
LATEST_BACKUP=$(ls -t /var/backups/sai-web/sai-backup-*.tar.gz | head -1)
tar -xzf $LATEST_BACKUP -C /

# 2. Restart services
systemctl restart sai-proxy nginx

# 3. Verify restoration
curl http://localhost:8003/api/health
```

### Rollback After Bad Update

```bash
# 1. Stop service
systemctl stop sai-proxy

# 2. Revert to previous git commit
cd /var/www/sai
git log --oneline -n 5  # Find the commit to revert to
git reset --hard <commit-hash>

# 3. Reinstall dependencies
npm install --production

# 4. Restart service
systemctl start sai-proxy

# 5. Verify
curl http://localhost:8003/api/health
```

### DDoS or High Load

```bash
# 1. Enable emergency rate limiting
cd /var/www/sai
# Edit .env to add stricter limits
echo "RATE_LIMIT_WINDOW=1" >> .env
echo "RATE_LIMIT_MAX=2" >> .env
systemctl restart sai-proxy

# 2. Block suspicious IPs with firewall
# Check access logs for patterns
tail -f /var/log/nginx/access.log | grep "/api/submit-form"

# Block IP if needed
iptables -A INPUT -s SUSPICIOUS_IP -j DROP

# 3. Enable Cloudflare if available
# Update DNS to route through Cloudflare proxy
```

## Performance Optimization

### Enable PM2 Cluster Mode

```bash
# Install PM2
npm install -g pm2

# Create ecosystem file
cat > /var/www/sai/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'sai-proxy',
    script: 'proxy-server.js',
    instances: 4,  // Or 'max' for all CPU cores
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 8003
    },
    error_file: '/var/log/pm2/sai-error.log',
    out_file: '/var/log/pm2/sai-out.log',
    merge_logs: true,
    time: true
  }]
}
EOF

# Stop systemd service
systemctl stop sai-proxy
systemctl disable sai-proxy

# Start with PM2
cd /var/www/sai
pm2 start ecosystem.config.js
pm2 save
pm2 startup systemd -u www-data --hp /home/www-data
```

### Enable Redis Cache (Optional)

```bash
# Install Redis
apt install redis-server

# Configure Redis for caching
cat >> /etc/redis/redis.conf << EOF
maxmemory 100mb
maxmemory-policy allkeys-lru
EOF

systemctl restart redis

# Update proxy server to use Redis
# (Requires code modification in proxy-server.js)
```

## Reporting

### Generate Monthly Report

```bash
#!/bin/bash
# Save as /usr/local/bin/sai-monthly-report.sh

MONTH=$(date +%B)
YEAR=$(date +%Y)
REPORT_FILE="/var/reports/sai-report-$YEAR-$MONTH.txt"
mkdir -p /var/reports

cat > $REPORT_FILE << EOF
SAI System Monthly Report
$MONTH $YEAR
========================

1. SUBMISSIONS SUMMARY
----------------------
EOF

# Total submissions
echo "Total Submissions: $(journalctl -u sai-proxy --since "1 month ago" | grep -c "Form submission successful")" >> $REPORT_FILE

# By province
echo -e "\nBy Province:" >> $REPORT_FILE
journalctl -u sai-proxy --since "1 month ago" | grep "Form submission from" | \
    awk -F", " '{print $2}' | sort | uniq -c | sort -rn >> $REPORT_FILE

# System uptime
echo -e "\n2. SYSTEM RELIABILITY\n----------------------" >> $REPORT_FILE
echo "Service Uptime: $(systemctl status sai-proxy | grep Active | awk '{print $9, $10, $11}')" >> $REPORT_FILE

# Errors
echo "Total Errors: $(journalctl -u sai-proxy --since "1 month ago" -p err | wc -l)" >> $REPORT_FILE

echo -e "\nReport saved to: $REPORT_FILE"
```

This comprehensive operations manual ensures smooth day-to-day management of the SAI system after migration to the git-based deployment model.