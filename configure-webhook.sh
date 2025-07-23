#!/bin/bash

# Script to configure n8n webhook URL for SAI website forms
# Usage: ./configure-webhook.sh "https://your-n8n-instance.com/webhook/sai-form"

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <webhook-url>"
    echo "Example: $0 'https://your-n8n-instance.com/webhook/sai-form'"
    exit 1
fi

WEBHOOK_URL="$1"
PLACEHOLDER="YOUR_N8N_WEBHOOK_URL_HERE"

echo "Configuring webhook URL in SAI website forms..."
echo "URL: $WEBHOOK_URL"

# Update Spanish version
if [ -f "static/index.html" ]; then
    sed -i "s|$PLACEHOLDER|$WEBHOOK_URL|g" static/index.html
    echo "✅ Updated static/index.html"
else
    echo "❌ File static/index.html not found"
fi

# Update English version
if [ -f "static/index-en.html" ]; then
    sed -i "s|$PLACEHOLDER|$WEBHOOK_URL|g" static/index-en.html
    echo "✅ Updated static/index-en.html"
else
    echo "❌ File static/index-en.html not found"
fi

echo ""
echo "🎉 Webhook configuration complete!"
echo ""
echo "Next steps:"
echo "1. Test your n8n webhook endpoint"
echo "2. Start your web server: cd static && python3 -m http.server 8080"
echo "3. Test form submission on both Spanish and English versions"
echo ""
echo "Form data will be sent as JSON with these fields:"
echo "- All form field values"
echo "- timestamp: ISO timestamp when form was submitted"
echo "- language: 'es' or 'en'"
echo "- source: 'sai-website'"
echo "- userAgent: Browser user agent string"