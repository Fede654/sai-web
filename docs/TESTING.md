# SAI Testing Documentation

This document describes the comprehensive test suite for SAI deployment validation.

## Test Scripts

### 1. `scripts/test-deployment.sh` - Complete Deployment Test Suite

**Purpose**: Full deployment validation with server access  
**Requirements**: SSH access to server, curl, timeout commands  
**Runtime**: ~2-3 minutes  

#### Test Categories:

**🌐 Website Accessibility**
- Spanish website responds (200 OK)
- English website responds (200 OK) 
- Favicon accessible
- Background image accessible

**📄 Website Content**
- Spanish title present ("Sistema de Alerta de Incendios")
- English title present ("Fire Alert System")
- Hero section content verification
- Nosotros section present
- GitHub link present (github.com/altermundi)

**📝 Form Configuration**
- Form API endpoint configured (/api/submit-form)
- Required form fields present (localidad, telefono, email)
- All form fields match expected structure

**🎥 Video Integration**
- YouTube embed configured (bbmto6GVLh8)
- Video overlay JavaScript present
- Video trigger button present

**🎨 Theme Elements**
- Celeste color variables present (#74ACDF, #5691C8)
- Argentine theme styling present
- Background image configured

**🔧 Proxy Server** (requires SSH)
- Health endpoint responds
- Version 1.2.0 running
- Authentication configured
- Service status healthy

**📤 Form Submission** (requires SSH)
- Form submission works end-to-end
- Phone number cleaning works (+54 removal)
- Data reaches n8n webhook

**🔒 Security Headers**
- HTTPS redirect works
- HSTS header present

**⚡ Performance**
- Page loads within 5 seconds
- Images load within 10 seconds

**🧹 Cleanup Verification**
- Old video pages return 404
- Test directory removed

#### Usage:

```bash
# Run all tests
./scripts/test-deployment.sh

# Quick essential tests only
./scripts/test-deployment.sh --quick

# Verbose output
./scripts/test-deployment.sh --verbose

# Custom configuration
WEBSITE_URL=https://test.example.com ./scripts/test-deployment.sh
```

### 2. `scripts/test-website.sh` - Public Website Test Suite

**Purpose**: Website validation without server access  
**Requirements**: curl only  
**Runtime**: ~30 seconds  

#### Test Categories:

**🌐 Website Accessibility**
- Response codes (200 OK)
- Image accessibility

**📄 Content Verification**
- Titles and core content
- Form configuration
- Video integration
- Links verification

**🔒 Security**
- HTTPS enforcement
- Security headers

**🧹 Cleanup**
- Removed pages return 404

#### Usage:

```bash
# Run public tests
./scripts/test-website.sh

# Test different URL
WEBSITE_URL=https://staging.example.com ./scripts/test-website.sh
```

## Test Results Interpretation

### Exit Codes
- `0` - All tests passed
- `1` - One or more tests failed

### Output Format
- ✅ Green checkmark - Test passed
- ❌ Red X - Test failed  
- ⚠️ Yellow warning - Test skipped or warning
- ℹ️ Blue info - Test category or information

### Common Test Failures

**Website Not Responding**
```
❌ Spanish website responds (200) - Expected: 200, Got: 000
```
- Check DNS resolution
- Verify nginx/web server running
- Check firewall rules

**Content Missing**
```
❌ Form endpoint configured - Expected: /api/submit-form, Got: 
```
- Website files not updated
- Cache issues (clear browser/CDN cache)
- Wrong version deployed

**Proxy Server Issues**
```
❌ Proxy server health endpoint - Expected: 1, Got: 0
```
- Service not running: `systemctl status sai-proxy`
- Port blocked: check firewall
- Configuration error: check logs

**Form Submission Failing**
```
❌ Form submission works - Expected: 1, Got: 0
```
- API key configuration
- n8n webhook down
- Network connectivity issues

## Integration with CI/CD

### Post-Deployment Hook
```bash
#!/bin/bash
# Add to deployment script
echo "Running deployment tests..."
if ./scripts/test-deployment.sh --quick; then
    echo "Deployment validated successfully"
else
    echo "Deployment validation failed - rolling back"
    exit 1
fi
```

### Monitoring Integration
```bash
# Cron job for periodic health checks
*/15 * * * * /path/to/sai-web/scripts/test-website.sh > /var/log/sai-health.log 2>&1
```

### GitHub Actions Example
```yaml
name: Deployment Test
on:
  deployment_status:
    types: [success]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Test Deployment
        run: ./scripts/test-website.sh
```

## Test Data

### Mock Form Submission Data
```json
{
  "localidad": "Test City Deploy",
  "departamento": "Test Dept", 
  "provincia": "Test Province",
  "nombre": "Deploy",
  "apellido": "Test",
  "telefono": "+54 11 1234 5678",
  "email": "deploy-test@example.com",
  "test": "true"
}
```

### Expected Response Patterns
- **Success Response**: `{"success":true,"message":"Form submitted successfully"}`
- **Health Check**: `{"status":"ok","version":"1.2.0"}`
- **HTTP Status**: `200`, `404` for removed pages

## Manual Testing Checklist

When automated tests aren't available:

### Website Visual Check
- [ ] Spanish page loads with celeste theme
- [ ] English page loads correctly
- [ ] Background image displays
- [ ] Video overlay works
- [ ] Form fields all present
- [ ] GitHub link works
- [ ] Mobile responsive

### Functionality Check  
- [ ] Form submission works
- [ ] Success/error messages appear
- [ ] Video plays in overlay
- [ ] Navigation scroll works
- [ ] All sections visible

### Technical Check
- [ ] HTTPS certificate valid
- [ ] Page load speed acceptable
- [ ] No console errors
- [ ] Proxy server responding
- [ ] Health endpoint works

## Troubleshooting

### Test Script Issues

**Permission Denied**
```bash
chmod +x scripts/test-deployment.sh scripts/test-website.sh
```

**Command Not Found**
```bash
# Install required tools on Ubuntu/Debian
sudo apt-get install curl timeout ssh
```

**SSH Connection Failed**
```bash
# Check SSH key configuration
ssh-add ~/.ssh/your-key
ssh root@sai.altermundi.net whoami
```

### Common Fixes

**Cache Issues**: Clear browser cache, CDN cache  
**DNS Issues**: Check domain resolution with `nslookup`  
**SSL Issues**: Verify certificate with `openssl s_client`  
**Service Issues**: Check with `systemctl status nginx sai-proxy`

## Best Practices

1. **Run tests after every deployment**
2. **Use quick mode for CI/CD pipelines** 
3. **Run full suite for major updates**
4. **Monitor test results over time**
5. **Update tests when adding new features**
6. **Keep test data realistic but safe**
7. **Document any test exclusions**

The test suite provides confidence that deployments are successful and the SAI system is functioning correctly for end users.