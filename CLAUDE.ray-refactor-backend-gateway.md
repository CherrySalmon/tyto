# Frontend API Gateway Refactor

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work.

## Branch
`ray/refactor-backend-gateway`

## Goal
Create a centralized API client (`frontend_app/lib/tyto-api.js`) that acts as the frontend's gateway to the backend API. This eliminates duplicated axios calls, auth header logic, and error handling scattered across 39 calls in 8 Vue components.

## Why
- **Single responsibility**: One module handles all HTTP/auth concerns
- **Consistency**: Uniform error handling, logging, and auth across all API calls
- **Maintainability**: Change auth scheme or error handling in one place
- **Testability**: Mock one module to test components in isolation
- **Matches backend architecture**: Similar to `infrastructure/auth/*/gateway.rb` pattern

## Current State
- [x] Plan created
- [ ] API gateway module implemented
- [ ] Verified working with existing endpoint

## Next Step (Requires Consultation)
- [ ] Migrate existing 39 axios calls to use gateway — **do not start without discussing scope and approach first**

## Design

### File Location
`frontend_app/lib/tyto-api.js`

### Responsibilities
1. Create axios instance with base URL `/api`
2. Attach `Bearer` auth header from cookieManager on every request
3. Handle 401 errors: clear cookies and redirect to `/login`
4. Return full axios response (callers handle 422/500 contextually)
5. Future: Consider dev-mode request/response logging

### Interface
```javascript
import api from '@/lib/tyto-api'

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

const api = axios.create({
  baseURL: '/api'
})

// Request interceptor: attach auth
api.interceptors.request.use(config => {
  const account = cookieManager.getAccount()
  if (account?.credential) {
    config.headers.Authorization = `Bearer ${account.credential}`
  }
  return config
})

// Response interceptor: handle errors
api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      cookieManager.onLogout()
      window.location.href = '/login'
    }
    // 422/500: Left to callers for contextual handling
    return Promise.reject(error)
  }
)

export default api
```

## Migration Strategy

### Phase 1: Gateway Implementation (This Branch)
1. Implement `tyto-api.js` without touching existing code
2. Verify it works with an existing endpoint
3. New features use `tyto-api.js` exclusively

### Phase 2: Migrate Existing Calls (Future — Requires Consultation)
Existing 39 axios calls across 8 files can continue working as-is. Migration is **not automatic** — discuss before starting:
- `AllCourse.vue` (9 calls)
- `SingleCourse.vue` (14 calls)
- `AttendanceTrack.vue` (6 calls)
- `ManageAccount.vue` (3 calls)
- `ManageCourse.vue` (3 calls)
- `AttendanceEventCard.vue` (2 calls)
- `Login.vue` (1 call)
- `FileUpload.vue` (1 call)

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] **Q1: Return value convention** — Should `api.get()` return the full axios `response` or unwrap to `response.data`? Current code often does `response.data.data` to get the payload.
  - **Decision**: Return full response for easier migration. Consider unwrapping as a future enhancement after major refactoring.
- [x] **Q2: 422/500 handling** — Should the gateway handle these uniformly (e.g., show toast notification) or leave error handling to individual callers?
  - **Decision**: Leave to callers. Gateway only handles 401 (redirect to login). Components handle validation/server errors contextually.

## Tasks (Phase 1)

- [ ] Create `frontend_app/lib/tyto-api.js`
- [ ] Verify it works with an existing endpoint
- [ ] Document usage in this file

## Completed
(none yet)

---

*Last updated: 2026-02-05*
