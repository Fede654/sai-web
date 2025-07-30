# SAI Website Deployment Guide

## Secure Server Proxy Deployment

This guide covers deploying the SAI website with a secure server proxy that keeps your n8n webhook credentials completely hidden.

## Architecture

```
User Browser → Your Server (proxy) → n8n Webhook
   (no keys)     (has API key)      (protected)
```

**Security Benefits:**
- ✅ No API keys visible in HTML source code
- ✅ No API keys in GitHub repository  
- ✅ Rate limiting and bot protection
- ✅ Server-side validation
- ✅ Request logging and monitoring

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/youruser/sai-web
cd sai-web
npm install
```

### 2. Configure Environment
```bash
# Copy example environment file
cp .env.example .env

# Edit with your values
nano .env
```

Required environment variables:
```bash
N8N_WEBHOOK_URL=https://your-n8n-instance.com/webhook/your-webhook-id
N8N_API_KEY=your-secret-api-key-here
NODE_ENV=production
PORT=8080
```

### 3. Start Server
```bash
# Production
npm start

# Development (with test endpoint)
npm run dev
```

### 4. Test Configuration
```bash
# Test webhook connectivity
npm run test-webhook

# Manual test
curl -X POST http://localhost:8080/api/test-webhook
```

## Production Deployment

### Option 1: Direct Server Deployment

```bash
# Install Node.js and dependencies
sudo apt update
sudo apt install nodejs npm
npm install

# Configure environment
cp .env.example .env
# Edit .env with your credentials

# Start with PM2 (recommended)
npm install -g pm2
pm2 start server.js --name sai-website
pm2 startup
pm2 save
```

### Option 2: Docker Deployment

```dockerfile
# Dockerfile (create this)
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
```

```bash
# Build and run
docker build -t sai-website .
docker run -d -p 8080:8080 --env-file .env sai-website
```

### Option 3: Reverse Proxy with Nginx

```nginx
# /etc/nginx/sites-available/sai-website
server {
    listen 80;
    server_name yourdomain.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## n8n Webhook Configuration

### 1. Create Webhook Node
- Add "Webhook" node to your n8n workflow
- Set Method: `POST`
- Set Path: `/sai-form` (or your preferred path)

### 2. Add Authentication Check
Add a "Code" node after webhook with:

```javascript
// Check API key authentication
const apiKey = $('Webhook').first().headers['x-api-key'];
const expectedKey = process.env.SAI_API_KEY; // Set in n8n environment

if (!apiKey || apiKey !== expectedKey) {
  throw new Error('Unauthorized: Invalid API key');
}

// Data is valid, continue processing
return $input.all();
```

### 3. Set Environment Variables in n8n
- Go to n8n Settings → Environment Variables
- Add: `SAI_API_KEY=your-secret-api-key-here`

## Security Features

### Server-Side Protection
- **Rate Limiting**: 5 form submissions per 15 minutes per IP
- **Input Validation**: Required fields, email format validation
- **Honeypot Detection**: Automatic bot filtering
- **Request Logging**: Monitor all submissions
- **Error Handling**: No sensitive data in error responses

### n8n Integration
- **API Key Authentication**: X-API-Key header validation
- **Timeout Protection**: 10-second request timeout
- **Retry Logic**: Automatic retry on network errors
- **Metadata Enrichment**: IP address, timestamp, user agent tracking

## Monitoring and Maintenance

### Health Checks
```bash
# Server health
curl http://localhost:8080/health

# Response should be:
{
  "status": "healthy",
  "timestamp": "2025-07-30T06:00:00.000Z",
  "version": "1.0.0"
}
```

### Log Monitoring
```bash
# PM2 logs
pm2 logs sai-website

# Direct server logs
NODE_ENV=production node server.js
```

### Security Monitoring
Monitor these events in your logs:
- Honeypot triggers (potential bots)
- Rate limit violations
- Invalid API key attempts
- n8n webhook failures

## Troubleshooting

### Common Issues

**Server won't start:**
```bash
# Check environment variables
node -e "console.log(process.env.N8N_WEBHOOK_URL)"

# Check port availability
netstat -tulpn | grep :8080
```

**Form submissions failing:**
```bash
# Test webhook directly
curl -X POST http://localhost:8080/api/test-webhook

# Check n8n logs for authentication errors
```

**High memory usage:**
```bash
# Monitor Node.js performance
pm2 monit

# Restart if needed
pm2 restart sai-website
```

### Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `N8N_WEBHOOK_URL` | Yes | Full n8n webhook URL | `https://n8n.example.com/webhook/sai-form` |
| `N8N_API_KEY` | Yes | Secret API key for authentication | `abc123xyz789` |
| `NODE_ENV` | No | Node.js environment | `production` |
| `PORT` | No | Server port | `8080` |
| `ALLOWED_ORIGINS` | No | CORS allowed origins | `https://yourdomain.com` |

## Migration from Static Files

If migrating from the static file approach:

1. **Backup current setup**
2. **Deploy new server** with environment variables
3. **Update DNS/proxy** to point to new server
4. **Test form submissions** end-to-end
5. **Monitor logs** for issues

The new server serves the same static files but adds the secure API proxy layer.