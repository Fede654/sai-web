#!/bin/bash

# SAI Proxy Server Deployment Script
# This script sets up the proxy server in production

set -e  # Exit on any error

echo "🚀 SAI Proxy Server Deployment"
echo "==============================="
echo

# Configuration
INSTALL_DIR="/opt/sai-proxy"
SERVICE_USER="www-data"
SERVICE_NAME="sai-proxy"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

echo "📁 Setting up installation directory..."
mkdir -p "$INSTALL_DIR"

echo "📋 Copying application files..."
cp proxy-server.js "$INSTALL_DIR/"
cp -r config/ "$INSTALL_DIR/"
cp package.json "$INSTALL_DIR/" 2>/dev/null || echo "⚠️  No package.json found, skipping..."

echo "🔐 Setting up environment file..."
if [ -f ".env" ]; then
    cp .env "$INSTALL_DIR/"
    echo "✅ Environment file copied"
else
    echo "⚠️  No .env file found. Creating from example..."
    if [ -f ".env.example" ]; then
        cp .env.example "$INSTALL_DIR/.env"
        echo "❗ IMPORTANT: Edit $INSTALL_DIR/.env with your actual configuration!"
    else
        echo "❌ No .env.example found. You'll need to create $INSTALL_DIR/.env manually"
    fi
fi

echo "🔒 Setting permissions..."
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod 600 "$INSTALL_DIR/.env" 2>/dev/null || true
chmod 755 "$INSTALL_DIR/proxy-server.js"

echo "📦 Installing Node.js dependencies..."
cd "$INSTALL_DIR"
if [ -f "package.json" ]; then
    npm install --production
else
    echo "Installing required packages manually..."
    npm install express dotenv
fi

echo "⚙️  Installing systemd service..."
if [ -f "../sai-proxy.service" ]; then
    cp ../sai-proxy.service /etc/systemd/system/
elif [ -f "sai-proxy.service" ]; then
    cp sai-proxy.service /etc/systemd/system/
else
    echo "❌ sai-proxy.service file not found!"
    exit 1
fi

echo "🔄 Enabling and starting service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "📊 Checking service status..."
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "✅ Service is running successfully!"
    systemctl status "$SERVICE_NAME" --no-pager -l
else
    echo "❌ Service failed to start. Check logs:"
    journalctl -u "$SERVICE_NAME" --no-pager -n 20
    exit 1
fi

echo
echo "🎉 Deployment completed successfully!"
echo
echo "📋 Service Information:"
echo "   - Service: $SERVICE_NAME"
echo "   - Location: $INSTALL_DIR"
echo "   - User: $SERVICE_USER"
echo
echo "🔧 Useful commands:"
echo "   - View logs: sudo journalctl -u $SERVICE_NAME -f"
echo "   - Restart: sudo systemctl restart $SERVICE_NAME"
echo "   - Status: sudo systemctl status $SERVICE_NAME"
echo "   - Health check: curl http://127.0.0.1:8003/api/health"
echo
echo "⚠️  Don't forget to:"
echo "   1. Verify .env configuration: sudo nano $INSTALL_DIR/.env"
echo "   2. Check health endpoint: curl http://127.0.0.1:8003/api/health"
echo "   3. Test form submission from website"