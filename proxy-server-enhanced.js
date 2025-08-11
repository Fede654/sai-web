const express = require('express');
const path = require('path');
const fs = require('fs');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const app = express();

// Load environment variables first
require('dotenv').config();

// Security middleware - apply before other middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'", "'unsafe-inline'"],
            imgSrc: ["'self'", "data:", "https:"],
        },
    },
    hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
    }
}));

// CORS configuration
const corsOptions = {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['https://sai.altermundi.net'],
    credentials: true,
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Session-Token'],
    optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

// Request size limits
app.use(express.json({ 
    limit: '10mb',
    verify: (req, res, buf) => {
        req.rawBody = buf;
    }
}));

// Trust proxy for correct IP addresses (when behind nginx)
app.set('trust proxy', 1);

// Session storage (in-memory for simplicity, use Redis in production)
const sessions = new Map();
const ipAttempts = new Map();
const suspiciousIPs = new Set();

// Configuration
const WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;
const API_KEY = process.env.N8N_API_KEY;
const PORT = parseInt(process.env.PORT) || 8003;
const SESSION_DURATION = parseInt(process.env.SESSION_DURATION) || 3600000; // 1 hour
const MAX_LOGIN_ATTEMPTS = parseInt(process.env.MAX_LOGIN_ATTEMPTS) || 5;
const LOCKOUT_DURATION = parseInt(process.env.LOCKOUT_DURATION) || 900000; // 15 minutes

// Validate critical configuration
if (!WEBHOOK_URL || !API_KEY) {
    console.error('❌ Critical configuration missing: WEBHOOK_URL and API_KEY required');
    process.exit(1);
}

// Rate limiting middleware - Multiple layers
const strictRateLimit = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // 5 requests per 15 minutes per IP
    message: {
        success: false,
        error: 'Too many requests. Please try again later.',
        retryAfter: '15 minutes'
    },
    standardHeaders: true,
    legacyHeaders: false,
    skip: (req) => {
        // Skip rate limiting for localhost in development
        return process.env.NODE_ENV === 'development' && 
               (req.ip === '127.0.0.1' || req.ip === '::1');
    }
});

const moderateRateLimit = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 3, // 3 requests per minute
    message: {
        success: false,
        error: 'Rate limit exceeded. Please wait before submitting again.',
        retryAfter: '1 minute'
    },
    standardHeaders: true,
    legacyHeaders: false
});

// Honeypot middleware - detect bots
const honeypotMiddleware = (req, res, next) => {
    if (req.body.website) { // Honeypot field should be empty
        console.warn(`🍯 Honeypot triggered by IP: ${req.ip}`);
        suspiciousIPs.add(req.ip);
        return res.status(429).json({
            success: false,
            error: 'Request rejected'
        });
    }
    next();
};

// IP blocking middleware
const ipBlockMiddleware = (req, res, next) => {
    if (suspiciousIPs.has(req.ip)) {
        console.warn(`🚫 Blocked suspicious IP: ${req.ip}`);
        return res.status(403).json({
            success: false,
            error: 'Access denied'
        });
    }
    next();
};

// Session token generation
const generateSessionToken = () => {
    return crypto.randomBytes(32).toString('hex');
};

// Session validation middleware
const validateSession = (req, res, next) => {
    const sessionToken = req.headers['x-session-token'];
    
    if (!sessionToken) {
        return res.status(401).json({
            success: false,
            error: 'Session token required'
        });
    }
    
    const session = sessions.get(sessionToken);
    
    if (!session || Date.now() > session.expiresAt) {
        sessions.delete(sessionToken);
        return res.status(401).json({
            success: false,
            error: 'Invalid or expired session'
        });
    }
    
    // Extend session
    session.expiresAt = Date.now() + SESSION_DURATION;
    session.lastActivity = Date.now();
    
    req.session = session;
    next();
};

// Input sanitization
const sanitizeInput = (input) => {
    if (typeof input !== 'string') return input;
    
    return input
        .trim()
        .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '') // Remove script tags
        .replace(/[<>]/g, '') // Remove HTML brackets
        .slice(0, 1000); // Limit length
};

