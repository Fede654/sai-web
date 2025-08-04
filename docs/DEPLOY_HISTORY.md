# SAI Web Deployment History

This document maintains a comprehensive log of all production deployments for the SAI (Sistema de Alerta de Incendios) web application.

## Deployment Log Format

Each deployment entry follows semantic versioning and includes:
- **Version**: Semantic version number (MAJOR.MINOR.PATCH)
- **Date**: ISO 8601 format (YYYY-MM-DD HH:MM:SS UTC)
- **Commit**: Git commit SHA reference
- **Deployer**: Person or system performing deployment
- **Environment**: Target deployment environment
- **Changes**: Summary of changes included
- **Notes**: Additional deployment notes or issues

---

## Deployment History

### v1.0.0-test.1 - Test Environment Deployment

**Date**: 2025-08-01  
**Commit**: `a606e84` (main)  
**Deployer**: fede  
**Environment**: Test (https://sai.altermundi.net/test)  
**Type**: Test Deployment  

#### Changes
- Initial deployment to test subdirectory
- Path adjustments for /test URL structure
- All features from v1.0.0 included

#### Deployment Method
- Used `scripts/deploy-test.sh` for automated deployment
- Files deployed to `/var/www/sai/test/`
- Automatic path rewriting for subdirectory hosting

#### Post-deployment Notes
- All assets loading correctly from /test path
- Language switching functional
- Video embedding working
- Modal dialogs operational

---

### v1.0.0 - Initial Production Deployment

**Date**: 2025-08-01 (Pending)  
**Commit**: `a606e84` (main)  
**Deployer**: TBD  
**Environment**: Production  
**Type**: Initial Release  

#### Changes
- Initial bilingual static website (Spanish/English)
- Landing pages with hero sections and modal dialogs
- Video showcase pages with YouTube integration
- Responsive design with wildfire background imagery
- Complete navigation system between pages and languages
- Favicon and modern UI components

#### Pre-deployment Checklist
- [ ] Verify all static assets are present in `/static/`
- [ ] Confirm webhook configuration is properly set
- [ ] Test both language versions (ES/EN)
- [ ] Validate responsive design on mobile devices
- [ ] Check video embedding functionality
- [ ] Verify navigation links between pages
- [ ] Test modal dialog functionality
- [ ] Confirm favicon displays correctly

#### Infrastructure Requirements
- Static web server (nginx/Apache)
- SSL/TLS certificate configuration
- Domain DNS configuration
- Port 80/443 access

#### Configuration Files
- `config/webhook.json` - Webhook endpoint configuration
- `static/` - All static website assets
- `scripts/` - Configuration and testing utilities

#### Post-deployment Verification
- [ ] Site accessible via HTTPS
- [ ] All pages load without errors
- [ ] Forms submit to correct webhook endpoint
- [ ] Language switching works correctly
- [ ] Video content loads properly
- [ ] Mobile responsiveness verified
- [ ] Browser console free of errors

#### Rollback Procedure
1. Keep previous version backup in `deployments/backup/v{previous}/`
2. If issues arise, restore from backup: `rsync -av deployments/backup/v{previous}/ /var/www/sai/`
3. Restart web server: `sudo systemctl restart nginx`
4. Verify rollback successful

---

## Version History Reference

### Versioning Strategy
- **MAJOR**: Incompatible API changes or major feature additions
- **MINOR**: New functionality in backwards compatible manner
- **PATCH**: Backwards compatible bug fixes

### Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch for features
- `feature/*`: Individual feature development
- `hotfix/*`: Emergency production fixes

### Deployment Environments
- **Production**: Live public-facing site
- **Staging**: Pre-production testing
- **Development**: Local development servers

---

## Notes

- All timestamps in UTC
- Commit SHAs reference the main branch unless otherwise noted
- Deployment checklist must be completed for each production deployment
- Keep backup of previous version for immediate rollback capability