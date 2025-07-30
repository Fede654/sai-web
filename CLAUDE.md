# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SAI (Sistema de Alerta de Incendios) is a static website with n8n webhook integration for collecting fire alert system applications from municipalities. The project uses a configuration-driven approach where `config/webhook.json` serves as the single source of truth for webhook URLs.

## Architecture

**Static Website**: Pure HTML/CSS/JavaScript with no build process - directly served from `static/` directory
**Configuration Management**: Centralized webhook configuration in `config/webhook.json` that gets injected into HTML files
**Bilingual Support**: Spanish (`index.html`) and English (`index-en.html`) versions with identical functionality
**Form Submission**: AJAX form handling with webhook integration, including test mode support

### Key Components

- `config/webhook.json` - Single source of truth for webhook configuration
- `static/index.html` - Spanish version of the website
- `static/index-en.html` - English version of the website  
- `scripts/configure-webhook.js` - Interactive webhook configuration tool
- `scripts/build-config.js` - Builds configuration into HTML files
- `scripts/test-webhook.py` - Python webhook testing utility

## Common Development Commands

### Development Server
```bash
npm start
# or
F5  # Start server on http://0.0.0.0:8080
```

### Configuration Management
```bash
npm run configure     # Interactive webhook URL configuration
npm run build        # Inject webhook config into HTML files
```

### Testing
```bash
# Test webhook with sample data
cd scripts && python3 test-webhook.py

# Test with query parameter
http://0.0.0.0:8080/?test=true
```

## Configuration System

The project uses a sophisticated configuration system:

1. **Source of Truth**: `config/webhook.json` contains webhook URL and metadata
2. **HTML Injection**: Build scripts inject webhook URL into `data-webhook-url` attributes in forms
3. **Runtime Lookup**: JavaScript reads `data-webhook-url` attribute for form submissions

### Configuration Workflow
1. Run `npm run configure` to set webhook URL interactively
2. Script updates both `config/webhook.json` and HTML files
3. For manual updates: edit `config/webhook.json` then run `npm run build`

## Form Handling Architecture

Forms use AJAX submission with sophisticated error handling:
- Reads webhook URL from `data-webhook-url` attribute
- Includes timestamp, language, source, and user agent metadata
- Supports test mode via `?test=true` query parameter
- Implements retry logic and user feedback

## File Structure Notes

- `static/images/` contains project assets including system diagrams and test images
- `configure-webhook.sh` is a bash wrapper for the Node.js configuration script
- HTML files contain embedded CSS and JavaScript (no separate asset files)
- Both language versions maintain identical form structure and JavaScript functionality

## Development Notes

- No build system required - HTML files are served directly
- Configuration changes require running build scripts to update HTML
- Test mode can be enabled via URL parameter for development
- Webhook testing script reads configuration directly from HTML files
- All form data includes metadata fields for tracking and analytics