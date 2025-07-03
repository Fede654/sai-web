# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **SAI (Sistema de Alerta de Incendios / Fire Alert System)** website - a bilingual static website showcasing an early warning fire detection system developed by AlterMundi in Córdoba, Argentina. The project presents information about an AI-powered wildfire detection system that uses camera nodes to identify smoke and fire, sending automated alerts via Telegram.

## Development Commands

### Local Development Server
```bash
# Using Python HTTP server (recommended)
cd static && python3 -m http.server 8080

# Using npx serve (alternative)
npx serve static -p 8080

# Access the site
curl -s http://localhost:8080
```

### File Structure Validation
```bash
# Check for missing files or broken links
find static/ -name "*.html" -exec grep -l "href=\|src=" {} \;
```

## Site Architecture

### Language Support
- **Bilingual Implementation**: Complete Spanish/English versions
- **File Naming Convention**: 
  - Spanish (default): `index.html`, `video.html`
  - English: `index-en.html`, `video-en.html`
- **Language Switcher**: Fixed position navigation in top-right corner
- **URL Structure**: Language variants share same directory structure

### Page Structure
1. **Landing Pages** (`index.html`, `index-en.html`)
   - Hero section with SAI branding
   - Modal-based "Learn More" functionality
   - Navigation to video impact page
   - Wildfire camera background image

2. **Video Pages** (`video.html`, `video-en.html`)
   - Embedded YouTube video showcasing system impact
   - Responsive 16:9 video wrapper
   - Back navigation to landing page

### CSS Architecture
- **Embedded Styles**: All CSS is inline within HTML files
- **Responsive Design**: Mobile-first approach with `@media` queries
- **Animation System**: CSS keyframes for fade-in effects (`fadeInDown`, `fadeInUp`, `zoomIn`)
- **Overlay Pattern**: Gradient overlays over background images for text readability
- **Color Scheme**: 
  - Primary: `#ff5722` (fire orange)
  - Background: Dark gradients with wildfire imagery
  - Text: White with transparency variations

### JavaScript Functionality
- **Modal Management**: Opening/closing learn-more modal
- **Event Handling**: Click and outside-click event listeners
- **Navigation**: Direct window.location for video pages

## Content Management

### Key Information
- **Organization**: AlterMundi (Asociación Civil)
- **Location**: Córdoba, Argentina (prototype in Molinari)
- **Technology**: AI-powered image analysis, 360° camera nodes, Telegram alerts
- **Licensing**: CC BY-SA 4.0 2025 AlterMundi
- **Contact**: sai@altermundi.net, WhatsApp integration

### Content Files
- `SAI-updated-info.md`: Comprehensive project documentation in Spanish
- `README.md`: Basic project identification (minimal content)

## Development Guidelines

### File Management
- Static assets in `/static/` directory
- No build process required - direct HTML/CSS/JS
- Maintain file naming consistency between language versions
- Preserve embedded styling approach for simplicity

### Content Updates
- Update both language versions simultaneously
- Maintain consistent messaging between Spanish and English
- Preserve AlterMundi branding and contact information
- Keep video embeds and external links functional

### Testing Workflow
```bash
# Start local server
cd static && python3 -m http.server 8080

# Test all pages manually
# - Landing page functionality (modal, navigation)
# - Language switching
# - Video page embedding
# - Mobile responsiveness
# - Cross-browser compatibility
```

## External Dependencies

### Media Assets
- Background image: `/images/wildfire-camera-2.jpeg` (referenced but not in repo)
- YouTube embed: Video ID `N5ROcdZJ3EI` 
- External documentation: HackMD hosted images in `SAI-updated-info.md`

### Third-party Services
- YouTube: Video hosting and embedding
- External image hosting: HackMD uploads for documentation

## Deployment Notes

- **Static Site**: No server-side processing required
- **Web Server**: Any HTTP server capable of serving static files
- **Missing Assets**: Background image referenced but not included in repository
- **Performance**: Minimal external dependencies, fast loading