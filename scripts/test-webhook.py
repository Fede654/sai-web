#!/usr/bin/env python3

import json
import requests
import time
from datetime import datetime

def test_webhook():
    """Test the configured webhook URL with sample form data"""
    
    print("🧪 SAI Website Webhook Testing Tool")
    print("=" * 40)
    print()
    
    # Read webhook URL from HTML files
    webhook_url = None
    try:
        with open('../static/index.html', 'r', encoding='utf-8') as f:
            content = f.read()
            start = content.find('data-webhook-url="') + 18
            end = content.find('"', start)
            webhook_url = content[start:end]
    except Exception as e:
        print(f"❌ Error reading webhook URL: {e}")
        return
    
    if not webhook_url or webhook_url == 'YOUR_N8N_WEBHOOK_URL_HERE':
        print("❌ Webhook URL not configured!")
        print("   Run the webhook configuration script first.")
        return
    
    print(f"🔗 Testing webhook: {webhook_url}")
    print()
    
    # Sample test data (Spanish form)
    test_data = {
        "localidad": "Córdoba",
        "departamento": "Capital",
        "provincia": "Córdoba",
        "nombre": "Test",
        "apellido": "User",
        "telefono": "+54 351 123-4567",
        "email": "test@example.com",
        "como-se-entero": "web",
        "ubicacion-nodo": "Torre de agua municipal",
        "acceso-internet": "on",
        "luz-electrica": "on",
        "red-municipios": "on",
        "timestamp": datetime.now().isoformat(),
        "language": "es",
        "source": "sai-website-test",
        "userAgent": "SAI-Webhook-Tester/1.0"
    }
    
    print("📤 Sending test data...")
    print(json.dumps(test_data, indent=2, ensure_ascii=False))
    print()
    
    try:
        # Send the request
        response = requests.post(
            webhook_url,
            json=test_data,
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'SAI-Website-Test/1.0'
            },
            timeout=10
        )
        
        print(f"📥 Response Status: {response.status_code}")
        print(f"📏 Response Size: {len(response.content)} bytes")
        
        if response.headers.get('content-type', '').startswith('application/json'):
            try:
                response_json = response.json()
                print("📋 Response Body:")
                print(json.dumps(response_json, indent=2))
            except:
                print("📋 Response Body (text):")
                print(response.text[:500])
        else:
            print("📋 Response Body:")
            print(response.text[:500])
        
        if response.status_code == 200:
            print("\n✅ Webhook test successful!")
            print("   Your n8n workflow should have received the test data.")
        elif response.status_code == 404:
            print("\n❌ Webhook endpoint not found (404)")
            print("   Check if your n8n workflow is active and the URL is correct.")
        elif response.status_code >= 500:
            print(f"\n❌ Server error ({response.status_code})")
            print("   There might be an issue with your n8n workflow.")
        else:
            print(f"\n⚠️  Unexpected response ({response.status_code})")
            print("   Check your n8n workflow configuration.")
            
    except requests.exceptions.Timeout:
        print("❌ Request timed out")
        print("   Check if your n8n instance is accessible.")
    except requests.exceptions.ConnectionError:
        print("❌ Connection error")
        print("   Check if your n8n instance is running and accessible.")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    print()
    print("💡 Tips:")
    print("   - Check your n8n workflow execution logs")
    print("   - Verify CORS settings if testing from browser")
    print("   - Ensure your n8n instance is accessible from this network")

if __name__ == "__main__":
    test_webhook()