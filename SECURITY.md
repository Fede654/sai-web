# SAI Website Security Guide

## Security Implementation

This document outlines the security measures implemented to protect the webhook endpoint before publishing to GitHub.

### Implemented Security Features

#### 1. API Key Authentication
- **X-API-Key** header sent with each form submission
- Randomly generated 32-character API key
- Configured automatically via `npm run setup-security`

#### 2. Bot Protection
- **Honeypot Field**: Hidden input field that bots typically fill but humans don't see
- **Timing Validation**: Rejects forms submitted too quickly (< 3 seconds)
- **Form Load Tracking**: Measures time between page load and submission

#### 3. Request Validation
- **Timestamp Validation**: Each request includes submission timestamp
- **User Agent Tracking**: Records browser information for analysis
- **Source Tagging**: All requests tagged with source identifier

### n8n Webhook Configuration

To secure your n8n webhook, add these validation steps:

1. **Authentication Check**:
   ```javascript
   // Check X-API-Key header
   if (headers['x-api-key'] !== 'YOUR_GENERATED_API_KEY') {
     return { error: 'Unauthorized' };
   }
   ```

2. **Rate Limiting**:
   - Set up rate limiting in n8n or reverse proxy
   - Recommended: 10 requests per minute per IP

3. **Data Validation**:
   - Check for honeypot field value (should be empty)
   - Validate timestamp freshness (< 1 hour old)
   - Verify required fields are present

### Setup Commands

```bash
# Configure webhook URL and enable security
npm run setup-security

# Apply configuration to HTML files
npm run build

# Test the secure webhook
cd scripts && python3 test-webhook.py
```

### Security Considerations for GitHub

**⚠️ IMPORTANT**: When publishing to GitHub, your API key will be visible in:
- `config/webhook.json`
- HTML files (as data attributes)

**Mitigation Strategies**:

1. **Monitor Usage**: Set up alerts in n8n for unusual activity
2. **Regular Key Rotation**: Change API key periodically
3. **IP Whitelisting**: Restrict webhook access to specific IPs if possible
4. **Request Logging**: Log all webhook requests for analysis

### Production Recommendations

For production deployment, consider:

1. **Environment Variables**: Move API key to server-side environment variables
2. **Server-Side Proxy**: Use a backend service to hide the actual webhook URL
3. **CAPTCHA**: Add CAPTCHA for additional bot protection
4. **Advanced Rate Limiting**: Implement sliding window rate limiting

### Monitoring and Alerts

Monitor these metrics in your n8n instance:
- Request frequency spikes
- Failed authentication attempts
- Honeypot trigger events
- Submissions with invalid timestamps

## Testing Security

The test script (`scripts/test-webhook.py`) validates:
- API key authentication
- Proper header formatting
- Response handling

Run tests before deploying:
```bash
cd scripts
python3 test-webhook.py
```

## Security vs. Accessibility Balance

The implemented security measures are designed to:
- ✅ Block automated bot submissions
- ✅ Prevent webhook URL abuse
- ✅ Maintain normal user experience
- ✅ Work without JavaScript dependencies
- ✅ Support accessibility tools

## Incident Response

If you detect abuse:
1. Check n8n execution logs
2. Identify attack patterns
3. Update API key: `npm run setup-security`
4. Consider additional IP-based blocking