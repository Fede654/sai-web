// Example server proxy to hide API key
// This would run on your server alongside the static files

const express = require('express');
const fetch = require('node-fetch');
const app = express();

// Serve static files
app.use(express.static('static'));
app.use(express.json());

// Hidden API key (not in HTML)
const WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;
const API_KEY = process.env.N8N_API_KEY;

// Proxy endpoint - API key stays on server
app.post('/api/submit-form', async (req, res) => {
    try {
        // Add security checks here
        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': API_KEY  // Hidden from client
            },
            body: JSON.stringify(req.body)
        });
        
        res.json({ success: response.ok });
    } catch (error) {
        res.status(500).json({ error: 'Submission failed' });  
    }
});

app.listen(8080, () => {
    console.log('Server running on http://localhost:8080');
});