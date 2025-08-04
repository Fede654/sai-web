const express = require('express');
const path = require('path');
const fs = require('fs');
const app = express();

// Parse JSON bodies
app.use(express.json());

// Serve static files from the static directory
app.use(express.static(path.join(__dirname, 'static')));

// Load environment variables first (production setup)
require('dotenv').config();

// Load webhook configuration (non-sensitive settings)
let webhookConfig = null;
try {
    const configPath = path.join(__dirname, 'config', 'webhook.json');
    const configData = fs.readFileSync(configPath, 'utf8');
    webhookConfig = JSON.parse(configData);
    console.log('✅ Webhook configuration loaded successfully');
} catch (error) {
    console.warn('⚠️  Failed to load webhook configuration:', error.message);
    console.warn('   Using environment variables and defaults');
}

// Configuration priority: ENV variables > config file > defaults
const WEBHOOK_URL = process.env.N8N_WEBHOOK_URL || (webhookConfig?.webhook?.url || '');
const API_KEY = process.env.N8N_API_KEY || ''; // Sensitive - should be in .env only
const PORT = parseInt(process.env.PORT) || 8080;
const TIMEOUT = parseInt(process.env.WEBHOOK_TIMEOUT) || (webhookConfig?.webhook?.timeout || 10000);
const MAX_RETRIES = parseInt(process.env.WEBHOOK_RETRIES) || (webhookConfig?.webhook?.retries || 3);

// Validate required configuration
if (!WEBHOOK_URL) {
    console.error('❌ WEBHOOK_URL not configured in environment variables!');
    console.error('   Set N8N_WEBHOOK_URL in .env file');
    process.exit(1);
}

if (!API_KEY) {
    console.error('❌ API_KEY not configured in environment variables!');
    console.error('   Set N8N_API_KEY in .env file');
    process.exit(1);
}

// Helper function to make webhook request with retries
async function sendToWebhook(data, retryCount = 0) {
    const headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'SAI-Proxy/1.0'
    };
    
    // Add API key authentication if configured
    if (API_KEY) {
        headers['Authorization'] = `Bearer ${API_KEY}`;
    }
    
    const response = await fetch(WEBHOOK_URL, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(data),
        timeout: TIMEOUT
    });
    
    return response;
}

// Proxy endpoint for form submissions
app.post('/api/submit-form', async (req, res) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] 📥 Form submission from ${req.body.localidad || 'unknown'}, ${req.body.provincia || 'unknown'}`);
    
    if (!WEBHOOK_URL) {
        console.error('❌ WEBHOOK_URL not configured');
        return res.status(500).json({ 
            success: false, 
            error: 'Server not properly configured' 
        });
    }
    
    if (!API_KEY) {
        console.warn('⚠️  API_KEY not configured - webhook may require authentication');
    }

    // Clean phone number - remove +54 and spaces
    const cleanedBody = { ...req.body };
    if (cleanedBody.telefono) {
        cleanedBody.telefono = cleanedBody.telefono
            .replace(/^\+54\s*/, '')  // Remove +54 and optional space at start
            .replace(/\s+/g, '');     // Remove all remaining spaces
    }

    // Add server metadata
    const enhancedData = {
        ...cleanedBody,
        meta: {
            timestamp: timestamp,
            serverVersion: '1.2.0',
            source: 'sai-proxy',
            ip: req.ip || req.connection.remoteAddress,
            userAgent: req.get('User-Agent')
        }
    };

    let lastError = null;
    
    // Retry logic
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
        try {
            const response = await sendToWebhook(enhancedData, attempt);
            const responseData = await response.text();
            
            if (process.env.NODE_ENV !== 'production') {
                console.log(`[${timestamp}] 📥 Webhook response: ${response.status} ${response.statusText}`);
            }
            
            if (response.ok) {
                console.log(`[${timestamp}] ✅ Form submission successful`);
                return res.json({ 
                    success: true,
                    message: 'Form submitted successfully' 
                });
            } else if (response.status >= 400 && response.status < 500) {
                // Client errors shouldn't be retried
                console.error(`[${timestamp}] ❌ Client error ${response.status}, not retrying`);
                return res.status(response.status).json({ 
                    success: false, 
                    error: 'Invalid request data or authentication failed' 
                });
            } else {
                // Server errors can be retried
                lastError = new Error(`Server error: ${response.status} ${response.statusText}`);
                console.warn(`[${timestamp}] ⚠️  Server error ${response.status}, will retry...`);
            }
            
        } catch (error) {
            lastError = error;
            console.warn(`[${timestamp}] ⚠️  Request failed (attempt ${attempt + 1}):`, error.message);
        }
        
        // Wait before retry (exponential backoff)
        if (attempt < MAX_RETRIES) {
            const delay = Math.min(1000 * Math.pow(2, attempt), 5000);
            console.log(`[${timestamp}] ⏳ Waiting ${delay}ms before retry...`);
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }
    
    // All retries failed
    console.error(`[${timestamp}] ❌ All retry attempts failed:`, lastError?.message);
    res.status(500).json({ 
        success: false, 
        error: 'Failed to process submission after retries' 
    });
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'ok',
        config: {
            webhook_url_configured: !!WEBHOOK_URL,
            api_key_configured: !!API_KEY,
            config_file_loaded: !!webhookConfig,
            timeout: TIMEOUT,
            max_retries: MAX_RETRIES,
            port: PORT
        },
        timestamp: new Date().toISOString(),
        version: '1.2.0'
    });
});

// Production ready - debug endpoints removed

app.listen(PORT, '127.0.0.1', () => {
    console.log(`🚀 SAI Proxy Server v1.2.0 running on http://127.0.0.1:${PORT}`);
    console.log(`📡 Webhook URL: ${WEBHOOK_URL ? '✅ Configured' : '❌ NOT CONFIGURED'}`);
    console.log(`🔐 API Key: ${API_KEY ? '✅ Configured' : '❌ NOT CONFIGURED'}`);
    console.log(`📁 Config file: ${webhookConfig ? '✅ Loaded' : '❌ Failed to load'}`);
    console.log(`⚙️  Timeout: ${TIMEOUT}ms, Retries: ${MAX_RETRIES}`);
    console.log(`📊 Health check: http://127.0.0.1:${PORT}/api/health`);
});
