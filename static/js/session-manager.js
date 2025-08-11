/**
 * SAI Session Manager
 * Handles client-side session tokens and secure form submissions
 */

class SAISessionManager {
    constructor() {
        this.sessionToken = null;
        this.sessionExpiry = null;
        this.apiBaseUrl = '/api';
        this.maxRetries = 3;
        
        // Initialize session on load
        this.initializeSession();
    }
    
    /**
     * Initialize session - create if needed or validate existing
     */
    async initializeSession() {
        try {
            // Check if we have a stored session
            const stored = this.getStoredSession();
            if (stored && this.isSessionValid(stored)) {
                this.sessionToken = stored.token;
                this.sessionExpiry = stored.expiry;
                console.log('📱 Using existing session token');
                return;
            }
            
            // Create new session
            await this.createSession();
        } catch (error) {
            console.error('❌ Session initialization failed:', error.message);
        }
    }
    
    /**
     * Create a new session with the server
     */
    async createSession() {
        try {
            console.log('🔐 Creating new session...');
            
            const response = await fetch(`${this.apiBaseUrl}/create-session`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                credentials: 'same-origin'
            });
            
            if (!response.ok) {
                if (response.status === 429) {
                    throw new Error('Too many requests. Please wait before trying again.');
                }
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            
            if (data.success) {
                this.sessionToken = data.sessionToken;
                this.sessionExpiry = Date.now() + data.expiresIn;
                
                // Store session
                this.storeSession({
                    token: this.sessionToken,
                    expiry: this.sessionExpiry
                });
                
                console.log('✅ Session created successfully');
            } else {
                throw new Error(data.error || 'Failed to create session');
            }
            
        } catch (error) {
            console.error('❌ Session creation failed:', error.message);
            throw error;
        }
    }
    
    /**
     * Submit form data with session authentication
     */
    async submitForm(formData) {
        // Ensure we have a valid session
        if (!this.sessionToken || !this.isSessionValid()) {
            console.log('🔄 Session expired, creating new one...');
            await this.createSession();
        }
        
        let lastError = null;
        
        for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
            try {
                console.log(`📤 Submitting form (attempt ${attempt}/${this.maxRetries})...`);
                
                const response = await fetch(`${this.apiBaseUrl}/submit-form`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Session-Token': this.sessionToken
                    },
                    body: JSON.stringify(formData),
                    credentials: 'same-origin'
                });
                
                const result = await response.json();
                
                if (response.ok && result.success) {
                    console.log('✅ Form submitted successfully');
                    return {
                        success: true,
                        message: result.message,
                        requestId: result.requestId
                    };
                }
                
                // Handle specific error cases
                if (response.status === 401) {
                    console.log('🔄 Session expired, creating new one...');
                    await this.createSession();
                    continue; // Retry with new session
                }
                
                if (response.status === 429) {
                    const retryAfter = response.headers.get('Retry-After') || 'some time';
                    throw new Error(`Too many requests. Please wait ${retryAfter} before trying again.`);
                }
                
                if (response.status === 400) {
                    throw new Error(result.error || 'Invalid form data');
                }
                
                lastError = new Error(result.error || `Server error: ${response.status}`);
                
            } catch (error) {
                lastError = error;
                console.warn(`⚠️ Attempt ${attempt} failed:`, error.message);
                
                // Don't retry on client errors
                if (error.message.includes('Too many requests') || 
                    error.message.includes('Invalid form data')) {
                    throw error;
                }
                
                // Wait before retry
                if (attempt < this.maxRetries) {
                    const delay = Math.min(1000 * attempt, 5000);
                    console.log(`⏳ Waiting ${delay}ms before retry...`);
                    await this.sleep(delay);
                }
            }
        }
        
        throw lastError || new Error('Failed to submit form after retries');
    }
    
    /**
     * Check if current session is valid
     */
    isSessionValid(session = null) {
        if (session) {
            return session.token && session.expiry > Date.now();
        }
        return this.sessionToken && this.sessionExpiry > Date.now();
    }
    
    /**
     * Store session in localStorage
     */
    storeSession(session) {
        try {
            localStorage.setItem('sai_session', JSON.stringify(session));
        } catch (error) {
            console.warn('Failed to store session:', error.message);
        }
    }
    
    /**
     * Get stored session from localStorage
     */
    getStoredSession() {
        try {
            const stored = localStorage.getItem('sai_session');
            return stored ? JSON.parse(stored) : null;
        } catch (error) {
            console.warn('Failed to retrieve stored session:', error.message);
            return null;
        }
    }
    
    /**
     * Clear session data
     */
    clearSession() {
        this.sessionToken = null;
        this.sessionExpiry = null;
        try {
            localStorage.removeItem('sai_session');
        } catch (error) {
            console.warn('Failed to clear stored session:', error.message);
        }
    }
    
    /**
     * Get session status
     */
    getSessionStatus() {
        return {
            hasSession: !!this.sessionToken,
            isValid: this.isSessionValid(),
            expiresAt: this.sessionExpiry ? new Date(this.sessionExpiry).toISOString() : null,
            timeUntilExpiry: this.sessionExpiry ? Math.max(0, this.sessionExpiry - Date.now()) : null
        };
    }
    
    /**
     * Utility function for delays
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

/**
 * Form Handler - Enhanced form submission with session management
 */
