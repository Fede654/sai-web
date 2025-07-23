#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { updateHtmlFile } = require('./build-config');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

const CONFIG_FILE = path.join(__dirname, '..', 'config', 'webhook.json');
const HTML_FILES = ['index.html', 'index-en.html'];

console.log('🔧 SAI Website Webhook Configuration Tool');
console.log('==========================================');
console.log('📋 Single Source of Truth Configuration');
console.log('');

function validateUrl(url) {
    try {
        new URL(url);
        return url.startsWith('http://') || url.startsWith('https://');
    } catch {
        return false;
    }
}

function updateConfig(webhookUrl) {
    try {
        const config = {
            webhook: {
                url: webhookUrl,
                timeout: 10000,
                retries: 3
            },
            meta: {
                lastUpdated: new Date().toISOString(),
                version: "1.0.0"
            }
        };
        
        fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2), 'utf8');
        console.log('✅ Updated config/webhook.json');
        return true;
    } catch (error) {
        console.error('❌ Error updating config:', error.message);
        return false;
    }
}

function updateHtmlFiles(webhookUrl) {
    let successCount = 0;
    const staticDir = path.join(__dirname, '..', 'static');
    
    HTML_FILES.forEach(filename => {
        const filePath = path.join(staticDir, filename);
        if (fs.existsSync(filePath)) {
            if (updateHtmlFile(filePath, webhookUrl)) {
                successCount++;
            }
        } else {
            console.log(`❌ File not found: ${filename}`);
        }
    });
    
    return successCount;
}

rl.question('Enter your n8n webhook URL: ', (webhookUrl) => {
    if (!webhookUrl) {
        console.log('❌ No URL provided. Exiting...');
        rl.close();
        return;
    }
    
    if (!validateUrl(webhookUrl)) {
        console.log('❌ Invalid URL format. Please provide a valid HTTP/HTTPS URL.');
        rl.close();
        return;
    }
    
    console.log('');
    console.log(`🔗 Configuring webhook URL: ${webhookUrl}`);
    console.log('');
    
    // Update config file (single source of truth)
    if (!updateConfig(webhookUrl)) {
        rl.close();
        return;
    }
    
    // Update HTML files
    const successCount = updateHtmlFiles(webhookUrl);
    
    console.log('');
    
    if (successCount > 0) {
        console.log('🎉 Webhook configuration complete!');
        console.log(`📊 Updated ${successCount} HTML files + config file`);
        console.log('');
        console.log('📋 Configuration stored in:');
        console.log('   - config/webhook.json (single source of truth)');
        console.log('   - static/index.html');
        console.log('   - static/index-en.html');
        console.log('');
        console.log('Next steps:');
        console.log('1. Test your n8n webhook endpoint');
        console.log('2. Start the development server (F5)');
        console.log('3. Open http://localhost:8080 and test form submission');
        console.log('');
        console.log('💡 Future updates:');
        console.log('   - Edit config/webhook.json');
        console.log('   - Run: npm run build-config');
    } else {
        console.log('❌ No HTML files were updated. Check if files exist.');
    }
    
    rl.close();
});

rl.on('close', () => {
    process.exit(0);
});