// Request validation
const validateFormData = (data) => {
    const required = ['localidad', 'departamento', 'provincia', 'nombre', 'apellido', 'telefono', 'email'];
    const missing = required.filter(field => !data[field] || data[field].trim() === '');
    
    if (missing.length > 0) {
        return { valid: false, message: `Missing required fields: ${missing.join(', ')}` };
    }
    
    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(data.email)) {
        return { valid: false, message: 'Invalid email format' };
    }
    
    // Phone validation (basic)
    const phoneRegex = /^[\d\s\-\+\(\)]+$/;
    if (!phoneRegex.test(data.telefono)) {
        return { valid: false, message: 'Invalid phone number format' };
    }
    
    return { valid: true };
};

// Enhanced webhook request with security headers
async function sendToWebhook(data, sessionInfo) {
    const headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'SAI-Proxy-Enhanced/2.0',
        'Authorization': `Bearer ${API_KEY}`,
        'X-Request-ID': uuidv4(),
        'X-Timestamp': new Date().toISOString(),
        'X-Source': 'sai-proxy-server'
    };
    
    const enhancedData = {
        ...data,
        meta: {
            requestId: headers['X-Request-ID'],
            timestamp: headers['X-Timestamp'],
            serverVersion: '2.0',
            source: 'sai-proxy-enhanced',
            sessionId: sessionInfo.sessionId,
            ip: sessionInfo.ip,
            userAgent: sessionInfo.userAgent,
            securityPassed: true
        }
    };
    
    try {
        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: headers,
            body: JSON.stringify(enhancedData),
            timeout: 30000
        });
        
        return response;
    } catch (error) {
        console.error('Webhook request failed:', error.message);
        throw error;
    }
}

// Serve static files
app.use(express.static(path.join(__dirname, 'static')));

// Session creation endpoint
app.post('/api/create-session', moderateRateLimit, ipBlockMiddleware, (req, res) => {
    const sessionToken = generateSessionToken();
    const sessionId = uuidv4();
    
    const session = {
        sessionId,
        sessionToken,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        createdAt: Date.now(),
        expiresAt: Date.now() + SESSION_DURATION,
        lastActivity: Date.now(),
        requestCount: 0
    };
    
    sessions.set(sessionToken, session);
    
    // Clean up expired sessions periodically
    if (Math.random() < 0.1) { // 10% chance to trigger cleanup
        const now = Date.now();
        for (const [token, sess] of sessions.entries()) {
            if (now > sess.expiresAt) {
                sessions.delete(token);
            }
        }
    }
    
    console.log(`🔐 New session created: ${sessionId} for IP: ${req.ip}`);
    
    res.json({
        success: true,
        sessionToken,
        expiresIn: SESSION_DURATION,
        message: 'Session created successfully'
    });
});

