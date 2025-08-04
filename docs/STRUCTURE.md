# SAI Project Structure

## Directory Organization

```
sai-web/
├── README.md                    # Main project documentation
├── CLAUDE.md                    # Development instructions for Claude
├── DEPLOYMENT.md                # General deployment guide
├── LICENSE                      # Project license
├── SECURITY.md                  # Security documentation
├── package.json                 # Node.js dependencies and scripts
├── package-lock.json            # Dependency lock file
├── proxy-server.js              # Production proxy server
├── configure-webhook.sh         # Webhook configuration script
│
├── static/                      # Website files (served directly)
│   ├── index.html              # Spanish website
│   ├── index-en.html           # English website  
│   ├── favicon.ico             # Website icon
│   └── images/                 # Website assets
│       └── wildfire-camera-2.jpeg
│
├── config/                      # Configuration files
│   ├── webhook.json            # Webhook settings (non-sensitive)
│   └── webhook.json.example    # Configuration template
│
├── scripts/                     # Utility scripts
│   ├── build-config.js         # Configuration build script
│   ├── configure-webhook.js    # Interactive webhook setup
│   ├── setup-security.js       # Security configuration
│   └── test-webhook.py         # Python webhook testing
│
├── deployment/                  # Production deployment files
│   ├── deploy-proxy.sh         # Server deployment script
│   └── sai-proxy.service       # SystemD service file
│
└── docs/                       # Project documentation
    ├── STRUCTURE.md            # This file
    ├── DEPLOYMENT_CHECKLIST.md # Deployment checklist
    ├── DEPLOY_HISTORY.md       # Deployment history
    └── PRODUCTION.md           # Production documentation
```

## Key Files

### Website
- **`static/index.html`** - Main Spanish website with celeste Argentine theme
- **`static/index-en.html`** - English version (needs sync with Spanish changes)

### Proxy Server
- **`proxy-server.js`** - Production-ready form submission proxy
- **`.env`** - Environment variables (not in repo, create from .env.example)

### Configuration
- **`config/webhook.json`** - Non-sensitive webhook configuration
- **`.env.example`** - Template for environment variables

### Deployment
- **`deployment/deploy-proxy.sh`** - Automated deployment script
- **`deployment/sai-proxy.service`** - SystemD service definition

## Development vs Production

### Development
- Use `npm run dev` for development mode with verbose logging
- Debug endpoints available in development mode
- Test scripts available for form testing

### Production  
- Use `npm start` for production mode
- Minimal logging for privacy
- Debug endpoints disabled
- Phone number cleaning active

## Git Branches

- **`main`** - Original website theme
- **`redesign-celeste-argentino`** - Current branch with Argentine blue theme