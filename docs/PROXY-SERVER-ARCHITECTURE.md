# SAI Proxy Server Architecture

## Overview

After the migration, the SAI proxy server operates as a unified Node.js application serving both static files and API endpoints, running from a single git-managed directory at `/var/www/sai`.

## Execution Flow

### 1. System Startup

```
systemd → sai-proxy.service → node /var/www/sai/proxy-server.js
```

**Service Configuration** (`/etc/systemd/system/sai-proxy.service`):
```ini
[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/sai
ExecStart=/usr/bin/node /var/www/sai/proxy-server.js
Environment=NODE_ENV=production
Environment=PORT=8003
EnvironmentFile=/var/www/sai/.env
```

### 2. Request Flow Architecture

```
User Browser
    ↓
HTTPS (443) → Nginx
    ↓
Route Decision:
    ├── Static Files → /var/www/sai/static/*
    └── API Calls (/api/*) → Proxy Server (127.0.0.1:8003)
                                 ↓
                            n8n Webhook
```

### 3. Proxy Server Components

#### Core Server (`proxy-server.js`)

**Initialization Process:**
1. Load environment variables from `.env`
2. Parse webhook configuration from `config/webhook.json`
3. Initialize Express server on port 8003
4. Set up middleware stack
5. Define API routes
6. Start listening

**Key Middleware Stack:**
```javascript
app.use(cors())           // CORS handling
app.use(express.json())   // JSON body parsing
app.use(rateLimit())      // Rate limiting
app.use(helmet())         // Security headers
app.use(logging())        // Request logging
```

#### Environment Configuration (`.env`)

```bash
# Core Settings
NODE_ENV=production
PORT=8003

# Webhook Configuration
N8N_WEBHOOK_URL=https://n8n-instance.com/webhook/xxx
N8N_API_KEY=secret-api-key

# Security Settings
ALLOWED_ORIGINS=https://sai.altermundi.net
RATE_LIMIT_WINDOW=15    # minutes
RATE_LIMIT_MAX=10       # requests per window

# Optional Features
ENABLE_LOGGING=true
LOG_LEVEL=info
WEBHOOK_TIMEOUT=10000   # milliseconds
RETRY_ATTEMPTS=3
```

### 4. API Endpoints

#### `/api/submit-form` (POST)
**Purpose:** Process form submissions from the website

**Request Flow:**
1. Receive form data from client
2. Validate required fields
3. Add metadata (timestamp, IP, user agent)
4. Check rate limits
5. Forward to n8n webhook
6. Handle response/errors
7. Return status to client

**Request Example:**
```json
{
  "localidad": "Villa Carlos Paz",
  "departamento": "Punilla",
  "provincia": "Córdoba",
  "nombre": "Juan",
  "apellido": "Pérez",
  "telefono": "+54 9 351 123-4567",
  "email": "juan@example.com",
  "comentarios-adicionales": "Urgente instalación"
}
```

**Response Example:**
```json
{
  "success": true,
  "message": "Form submitted successfully",
  "submissionId": "sub_1234567890"
}
```

#### `/api/health` (GET)
**Purpose:** Health check for monitoring

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-08-10T12:00:00Z",
  "uptime": 86400,
  "version": "1.2.0"
}
```

#### `/api/test-webhook` (POST)
**Purpose:** Test webhook connectivity (development only)

### 5. Error Handling

**Retry Logic:**
```javascript
// Exponential backoff for webhook failures
attempt 1: immediate
attempt 2: wait 1 second
attempt 3: wait 2 seconds
```

**Error Categories:**
- **400**: Validation errors (missing fields, invalid format)
- **429**: Rate limit exceeded
- **500**: Server errors (webhook failure, internal error)
- **503**: Service unavailable (n8n down, timeout)

### 6. Security Features

#### Rate Limiting
- Per-IP tracking
- Sliding window algorithm
- Configurable limits via environment variables
- Bypass for localhost (testing)

#### Input Validation
- Required field checking
- Email format validation
- Phone number sanitization
- XSS protection via HTML escaping
- SQL injection prevention (parameterized queries)

#### CORS Configuration
```javascript
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true,
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
}
```

### 7. Logging System

**Log Locations:**
- **Standard Output:** `/var/log/sai-proxy.log`
- **Error Output:** `/var/log/sai-proxy.error.log`
- **Systemd Journal:** `journalctl -u sai-proxy`

**Log Format:**
```
[2025-08-10T12:00:00.000Z] INFO: Form submission from Villa Carlos Paz, Córdoba
[2025-08-10T12:00:01.000Z] SUCCESS: Webhook response received (200)
[2025-08-10T12:00:01.100Z] INFO: Form submission successful
```

### 8. Performance Optimizations

#### Connection Pooling
- Keep-alive connections to n8n
- Connection reuse for multiple requests
- Automatic reconnection on failure

#### Caching Strategy
- Static configuration cached in memory
- Webhook URL cached for session
- No caching of form data (privacy)

#### Resource Limits
```javascript
// Memory management
const maxRequestSize = '10mb'
const maxConcurrentRequests = 100
const requestTimeout = 30000 // 30 seconds
```

### 9. Monitoring & Maintenance

#### Health Checks
```bash
# Quick health check
curl http://localhost:8003/api/health

