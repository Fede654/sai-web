# SAI Proxy Server - Production v1.2.0

## Production Ready Features

### ✅ Security Hardened
- **Debug endpoints removed** - No configuration exposure in production
- **Minimal logging** - Only essential information logged (city/province, success/error)
- **Sensitive data protection** - No personal data logged to system logs
- **Environment isolation** - All sensitive config in `.env` file

### ✅ Phone Number Processing
- **Automatic cleaning** - Removes "+54" country code and spaces
- **Consistent format** - Ensures numeric-only phone numbers in n8n
- **Input flexibility** - Handles various user input formats

### ✅ Production Optimizations
- **Reduced verbosity** - Minimal console output in production mode
- **Error handling** - Comprehensive retry logic with exponential backoff
- **Health monitoring** - `/api/health` endpoint for service monitoring
- **Bearer authentication** - Secure API key transmission to n8n

## Deployment Status

**Current Version:** 1.2.0  
**Deployed:** sai.altermundi.net:8003  
**Status:** ✅ Active and operational  
**Authentication:** ✅ Bearer token configured  
**Phone cleaning:** ✅ Active  

## Available Endpoints

### Production Endpoints
- `POST /api/submit-form` - Form submission proxy (production ready)
- `GET /api/health` - Service health check

### Removed in Production
- ❌ `/api/debug/config` - Debug endpoint removed for security

## Service Management

```bash
# Service status
sudo systemctl status sai-proxy

# View logs (minimal in production)
sudo journalctl -u sai-proxy -f

# Health check
curl http://127.0.0.1:8003/api/health

# Restart service
sudo systemctl restart sai-proxy
```

## Configuration Files

### Required Files
- `/opt/sai-proxy/proxy-server.js` - Main application
- `/opt/sai-proxy/.env` - Environment configuration (sensitive)
- `/opt/sai-proxy/config/webhook.json` - Non-sensitive settings
- `/opt/sai-proxy/package.json` - Dependencies and scripts

### Environment Variables (.env)
```bash
NODE_ENV=production
PORT=8003
N8N_WEBHOOK_URL=https://ai.altermundi.net/pipelines/webhook/web-form-sai
N8N_API_KEY=3tafmtmp313a8jSZMCZpCi5mbYgL6eVe
LOG_LEVEL=info
```

## Form Data Processing

### Input Processing
1. **Phone Cleaning**: `"+54 381 123 4567"` → `"3811234567"`
2. **Field Validation**: All required fields checked
3. **Metadata Addition**: Timestamp, source, user agent added
4. **Authentication**: Bearer token attached to n8n request

### Success Response
```json
{
  "success": true,
  "message": "Form submitted successfully"
}
```

## Monitoring

### Key Metrics
- **Response Time**: ~2-3 seconds average
- **Success Rate**: 100% with proper configuration  
- **Error Handling**: 3 retry attempts with exponential backoff
- **Phone Cleaning**: Active for all submissions

### Log Examples (Production)
```
[2025-08-04T00:32:46.667Z] 📥 Form submission from Production Test, Test Province
[2025-08-04T00:32:46.667Z] ✅ Form submission successful
```

## Version History

- **v1.2.0** - Production ready (debug removed, phone cleaning, minimal logging)
- **v1.1.0** - Phone cleaning implemented
- **v1.0.1** - Bearer authentication fixed
- **v1.0.0** - Initial proxy server

## Next Steps

The SAI proxy server is now production ready and handles all form submissions securely with proper data processing and minimal logging for privacy compliance.