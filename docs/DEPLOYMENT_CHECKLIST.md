# SAI Web Deployment Checklist

This checklist ensures consistent and reliable deployments of the SAI (Sistema de Alerta de Incendios) web application.

## Pre-Deployment Checklist

### Code Preparation
- [ ] All changes committed to git
- [ ] Code reviewed and approved
- [ ] Branch is up to date with main
- [ ] Version number updated in relevant files
- [ ] DEPLOY_HISTORY.md entry prepared

### Configuration Verification
- [ ] `config/webhook.json` contains correct production webhook URL
- [ ] All environment-specific settings reviewed
- [ ] No hardcoded development URLs in code
- [ ] No debug mode enabled in production code

### Testing
- [ ] All automated tests passing
- [ ] Manual testing completed on staging environment
- [ ] Cross-browser testing completed (Chrome, Firefox, Safari, Edge)
- [ ] Mobile responsiveness verified (iOS, Android)
- [ ] Form submissions tested with production webhook
- [ ] Language switching tested (ES/EN)

### Security Review
- [ ] No sensitive data in codebase
- [ ] No exposed API keys or secrets
- [ ] HTTPS enforcement configured
- [ ] Security headers configured on server
- [ ] Content Security Policy (CSP) reviewed

### Asset Verification
- [ ] All images optimized and present
- [ ] Favicon files in place
- [ ] CSS and JavaScript minified (if applicable)
- [ ] No broken internal links
- [ ] External resources (YouTube) accessible

## Deployment Steps

### 1. Backup Current Production
```bash
# Create timestamped backup
BACKUP_DIR="/var/backups/sai-web/$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"
sudo rsync -av /var/www/sai/ "$BACKUP_DIR/"
```

### 2. Deploy New Version
```bash
# Deploy static files
sudo rsync -av --delete \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='scripts' \
  --exclude='*.md' \
  --exclude='.gitignore' \
  /home/fede/REPOS/sai-web/static/ /var/www/sai/

# Set correct permissions
sudo chown -R www-data:www-data /var/www/sai/
sudo find /var/www/sai/ -type d -exec chmod 755 {} \;
sudo find /var/www/sai/ -type f -exec chmod 644 {} \;
```

### 3. Server Configuration
```bash
# Verify nginx configuration
sudo nginx -t

# Reload nginx if config is valid
sudo systemctl reload nginx

# Check service status
sudo systemctl status nginx
```

## Post-Deployment Verification

### Functional Checks
- [ ] Homepage loads correctly (both languages)
- [ ] Navigation between pages works
- [ ] Modal dialogs open and close properly
- [ ] Video pages load and play content
- [ ] Form submission reaches webhook endpoint
- [ ] Language switcher functions correctly

### Technical Checks
- [ ] HTTPS certificate valid and working
- [ ] No mixed content warnings
- [ ] No console errors in browser
- [ ] Page load time acceptable (<3 seconds)
- [ ] All assets loading (check Network tab)
- [ ] Correct HTTP response codes (200, not 404)

### Monitoring Setup
- [ ] Server logs monitored for errors
- [ ] Uptime monitoring configured
- [ ] SSL certificate expiry monitoring active
- [ ] Webhook endpoint monitoring enabled

## Rollback Procedure

If critical issues are discovered post-deployment:

### 1. Immediate Rollback
```bash
# Restore from backup
sudo rsync -av --delete /var/backups/sai-web/[TIMESTAMP]/ /var/www/sai/

# Reload web server
sudo systemctl reload nginx
```

### 2. Verify Rollback
- [ ] Previous version restored successfully
- [ ] All functionality working as before
- [ ] No residual issues from failed deployment

### 3. Post-Mortem
- [ ] Document what went wrong
- [ ] Update deployment procedures
- [ ] Fix issues in development environment
- [ ] Re-test before next deployment attempt

## Emergency Contacts

- **System Administrator**: [Contact Info]
- **Project Lead**: [Contact Info]
- **On-call Developer**: [Contact Info]
- **Hosting Provider Support**: [Contact Info]

## Server Details

### Production Environment
- **Server**: [Server Name/IP]
- **OS**: Debian 12
- **Web Server**: nginx
- **Document Root**: `/var/www/sai/`
- **Config Location**: `/etc/nginx/sites-available/sai`
- **SSL Certificate**: Let's Encrypt
- **Monitoring**: [Monitoring System]

### Required Server Modules
- nginx with SSL module
- gzip compression enabled
- Headers module for security headers
- Rewrite module for URL handling

## Notes

- Always perform deployments during low-traffic periods
- Keep communication channels open during deployment
- Have rollback plan ready before starting
- Document any deviations from standard procedure
- Update DEPLOY_HISTORY.md immediately after deployment