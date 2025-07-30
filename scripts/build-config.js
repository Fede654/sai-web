#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Build script that injects webhook configuration into HTML files
 * This creates a single source of truth for webhook URLs
 */

const CONFIG_FILE = path.join(__dirname, '..', 'config', 'webhook.json');
const STATIC_DIR = path.join(__dirname, '..', 'static');
const HTML_FILES = ['index.html', 'index-en.html'];

function loadConfig() {
    try {
        const configContent = fs.readFileSync(CONFIG_FILE, 'utf8');
        return JSON.parse(configContent);
    } catch (error) {
        console.error('❌ Error loading config:', error.message);
        process.exit(1);
    }
}

function updateHtmlFile(filePath, webhookUrl, config) {
    try {
        let content = fs.readFileSync(filePath, 'utf8');
        
        // Replace webhook URL in data-webhook-url attribute
        const regex = /data-webhook-url="[^"]*"/g;
        const newAttribute = `data-webhook-url="${webhookUrl}"`;
        
        if (content.match(regex)) {
            content = content.replace(regex, newAttribute);
            
            // Add security configuration as data attributes
            if (config.webhook.auth) {
                const authRegex = /data-auth-key="[^"]*"/g;
                const authAttribute = `data-auth-key="${config.webhook.auth.key}"`;
                if (content.match(authRegex)) {
                    content = content.replace(authRegex, authAttribute);
                } else {
                    // Add auth attribute to form tag
                    content = content.replace(
                        /(<form[^>]*data-webhook-url="[^"]*")/,
                        `$1 ${authAttribute}`
                    );
                }
            }
            
            // Add security flags
            if (config.security) {
                const securityAttr = `data-security='${JSON.stringify(config.security)}'`;
                content = content.replace(
                    /(<form[^>]*data-webhook-url="[^"]*"[^>]*)/,
                    `$1 ${securityAttr}`
                );
            }
            
            fs.writeFileSync(filePath, content, 'utf8');
            console.log(`✅ Updated ${path.basename(filePath)}`);
            return true;
        } else {
            console.log(`⚠️  No webhook URL found in ${path.basename(filePath)}`);
            return false;
        }
    } catch (error) {
        console.error(`❌ Error updating ${path.basename(filePath)}:`, error.message);
        return false;
    }
}

function main() {
    console.log('🔧 SAI Website Configuration Builder');
    console.log('====================================');
    console.log('');
    
    // Load configuration
    const config = loadConfig();
    const webhookUrl = config.webhook.url;
    
    if (!webhookUrl) {
        console.error('❌ No webhook URL found in config');
        process.exit(1);
    }
    
    console.log(`🔗 Using webhook URL: ${webhookUrl}`);
    console.log('');
    
    // Update HTML files
    let successCount = 0;
    
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
    
    if (successCount > 0) {
        console.log('🎉 Configuration build complete!');
        console.log(`📊 Updated ${successCount} files`);
        console.log('');
        console.log('Next steps:');
        console.log('1. Start the development server (F5)');
        console.log('2. Test form submissions');
    } else {
        console.log('❌ No files were updated');
    }
}

if (require.main === module) {
    main();
}

module.exports = { loadConfig, updateHtmlFile };