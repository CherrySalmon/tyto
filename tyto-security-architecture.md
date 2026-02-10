# Tyto Security Architecture Assessment

**Date:** February 2026
**Scope:** Evaluate whether Tyto needs a Backend-for-Frontend (BFF) architecture
**Status:** Decision document (not an implementation plan)

---

## Executive Summary

**Decision: Tyto does not need a separate BFF service.** Its existing architecture — where the Ruby Roda backend serves both the SPA and the API on the same origin — already provides the structural benefits of a BFF. The frontend never calls external APIs directly, and all secrets remain server-side.

However, there are meaningful security gaps in the current implementation that should be addressed regardless of architectural pattern. These are incremental improvements to the existing architecture, not a redesign.

---

## Current Architecture Analysis

### What Tyto Gets Right

#### 1. Same-origin architecture (the most important part)

Tyto's Roda backend serves both static frontend files (`dist/`) and API routes (`/api/*`) from the same server. This eliminates the primary motivation for a separate BFF — there is no cross-origin communication, no CORS complexity, and no need for an intermediary proxy.

```text
Browser → https://yourdomain.com (Roda serves both)
  ├── / → dist/index.html (SPA)
  └── /api/* → Roda route handlers
```

#### 2. Secrets stay server-side

- `JWT_KEY` (RbNaCl encryption key): server-only via `secrets.yml`
- Google OAuth client secret: server-only
- Database credentials: server-only
- The frontend env vars (`VUE_APP_GOOGLE_CLIENT_ID`, `VUE_APP_GOOGLE_MAP_KEY`) are public identifiers, not secrets

#### 3. Server-side authorization

The policy pattern (`CoursePolicy`, `EventPolicy`, `AccountPolicy`, etc.) enforces authorization on every API request. User identity comes from the encrypted JWT token, not from client-supplied data. The `verify_policy` pattern in services provides defense-in-depth.

#### 4. Backend validates Google OAuth

The frontend receives a Google access token via `vue3-google-login`, but immediately sends it to the backend (`POST /api/auth/verify_google_token`). The backend validates with Google's API, creates/retrieves the user, and issues its own encrypted credential. The frontend never handles the OAuth flow independently.

#### 5. Encrypted (not just signed) tokens

Tyto uses RbNaCl SecretBox (XSalsa20-Poly1305) for token encryption. This means token contents cannot be read or tampered with by the client — stronger than typical JWT signing.

### Security Gaps to Address

#### 1. JWT stored in JavaScript-readable cookies (moderate risk)

The encrypted JWT is stored using `js-cookie` (`Cookies.set('account_credential', ...)`) without `httpOnly` or `secure` flags. Multiple user attributes (id, roles, name, avatar) are also stored in separate readable cookies.

- An XSS vulnerability could exfiltrate the credential cookie
- The encrypted JWT mitigates some risk (attacker gets an opaque blob, not readable token data)
- But the stolen credential can still be replayed in API requests

#### 2. Excessive session duration (high risk)

Cookies are set with a 180-day expiry. A stolen credential is valid for 6 months. For a university course management app, 8-24 hours is far more appropriate. This is the easiest fix with the biggest impact.

#### 3. No CSRF protection (low risk currently, but important for future)

There are no CSRF tokens or `SameSite` cookie attributes. However, the current auth pattern provides **natural CSRF resistance**: the frontend manually reads the credential from a cookie and sets it as an `Authorization: Bearer` header. Cross-site forms and links cannot set custom headers, so CSRF attacks cannot forge authenticated requests. This is actually stronger than many cookie-based apps. CSRF protection becomes necessary only if/when auth moves to httpOnly cookies (which browsers send automatically).

#### 4. Missing security headers (low-moderate risk)

Only HSTS is configured (via `Rack::SslEnforcer` in production). Missing:

- `Content-Security-Policy`
- `X-Frame-Options`
- `X-Content-Type-Options`
- `Referrer-Policy`

#### 5. No rate limiting (low-moderate risk)

No rate limiting on API endpoints, including authentication. For a course management app this is lower risk than for a public-facing service, but brute-force protection on auth endpoints is still worthwhile.

#### 6. Google Maps API key in frontend (low risk)

`VUE_APP_GOOGLE_MAP_KEY` is bundled into the frontend. This is a public API key (Google expects it to be in client code), but should be restricted via Google Cloud Console to specific referrers/APIs to prevent misuse.

#### 7. Client-side role storage (informational)

Roles are stored in a readable cookie (`account_roles`) and used for UI rendering decisions. This is acceptable for UI purposes only — and Tyto correctly re-validates roles server-side via the encrypted JWT on every API request. The readable cookie is a convenience for the frontend, not a security boundary.

---

## Why Tyto Does Not Need a Separate BFF

The BFF pattern guide identifies several scenarios where a dedicated BFF is necessary. Here is how Tyto maps against each:

| BFF Guide Concern | Tyto's Situation | BFF Needed? |
| --- | --- | --- |
| Frontend calls external APIs with secrets | No — all external calls (Google OAuth) go through the backend | No |
| OAuth tokens stored in localStorage | Tokens stored in cookies (not httpOnly, but encrypted). Backend manages the Google OAuth exchange. | No (fix cookie flags instead) |
| Client-side authorization only | Server-side policies enforce all access control | No |
| Multiple backend APIs needing orchestration | Single Roda backend handles everything | No |
| Frontend bundles API keys/secrets | Only public identifiers in frontend env | No |
| CORS complexity with multiple origins | Same-origin — no CORS needed | No |

**The Roda backend already IS the BFF.** It:

- Receives frontend requests on the same origin
- Holds all secrets
- Manages the OAuth exchange with Google
- Issues and validates encrypted credentials
- Enforces authorization via policies
- Serves as the single point of API access

Adding a separate BFF service would introduce unnecessary infrastructure complexity (another deployment, another failure point, inter-service communication) with no security benefit.

---

## Threat Model Context

Tyto is a **course management and attendance tracking application** used in educational settings. This matters for threat modeling:

- **Data sensitivity:** Course enrollments, attendance records, user emails. Sensitive but not financial or medical data.
- **User base:** Students and instructors at educational institutions. Not a high-value target for credential theft.
- **Attack surface:** Limited — Google OAuth means no password database to steal. Encrypted JWTs mean no readable token contents.
- **Likely threats:** XSS (from any user-generated content), session hijacking (if cookies are stolen), unauthorized access to courses (mitigated by policies).

This context does not excuse security gaps, but it does inform proportionate response. The improvements listed below are all worthwhile regardless of the threat model.

---

## Recommended Security Improvements

These are improvements to the existing architecture, not a redesign. Grouped by priority.

### High Priority

1. **Shorten session duration** — Reduce cookie expiry from 180 days to 8-24 hours. This is the easiest fix with the biggest impact: a stolen credential is currently valid for 6 months.

2. **Add rate limiting** — Add `rack-attack` gem, especially on `/api/auth/verify_google_token`. Protects against credential stuffing and brute-force abuse.

3. **Add security headers** — Configure Roda to send `Content-Security-Policy`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, and `Referrer-Policy` headers via Rack middleware. CSP is particularly important as the primary defense against XSS — the main remaining threat vector.

### Medium Priority

1. **Add cookie security flags** — Set `Secure` (HTTPS-only) and `SameSite=Lax` on all cookies. Currently no flags are set.

2. **Remove plaintext account metadata from cookies** — `account_roles`, `account_id`, `account_name`, `account_img` are stored in JS-readable cookies as a frontend convenience. The server already has all this data from the encrypted credential and never trusts the cookie values. Move this data to a server endpoint (e.g., `/api/auth/me`) to reduce cookie surface area and XSS information disclosure.

3. **Stop persisting Google access_token in the database** — The backend stores the Google access token after verification. Google access tokens are short-lived (~1 hour) and only needed during the initial userinfo API call. This is unnecessary data retention.

4. **Restrict Google Maps API key** — In Google Cloud Console, restrict the Maps API key to your domain and to only the Maps JavaScript API.

### Low Priority (Phase 2)

1. **Consider httpOnly cookie migration** — The current pattern (JS reads credential cookie, sets `Authorization: Bearer` header) provides natural CSRF resistance but allows XSS token theft. The alternative (httpOnly cookie, server reads auth from cookie) prevents XSS theft but requires adding CSRF tokens and rearchitecting the frontend auth transport. Both approaches have trade-offs. The current approach is acceptable for Tyto's threat model if combined with a strong CSP (item 3). The httpOnly migration is a cleaner long-term architecture.

### Bug Fix (Not Security Architecture)

- `RolePolicy#include_admin_role?` references `@new_role` (singular) instead of `@new_roles` (the actual instance variable). Worth fixing independently.

---

## Conclusion

Tyto's architecture is fundamentally sound for its use case. The single-origin Roda backend serving both SPA and API already provides the core security property that the BFF pattern exists to achieve: **secrets and authorization enforcement live server-side, not in the browser.**

The recommended path forward is not an architectural redesign but targeted hardening of the existing implementation — starting with session duration, rate limiting, and security headers, which address the most significant gaps with the least disruption.

### A Note on the Authorization Header Pattern

Tyto's current approach — where the frontend reads the credential from a cookie and manually sets the `Authorization: Bearer` header — is worth calling out as a design strength. Because browsers do not automatically attach custom headers to cross-site requests, this pattern provides natural CSRF resistance without CSRF tokens. This is actually a stronger CSRF posture than many session-cookie-based applications. If/when migrating to httpOnly cookies in the future, this natural resistance would be lost and explicit CSRF protection would become required.