class SAIFormHandler {
    constructor() {
        this.sessionManager = new SAISessionManager();
        this.isSubmitting = false;
        
        // Initialize after DOM is loaded
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.init());
        } else {
            this.init();
        }
    }
    
    init() {
        // Find and attach to forms
        const forms = document.querySelectorAll('form[data-api-endpoint]');
        forms.forEach(form => this.attachFormHandler(form));
        
        // Show session status in test mode
        if (this.isTestMode()) {
            this.showSessionStatus();
        }
    }
    
    attachFormHandler(form) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            if (this.isSubmitting) {
                console.log('⏳ Submission already in progress...');
                return;
            }
            
            await this.handleFormSubmit(form);
        });
    }
    
    async handleFormSubmit(form) {
        this.isSubmitting = true;
        
        try {
            // Show loading state
            this.setFormState(form, 'loading');
            
            // Collect form data
            const formData = this.collectFormData(form);
            
            // Submit via session manager
            const result = await this.sessionManager.submitForm(formData);
            
            if (result.success) {
                this.setFormState(form, 'success', result.message);
                form.reset();
            } else {
                this.setFormState(form, 'error', result.error || 'Submission failed');
            }
            
        } catch (error) {
            console.error('Form submission error:', error);
            this.setFormState(form, 'error', error.message);
        } finally {
            this.isSubmitting = false;
        }
    }
    
    collectFormData(form) {
        const data = {};
        const formData = new FormData(form);
        
        for (const [key, value] of formData.entries()) {
            data[key] = value;
        }
        
        return data;
    }
    
    setFormState(form, state, message = '') {
        const submitButton = form.querySelector('button[type="submit"]');
        const btnText = submitButton?.querySelector('.btn-text');
        const btnLoading = submitButton?.querySelector('.btn-loading');
        
        // Remove previous state classes
        form.classList.remove('form-loading', 'form-success', 'form-error');
        
        switch (state) {
            case 'loading':
                form.classList.add('form-loading');
                if (submitButton) submitButton.disabled = true;
                if (btnText) btnText.style.display = 'none';
                if (btnLoading) btnLoading.style.display = 'inline';
                break;
                
            case 'success':
                form.classList.add('form-success');
                if (submitButton) submitButton.disabled = false;
                if (btnText) btnText.style.display = 'inline';
                if (btnLoading) btnLoading.style.display = 'none';
                this.showMessage('success', message);
                break;
                
            case 'error':
                form.classList.add('form-error');
                if (submitButton) submitButton.disabled = false;
                if (btnText) btnText.style.display = 'inline';
                if (btnLoading) btnLoading.style.display = 'none';
                this.showMessage('error', message);
                break;
                
            default:
                if (submitButton) submitButton.disabled = false;
                if (btnText) btnText.style.display = 'inline';
                if (btnLoading) btnLoading.style.display = 'none';
        }
    }
    
    showMessage(type, message) {
        // Create or update message element
        let messageEl = document.getElementById('form-message');
        
        if (!messageEl) {
            messageEl = document.createElement('div');
            messageEl.id = 'form-message';
            messageEl.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                padding: 15px 20px;
                border-radius: 8px;
                max-width: 400px;
                z-index: 10000;
                animation: slideIn 0.3s ease;
            `;
            document.body.appendChild(messageEl);
        }
        
        messageEl.className = `form-message form-message-${type}`;
        messageEl.textContent = message;
        
        // Auto-hide success messages
        if (type === 'success') {
            setTimeout(() => {
                if (messageEl.parentNode) {
                    messageEl.parentNode.removeChild(messageEl);
                }
            }, 5000);
        }
    }
    
    isTestMode() {
        return new URLSearchParams(window.location.search).has('test');
    }
    
    showSessionStatus() {
        const status = this.sessionManager.getSessionStatus();
        console.log('🔐 Session Status:', status);
        
        // Show session info in test mode banner
        const banner = document.getElementById('test-mode-banner');
        if (banner) {
            banner.innerHTML += `<br>🔐 Session: ${status.hasSession ? '✅ Active' : '❌ None'} | 
                Valid: ${status.isValid ? '✅ Yes' : '❌ No'}`;
        }
    }
}

// Add CSS for animations and states
const styles = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    
    .form-message-success {
        background: #d4edda;
        color: #155724;
        border: 1px solid #c3e6cb;
    }
    
    .form-message-error {
        background: #f8d7da;
        color: #721c24;
        border: 1px solid #f5c6cb;
    }
    
    .form-loading .btn-text {
        display: none !important;
    }
    
    .form-loading .btn-loading {
        display: inline !important;
    }
`;

// Inject styles
const styleSheet = document.createElement('style');
styleSheet.textContent = styles;
document.head.appendChild(styleSheet);

// Initialize form handler
const saiFormHandler = new SAIFormHandler();

// Export for global access
window.SAI = {
    sessionManager: saiFormHandler.sessionManager,
    formHandler: saiFormHandler
};