# Full system check
systemctl status sai-proxy
```

#### Performance Metrics
```bash
# View real-time logs
journalctl -u sai-proxy -f

# Check memory usage
systemctl status sai-proxy | grep Memory

# View connection count
ss -plant | grep :8003
```

#### Common Maintenance Tasks

**Update webhook URL:**
```bash
cd /var/www/sai
nano .env  # Edit N8N_WEBHOOK_URL
systemctl restart sai-proxy
```

**Update from repository:**
```bash
cd /var/www/sai
git pull origin main
npm install --production
systemctl restart sai-proxy
```

**View submission logs:**
```bash
journalctl -u sai-proxy | grep "Form submission"
```

**Debug mode:**
```bash
# Temporarily run in debug mode
systemctl stop sai-proxy
cd /var/www/sai
NODE_ENV=development node proxy-server.js
```

### 10. Deployment Architecture After Migration

```
/var/www/sai/                    # Git repository root
├── proxy-server.js              # Main proxy server
├── package.json                 # Dependencies
├── .env                        # Environment config (git-ignored)
├── config/
│   └── webhook.json            # Webhook configuration
├── static/                     # Website files
│   ├── index.html              # Spanish version
│   ├── index-en.html           # English version
│   └── images/                 # Assets
├── scripts/                    # Utility scripts
│   ├── update.sh              # Quick update script
│   ├── test-webhook.py        # Testing utility
│   └── validate-deployment.sh # Validation script
└── .git/                      # Git repository

/etc/nginx/sites-available/
└── sai.altermundi.net         # Nginx configuration

/etc/systemd/system/
└── sai-proxy.service          # Systemd service
```

### 11. Scaling Considerations

#### Current Capacity
- Handles ~100 concurrent connections
- Processes ~10 requests/second sustained
- Memory usage: ~50-100MB
- CPU usage: <5% on single core

#### Future Scaling Options

**Horizontal Scaling with PM2:**
```javascript
// ecosystem.config.js for PM2 cluster mode
module.exports = {
  apps: [{
    name: 'sai-proxy',
    script: 'proxy-server.js',
    instances: 'max',  // Use all CPU cores
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 8003
    }
  }]
}
```

**Load Balancing:**
```nginx
# Nginx upstream for multiple instances
upstream sai_backend {
    least_conn;
    server 127.0.0.1:8003;
    server 127.0.0.1:8004;
    server 127.0.0.1:8005;
}
```

### 12. Disaster Recovery

#### Backup Strategy
- Automated daily backups via cron
- Configuration files backed up separately
- Git repository provides code recovery
- Database/webhook data in n8n (separate backup)

#### Recovery Procedure
1. Restore from backup: `tar -xzf /var/backups/sai-web/backup.tar.gz -C /`
2. Pull latest code: `cd /var/www/sai && git pull`
3. Restore configuration: Copy `.env` from secure backup
4. Restart services: `systemctl restart sai-proxy nginx`
5. Validate: Run test suite

### 13. Security Hardening

#### Process Isolation
- Runs as non-root user (www-data)
- Restricted file system access
- No shell access for service user

#### Network Security
- Binds to localhost only (127.0.0.1:8003)
- All external traffic through nginx reverse proxy
- SSL/TLS termination at nginx level

#### Input Sanitization
```javascript
// All user inputs sanitized
const sanitize = (input) => {
  return input
    .replace(/[<>]/g, '')  // Remove HTML tags
    .trim()                // Remove whitespace
    .slice(0, 1000)        // Limit length
}
```

## Troubleshooting Guide

### Common Issues

**1. Service won't start:**
```bash
# Check for port conflicts
lsof -i :8003
# Check logs
journalctl -u sai-proxy -n 50
```

**2. Webhook failures:**
```bash
# Test webhook directly
curl -X POST $N8N_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $N8N_API_KEY" \
  -d '{"test": true}'
```

**3. High memory usage:**
```bash
# Restart service to clear memory
systemctl restart sai-proxy
# Check for memory leaks
node --inspect /var/www/sai/proxy-server.js
```

**4. Slow response times:**
```bash
# Check nginx logs
tail -f /var/log/nginx/error.log
# Monitor proxy performance
time curl http://localhost:8003/api/health
```

This architecture provides a robust, scalable, and maintainable solution for the SAI form submission system.