// Form submission endpoint with enhanced security
app.post('/api/submit-form', 
    strictRateLimit, 
    ipBlockMiddleware, 
    honeypotMiddleware, 
    validateSession, 
    async (req, res) => {
        
    const timestamp = new Date().toISOString();
    const requestId = uuidv4();
    
    console.log(`[${timestamp}] 📥 Form submission from ${req.body.localidad || 'unknown'}, ${req.body.provincia || 'unknown'} (Session: ${req.session.sessionId})`);
    
    try {
        // Track request count per session
        req.session.requestCount++;
        
        // Additional security: limit requests per session
        if (req.session.requestCount > 10) {
            console.warn(`⚠️  Session ${req.session.sessionId} exceeded request limit`);
            return res.status(429).json({
                success: false,
                error: 'Too many submissions from this session'
            });
        }
        
        // Sanitize all input
        const sanitizedBody = {};
        for (const [key, value] of Object.entries(req.body)) {
            if (key !== 'website') { // Skip honeypot field
                sanitizedBody[key] = sanitizeInput(value);
            }
        }
        
        // Validate form data
        const validation = validateFormData(sanitizedBody);
        if (!validation.valid) {
            return res.status(400).json({
                success: false,
                error: validation.message
            });
        }
        
        // Clean phone number
        if (sanitizedBody.telefono) {
            sanitizedBody.telefono = sanitizedBody.telefono
                .replace(/^\+54\s*/, '')
                .replace(/\s+/g, '');
        }
        
        // Send to webhook with retry logic
        let lastError = null;
        const maxRetries = 3;
        
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                const response = await sendToWebhook(sanitizedBody, {
                    sessionId: req.session.sessionId,
                    ip: req.ip,
                    userAgent: req.get('User-Agent')
                });
                
                if (response.ok) {
                    console.log(`[${timestamp}] ✅ Form submission successful (Request ID: ${requestId})`);
                    return res.json({
                        success: true,
                        message: 'Form submitted successfully',
                        requestId
                    });
                } else if (response.status >= 400 && response.status < 500) {
                    console.error(`[${timestamp}] ❌ Client error ${response.status}, not retrying`);
                    return res.status(response.status).json({
                        success: false,
                        error: 'Request could not be processed'
                    });
                } else {
                    lastError = new Error(`Server error: ${response.status}`);
                }
                
            } catch (error) {
                lastError = error;
            }
            
            if (attempt < maxRetries) {
                const delay = Math.min(1000 * Math.pow(2, attempt), 5000);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
        
        console.error(`[${timestamp}] ❌ All retry attempts failed:`, lastError?.message);
        res.status(500).json({
            success: false,
            error: 'Unable to process submission at this time'
        });
        
    } catch (error) {
        console.error(`[${timestamp}] ❌ Unexpected error:`, error.message);
        res.status(500).json({
            success: false,
            error: 'Internal server error'
        });
    }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    const sessionCount = sessions.size;
    const suspiciousIPCount = suspiciousIPs.size;
    
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        version: '2.0-enhanced',
        security: {
            activeSessions: sessionCount,
            suspiciousIPs: suspiciousIPCount,
            rateLimitEnabled: true,
            honeypotEnabled: true,
            sessionManagement: true
        },
        config: {
            webhookConfigured: !!WEBHOOK_URL,
            apiKeyConfigured: !!API_KEY,
            sessionDuration: SESSION_DURATION,
            maxLoginAttempts: MAX_LOGIN_ATTEMPTS
        }
    });
});

// Security status endpoint (admin only)
app.get('/api/security-status', (req, res) => {
    // Simple IP-based admin check (enhance with proper auth in production)
    const adminIPs = (process.env.ADMIN_IPS || '127.0.0.1').split(',');
    
    if (!adminIPs.includes(req.ip)) {
        return res.status(403).json({ error: 'Access denied' });
    }
    
    const activeSessions = Array.from(sessions.values()).map(session => ({
        sessionId: session.sessionId,
        ip: session.ip,
        createdAt: new Date(session.createdAt).toISOString(),
        lastActivity: new Date(session.lastActivity).toISOString(),
        requestCount: session.requestCount
    }));
    
    res.json({
        activeSessions,
        suspiciousIPs: Array.from(suspiciousIPs),
        totalSessions: sessions.size,
        ipAttempts: Object.fromEntries(ipAttempts)
    });
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Received SIGTERM, shutting down gracefully...');
    sessions.clear();
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Received SIGINT, shutting down gracefully...');
    sessions.clear();
    process.exit(0);
});

// Start server
app.listen(PORT, '127.0.0.1', () => {
    console.log(`🚀 SAI Proxy Server Enhanced v2.0 running on http://127.0.0.1:${PORT}`);
    console.log(`🔐 Security Features: Rate limiting, Session management, Honeypot protection`);
    console.log(`📡 Webhook URL: ${WEBHOOK_URL ? '✅ Configured' : '❌ NOT CONFIGURED'}`);
    console.log(`🔑 API Key: ${API_KEY ? '✅ Configured' : '❌ NOT CONFIGURED'}`);
    console.log(`⚙️  Session Duration: ${SESSION_DURATION / 1000}s`);
    console.log(`📊 Health check: http://127.0.0.1:${PORT}/api/health`);
});