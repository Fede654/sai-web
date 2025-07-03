# SAI - Sistema de Alerta de Incendios / Fire Alert System

**Early wildfire detection system using AI-powered computer vision and real-time alerts**

🔥 **Real-world validated** - Successfully detected and alerted during June 2024 fire in Molinari, Córdoba  
🤖 **AI-powered** - Double neural network confirmation system  
📱 **Instant alerts** - Telegram bot with interactive verification  
🌍 **Bilingual** - Complete Spanish/English website

## 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd sai-web

# Start local development server
cd static
python3 -m http.server 8080

# Open in browser
open http://localhost:8080
```

## 📋 Project Overview

SAI (Sistema de Alerta de Incendios) is an early warning fire detection system developed by AlterMundi in collaboration with volunteer fire departments in Córdoba, Argentina. The system addresses critical gaps in the Provincial Fire Management Plan by providing real-time fire detection in initial stages.

### 🔢 The Problem (2024 Data - Copernicus Program)
- **11,560** fire outbreaks registered in Argentina
- **3.9M** hectares affected by fires
- **103,309** hectares affected in Córdoba province
- Current solutions: expensive human towers + satellites that miss initial stages

### 🛠️ Technical Solution
1. **360° Camera Nodes** - 4 cameras per node, photos every 5 minutes
2. **AI Analysis** - Computer vision model detects smoke/fire indicators  
3. **Double Confirmation** - Second neural network validates alerts
4. **Interactive Alerts** - Telegram bot sends messages, recipients can confirm/deny

## 🏗️ Project Structure

```
sai-web/
├── static/                 # Static website files
│   ├── index.html          # Spanish homepage
│   ├── index-en.html       # English homepage  
│   ├── video.html          # Spanish video page
│   └── video-en.html       # English video page
├── SAI-updated-info.md     # Detailed project documentation
├── CLAUDE.md              # Development workflow & AI assistant context
└── README.md              # This file
```

## 🌐 Website Features

### Design & UX
- **Responsive Design** - Mobile-first with professional glass-morphism styling
- **Smooth Animations** - Scroll-triggered animations and micro-interactions
- **Modern UI** - Inter font, gradient backgrounds, professional color scheme
- **Accessibility** - Semantic HTML, proper contrast, keyboard navigation

### Content Sections
- **Problem Statement** - Context about fire management gaps
- **Technical Process** - 4-step explanation of AI detection system
- **Real Validation** - Molinari prototype success story
- **Subscription Form** - Complete form with all required fields for node installation
- **Emergency Contacts** - Quick access to fire emergency numbers
- **Partner Network** - INTI, fire departments, AlterMundi

### Technical Implementation
- **Pure HTML/CSS/JS** - No build process required
- **Embedded Styles** - All CSS inline for easy deployment
- **Form Validation** - Client-side validation with visual feedback
- **Bilingual Support** - Complete Spanish/English versions

## 🏃‍♂️ Development Workflow

### Local Development
```bash
# Start development server
cd static && python3 -m http.server 8080

# Alternative with npx
npx serve static -p 8080
```

### Making Changes
1. Edit HTML files directly in `static/` directory
2. Test locally on http://localhost:8080
3. Maintain parity between Spanish and English versions
4. Follow existing design patterns and CSS variables

### CSS Architecture
```css
:root {
  --primary-color: #ff5722;    /* Fire orange */
  --primary-dark: #e64a19;     /* Darker orange */
  --accent-color: #ffc107;     /* Amber */
  --text-light: #ffffff;       /* White text */
  --section-bg: rgba(26, 26, 26, 0.95); /* Dark sections */
}
```

## 📊 Real-World Validation

### Molinari Prototype (June 2024)
- **Location**: Molinari, Córdoba Province, Argentina
- **Event**: Real wildfire incident in mid-June 2024
- **Result**: System issued first positive alarm, validating functionality
- **Impact**: Proof of concept for early detection capabilities

### Partner Network
- 🏛️ **INTI** - Instituto Nacional de Tecnología Industrial
- 🚒 **Alta Gracia Volunteer Firefighters** - Node validation collaboration  
- 🚒 **Villa Ciudad de América Firefighters** - Testing support
- 🏢 **AlterMundi Civil Association** - Technical expertise and funding

## 📞 Contact & Emergency Information

### Project Contact
- **Email**: sai@altermundi.net
- **WhatsApp**: +54 3547 469632
- **Website**: https://sai.altermundi.net

### Emergency Numbers (Argentina)
- 🔥 **0800-888-FUEGO** - Fire emergency
- 👮 **911** - Police
- 🚒 **100** - Firefighters

## 🔧 Subscription Process

Users can subscribe through the website form providing:
- Location details (city, department, province)
- Contact information (name, phone, email)
- Node installation details (location, internet/power access)
- Interest in municipal alert network participation

## 📄 License

CC BY-SA 4.0 2025 AlterMundi

## 🚀 Deployment

This is a static website that can be deployed to any web server:

```bash
# Copy static files to web server
rsync -av static/ user@server:/var/www/sai/

# Or deploy to GitHub Pages, Netlify, Vercel, etc.
```

## 📚 Additional Documentation

- **[SAI-updated-info.md](./SAI-updated-info.md)** - Detailed project information in Spanish
- **[CLAUDE.md](./CLAUDE.md)** - Development context and AI assistant instructions

---

**🤖 This project documentation was enhanced with [Claude Code](https://claude.ai/code)**