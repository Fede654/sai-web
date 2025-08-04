# SAI - Sistema de Alerta de Incendios

Static website with n8n webhook integration for collecting fire alert system applications from municipalities.

## Quick Start

**Development Server**: `F5` (starts on http://0.0.0.0:8080)  
**Test Mode**: http://0.0.0.0:8080/?test=true  
**Configuration**: `npm run configure`  
**Production Proxy**: `npm start` (runs on port 8003)

## Architecture

- **Static Website**: Pure HTML/CSS/JavaScript served from `static/`
- **Proxy Server**: Node.js server for secure webhook communication
- **Configuration**: Centralized in `config/webhook.json` + `.env`
- **Bilingual**: Spanish (`index.html`) and English (`index-en.html`)

## Documentation

- **[Project Structure](docs/STRUCTURE.md)** - Directory organization
- **[Production Guide](docs/PRODUCTION.md)** - Production deployment info
- **[Deployment History](docs/DEPLOY_HISTORY.md)** - Deployment log
- **[Security](SECURITY.md)** - Security documentation

## Current Theme

Branch `redesign-celeste-argentino` features Argentine blue/white color palette with professional styling and improved user experience.