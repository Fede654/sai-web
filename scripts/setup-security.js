#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { updateHtmlFile } = require('./build-config');

/**
 * Security Setup Script for SAI Website
 * Configures authentication and security measures for webhook protection
 */

const CONFIG_FILE = path.join(__dirname, '..', 'config', 'webhook.json');
const STATIC_DIR = path.join(__dirname, '..', 'static');
const HTML_FILES = ['index.html', 'index-en.html'];

function generateApiKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < 32; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

function setupSecurity() {
    console.log('🔒 SAI Website Security Setup');
    console.log('============================');
    console.log('');
    
    try {
        // Load existing config
        const configContent = fs.readFileSync(CONFIG_FILE, 'utf8');
        const config = JSON.parse(configContent);
        
        // Generate new API key if needed
        if (!config.webhook.auth || config.webhook.auth.key === 'YOUR_API_KEY_HERE') {
            const apiKey = generateApiKey();
            config.webhook.auth = {
                type: 'api-key',
                key: apiKey
            };
            console.log('🔑 Generated new API key:', apiKey);
        } else {
            console.log('🔑 Using existing API key:', config.webhook.auth.key);
        }
        
        // Enable security features
        config.security = {
            honeypot: true,
            rateLimit: true,
            timestampValidation: true
        };
        
        config.meta.lastUpdated = new Date().toISOString();
        
        // Save updated config
        fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2), 'utf8');
        console.log('✅ Updated config/webhook.json');
        
        // Update HTML files
        let successCount = 0;
        const webhookUrl = config.webhook.url;
        
        HTML_FILES.forEach(filename => {
            const filePath = path.join(STATIC_DIR, filename);
            if (fs.existsSync(filePath)) {
                if (updateHtmlFile(filePath, webhookUrl, config)) {
                    successCount++;
                }
            } else {
                console.log(`❌ File not found: ${filename}`);
            }
        });
        
        console.log('');
        console.log('🎉 Security setup complete!');
        console.log(`📊 Updated ${successCount} HTML files + config file`);
        console.log('');
        console.log('🛡️  Security Features Enabled:');
        console.log('   ✅ API Key Authentication');
        console.log('   ✅ Honeypot Bot Detection');
        console.log('   ✅ Timestamp Validation');
        console.log('   ✅ Rate Limiting Headers');
        console.log('');
        console.log('🔧 n8n Webhook Configuration:');
        console.log('   1. Add Authentication node in your workflow');
        console.log('   2. Check for X-API-Key header');
        console.log(`   3. Expected value: ${config.webhook.auth.key}`);
        console.log('   4. Add rate limiting in n8n or reverse proxy');
        console.log('');
        console.log('⚠️  IMPORTANT FOR GITHUB:');
        console.log('   • Your API key will be visible in the repository');
        console.log('   • Consider using environment variables in production');
        console.log('   • Monitor your n8n logs for suspicious activity');
        
    } catch (error) {
        console.error('❌ Error setting up security:', error.message);
        process.exit(1);
    }
}

if (require.main === module) {
    setupSecurity();
}

module.exports = { setupSecurity, generateApiKey };