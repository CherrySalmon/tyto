# Frontend API Gateway Refactor

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work.

## Branch
`ray/refactor-backend-gateway`

## Goal
Create a centralized API client (`frontend_app/lib/api.js`) that acts as the frontend's gateway to the backend API. This eliminates duplicated axios calls, auth header logic, and error handling scattered across 106+ locations in Vue components.

## Why
- **Single responsibility**: One module handles all HTTP/auth concerns
- **Consistency**: Uniform error handling, logging, and auth across all API calls
- **Maintainability**: Change auth scheme or error handling in one place
- **Testability**: Mock one module to test components in isolation
- **Matches backend architecture**: Similar to `infrastructure/auth/*/gateway.rb` pattern

## Current State
- [ ] Plan created
- [ ] API gateway module implemented
- [ ] Existing components migrated (optional, can be incremental)

## Design

### File Location
`frontend_app/lib/api.js`

### Responsibilities
1. Create axios instance with base URL `/api`
2. Attach auth header from cookieManager on every request
3. Handle common errors uniformly:
   - 401 → redirect to login
   - 422 → return validation errors
   - 500 → log and surface error message
4. Optional: request/response logging for dev mode

### Interface
```javascript
import api from '@/lib/api'

// Usage in components:
await api.get('/course')
await api.post('/course', { name: 'CS101' })
await api.put('/course/123', { name: 'CS102' })
await api.delete('/course/123')
```

### Implementation Sketch
```javascript
import axios from 'axios'
import cookieManager from './cookieManager'
import router from '../router'

const api = axios.create({
  baseURL: '/api'
})

// Request interceptor: attach auth
api.interceptors.request.use(config => {
  const account = cookieManager.getAccount()
  if (account?.credential) {
    config.headers.Authorization = account.credential
  }
  return config
})

// Response interceptor: handle errors
api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      cookieManager.clearAccount()
      router.push('/login')
    }
    return Promise.reject(error)
  }
)

export default api
```

## Migration Strategy
1. Implement `api.js` without touching existing code
2. New features use `api.js` exclusively
3. Optionally migrate existing components incrementally (not required for this branch)

## Questions

> Questions must be crossed off when resolved. Note the decision made.

(none yet)

## Tasks

- [ ] Create `frontend_app/lib/api.js`
- [ ] Verify it works with an existing endpoint
- [ ] Document usage in this file
- [ ] Update CLAUDE.md frontend section if needed

## Completed
(none yet)

---

*Last updated: 2026-02-05*
