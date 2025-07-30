#!/usr/bin/env node

const express = require('express');
const path = require('path');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;

// Security middleware
app.use(helmet({
    contentSecurityPolicy: false // Allow inline styles/scripts for static site
}));

app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
    credentials: true
}));

// Rate limiting for form submissions
const formLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // 5 submissions per window per IP
    message: { error: 'Too many form submissions, please try again later' },
    standardHeaders: true,
    legacyHeaders: false,
});

// General rate limiting
const generalLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // 100 requests per window per IP
    standardHeaders: true,
    legacyHeaders: false,
});

app.use(generalLimiter);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve static files
app.use(express.static(path.join(__dirname, 'static'), {
    maxAge: '1d', // Cache static assets for 1 day
    etag: true
}));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        version: require('./package.json').version
    });
});

// Secure form submission endpoint
app.post('/api/submit-form', formLimiter, async (req, res) => {
    try {
        // Load webhook configuration from environment
        const WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;
        const API_KEY = process.env.N8N_API_KEY;

        if (!WEBHOOK_URL || !API_KEY) {
            console.error('Missing N8N_WEBHOOK_URL or N8N_API_KEY environment variables');
            return res.status(500).json({ 
                error: 'Server configuration error',
                message: 'Webhook not properly configured'
            });
        }

        // Validate request body
        if (!req.body || typeof req.body !== 'object') {
            return res.status(400).json({ 
                error: 'Invalid request body' 
            });
        }

        // Security checks
        const data = req.body;

        // Honeypot check
        if (data.website) {
            console.log('Honeypot triggered from IP:', req.ip);
            // Silent success for bots
            return res.json({ success: true });
        }

        // Required fields validation
        const requiredFields = ['city', 'department', 'province', 'first-name', 'last-name', 'phone', 'email'];
        const missingFields = requiredFields.filter(field => !data[field] || !data[field].toString().trim());
        
        if (missingFields.length > 0) {
            return res.status(400).json({ 
                error: 'Missing required fields',
                fields: missingFields
            });
        }

        // Email validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(data.email)) {
            return res.status(400).json({ 
                error: 'Invalid email format' 
            });
        }

        // Add server-side metadata
        const submissionData = {
            ...data,
            timestamp: new Date().toISOString(),
            serverTimestamp: new Date().toISOString(),
            ipAddress: req.ip,
            userAgent: req.get('User-Agent'),
            source: 'sai-website-proxy',
            version: require('./package.json').version
        };

        // Forward to n8n webhook with API key
        const fetch = (await import('node-fetch')).default;
        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': API_KEY,
                'User-Agent': `SAI-Website-Proxy/${require('./package.json').version}`
            },
            body: JSON.stringify(submissionData),
            timeout: 10000 // 10 second timeout
        });

        if (!response.ok) {
            console.error('N8N webhook error:', response.status, response.statusText);
            throw new Error(`Webhook returned ${response.status}`);
        }

        // Log successful submission (without sensitive data)
        console.log('Form submitted successfully:', {
            timestamp: submissionData.timestamp,
            city: data.city,
            province: data.province,
            ip: req.ip
        });

        res.json({ 
            success: true,
            message: 'Form submitted successfully',
            timestamp: submissionData.timestamp
        });

    } catch (error) {
        console.error('Form submission error:', error);
        
        // Don't expose internal errors to client
        res.status(500).json({ 
            error: 'Submission failed',
            message: 'Please try again later'
        });
    }
});

// Webhook test endpoint (for development)
if (process.env.NODE_ENV !== 'production') {
    app.post('/api/test-webhook', async (req, res) => {
        try {
            const testData = {
                city: 'Test City',
                department: 'Test Department',
                province: 'Test Province',
                'first-name': 'Test',
                'last-name': 'User',
                phone: '+54 351 123-4567',
                email: 'test@example.com',
                'how-heard': 'test',
                'node-location': 'Test location',
                timestamp: new Date().toISOString(),
                source: 'webhook-test'
            };

            const WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;
            const API_KEY = process.env.N8N_API_KEY;

            if (!WEBHOOK_URL || !API_KEY) {
                return res.status(500).json({ error: 'Webhook not configured' });
            }

            const fetch = (await import('node-fetch')).default;
            const response = await fetch(WEBHOOK_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-API-Key': API_KEY
                },
                body: JSON.stringify(testData),
                timeout: 10000
            });

            res.json({ 
                success: response.ok,
                status: response.status,
                message: response.ok ? 'Test successful' : 'Test failed'
            });

        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    });
}

// Catch-all handler for SPA-style routing
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'static', 'index.html'));
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Server error:', error);
    res.status(500).json({ 
        error: 'Internal server error',
        message: 'Something went wrong'
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log('🚀 SAI Website Server started');
    console.log(`📍 Server running on http://0.0.0.0:${PORT}`);
    console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`🔧 Webhook configured: ${process.env.N8N_WEBHOOK_URL ? 'Yes' : 'No'}`);
    console.log(`🔑 API Key configured: ${process.env.N8N_API_KEY ? 'Yes' : 'No'}`);
});