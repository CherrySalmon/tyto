# Refactor Frontend Cleanup — Slice 7: Frontend Utilities

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`refactor-frontend-cleanup`

## Goal

Extract duplicated frontend utility code (geolocation, date formatting, attendance logic) into shared modules, completing Slice 7 — the final slice of the frontend-to-backend DDD refactoring.

## Strategy: Frontend-Only Cleanup

No backend changes. This slice extracts duplicated Vue component logic into shared utilities under `frontend_app/lib/`. File naming: **PascalCase** for `.vue` components (Vue standard), **concern-based names** for `.js` modules (e.g., `session.js`, `attendance.js`, `dates.js` — named by domain concern, not by mechanism or pattern suffix).

1. **Analyze** — Identify all duplicated code across components
2. **Extract** — Create shared utility modules
3. **Update** — Refactor components to use shared utilities
4. **Verify** — Manual testing confirms no regressions

## Current State

- [x] Plan created
- [x] Duplicated code analyzed (see Key Findings)
- [x] Geolocation utility extracted
- [x] Date formatting utility extracted
- [x] Shared attendance logic extracted
- [x] Components updated to use utilities
- [x] Deprecated logic removed
- [ ] Manual verification

## Key Findings

### Duplicated Geolocation Functions

`AttendanceTrack.vue` and `AllCourse.vue` share **identical** implementations of:

| Method | Purpose |
| ------ | ------- |
| `getLocation(event)` | Shows loading overlay, calls `navigator.geolocation.getCurrentPosition` |
| `showPosition(position, loading, event)` | Stores lat/lng from position, calls `postAttendance` |
| `showError(error, loading)` | Maps geolocation error codes to user messages |

A third component, `LocationCard.vue`, has its own `getCurrentLocation()` with a different flow (stores coords + initializes map). This is a **different use case** (location setup, not attendance) — extracting only the raw geolocation promise wrapper would benefit it, but refactoring its full flow is out of scope.

### Duplicated Attendance Logic

`AttendanceTrack.vue` and `AllCourse.vue` share **identical** implementations of:

| Method | Purpose |
| ------ | ------- |
| `postAttendance(loading, event)` | POSTs to `/course/:id/attendance`, shows success/error dialogs |
| `updateEventAttendanceStatus(eventId, status)` | Finds event in local array, sets `isAttendanceExisted` flag |

These are tightly coupled: `getLocation` → `showPosition` → `postAttendance` → `updateEventAttendanceStatus`. The entire attendance-recording flow should be extracted as one cohesive module.

### Duplicated Date Formatting

`getLocalDateString(utcStr)` is duplicated in `AttendanceTrack.vue` and `CourseInfoCard.vue`:

- Parses ISO 8601 UTC string → local `YYYY-MM-DD HH:MM` format
- Includes null/NaN guard with `'Invalid Date'` fallback

Minor differences: `CourseInfoCard` returns `false` instead of `'Invalid Date'` for null input. Normalize to return `null` (more idiomatic for Vue template `v-if` checks).

### Component Data Dependencies

The attendance functions reference component-level `data()` properties:

- `this.latitude`, `this.longitude` — set by `showPosition`, read by `postAttendance`
- `this.events` — mutated by `updateEventAttendanceStatus`
- `this.errMessage` / `this.locationText` — set by `showError`

**Design choice**: The extracted module will accept an `events` ref/array and return a function that handles the full flow. Component state (`latitude`, `longitude`) becomes internal to the module. The `events` array mutation and error display remain callbacks/return values so components stay in control of their own state.

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] ~~Module style: ES module functions vs. Vue composable?~~ **Decision: Plain ES module functions in `lib/`. Vue composables (`useX`) would add coupling to Vue's reactivity system for what are essentially stateless utilities. The attendance flow function accepts callbacks for state mutation. This matches the existing `lib/` convention.**
- [x] ~~Should `LocationCard.vue` geolocation be refactored too?~~ **Decision: Only extract the low-level geolocation promise wrapper that `LocationCard` could optionally adopt. Don't refactor `LocationCard`'s map initialization flow — it's a different use case and out of scope for this cleanup slice.**
- [x] ~~`getLocalDateString` null return value: `'Invalid Date'` vs `false` vs `null`?~~ **Decision: Return `null` for invalid/missing input. More idiomatic for Vue templates (`v-if="formattedDate"`) and avoids rendering the literal string `'Invalid Date'`.**
- [x] ~~File naming convention for `lib/` modules: camelCase vs kebab-case?~~ **Decision: Name `.js` modules by domain concern (e.g., `session.js`, `attendance.js`, `dates.js`), not by mechanism or pattern suffix (`-Manager`, `Formatter`). Went through kebab-case → camelCase → concern-based naming. Final convention: short, descriptive names that match JS import style (`import session from './lib/session'`). PascalCase for `.vue` components (Vue standard).**

## Scope

**In scope**:

- Extract `frontend_app/lib/geolocation.js` — promise-based geolocation wrapper + error message mapper
- Extract `frontend_app/lib/dates.js` — `formatLocalDateTime(utcStr)` utility
- Extract `frontend_app/lib/attendance.js` — full attendance-recording flow (`recordAttendance`)
- Extract `frontend_app/lib/roles.js` — consolidated role definitions (labels + descriptions) used by multiple components
- Update `AttendanceTrack.vue`, `AllCourse.vue`, `CourseInfoCard.vue`, `ManageAccount.vue` to use shared utilities
- Remove duplicated method definitions from components

**Out of scope**:

- Refactoring `LocationCard.vue` map initialization flow
- Backend changes (none needed — this is Slice 7)
- Date format changes (the open question about ISO 8601 vs. locale strings from the parent plan is deferred)
- Adding frontend tests (no test infrastructure exists; E2E deferred per parent test plan)

**Frontend changes**:

New files:

- `frontend_app/lib/geolocation.js` — `getCurrentPosition()` returns Promise; `getGeolocationErrorMessage(error)` maps error codes
- `frontend_app/lib/dates.js` — `formatLocalDateTime(utcStr)` returns `'YYYY-MM-DD HH:MM'` or `null`
- `frontend_app/lib/attendance.js` — `recordAttendance(event, { onSuccess, onError, onDuplicate })` orchestrates the full flow: get location → POST attendance → invoke callback
- `frontend_app/lib/roles.js` — `SYSTEM_ROLES` definitions, `roleOptions` for dropdowns, `describeRoles(roles)` for display

Renamed files:

- `frontend_app/lib/cookieManager.js` → `frontend_app/lib/session.js` (named by concern: auth session management)
- `frontend_app/lib/tyto-api.js` → `frontend_app/lib/tytoApi.js` (camelCase consistency)

Modified files:

- `frontend_app/pages/course/AttendanceTrack.vue` — remove 5 methods, import from shared modules
- `frontend_app/pages/course/AllCourse.vue` — remove 5 methods + `features` data object, import from shared modules including `describeRoles`
- `frontend_app/pages/course/components/CourseInfoCard.vue` — remove `getLocalDateString`, import `formatLocalDateTime`
- `frontend_app/pages/ManageAccount.vue` — remove hardcoded `roleOptions`, import from `roles.js`

## Tasks

> Note: No backend tests for this slice — pure frontend extraction with no behavior changes.

- [x] ~~0 Rename `cookieManager.js` → `cookie-manager.js`, `downloadFile.js` → `download-file.js`~~ (reverted — camelCase adopted as convention)
- [x] 1 Create `frontend_app/lib/geolocation.js` with `getCurrentPosition()` promise wrapper and `getGeolocationErrorMessage(error)` mapper
- [x] 2 Create `frontend_app/lib/dates.js` with `formatLocalDateTime(utcStr)` utility
- [x] 3 Create `frontend_app/lib/attendance.js` with `recordAttendance(event, callbacks)` that orchestrates geolocation → POST → status update
- [x] 4a Update `AttendanceTrack.vue` — remove duplicated methods, import and use shared modules
- [x] 4b Update `AllCourse.vue` — remove duplicated methods, import and use shared modules
- [x] 4c Update `CourseInfoCard.vue` — remove `getLocalDateString`, import `formatLocalDateTime`
- [x] 5 Remove any remaining deprecated logic from components
- [x] 5b Consolidate duplicated role definitions — extract `lib/roles.js`, update `AllCourse.vue` and `ManageAccount.vue`
- [ ] 6 Manual verification: test attendance recording from both AttendanceTrack and AllCourse views, verify date display on CourseInfoCard, verify role descriptions on AllCourse and role dropdown on ManageAccount

## Completed

- Task 0: Renamed lib/ files to concern-based names: `cookieManager` → `session`, `attendanceManager` → `attendance`, `dateFormatter` → `dates`, `tyto-api` → `tytoApi`. Updated all imports and variable references across 8 files.
- Task 1: Created `lib/geolocation.js` — `getCurrentPosition()` promise wrapper + `getGeolocationErrorMessage()` error mapper
- Task 2: Created `lib/dates.js` — `formatLocalDateTime(utcStr)` returns `YYYY-MM-DD HH:MM` or `null`
- Task 3: Created `lib/attendance.js` — `recordAttendance(event, {onSuccess, onError, onDuplicate})` orchestrates geolocation → POST → callbacks
- Task 4a: Updated `AttendanceTrack.vue` — replaced 5 methods with imports from shared modules; removed unused data properties (`latitude`, `longitude`, `errMessage`, `locationText`)
- Task 4b: Updated `AllCourse.vue` — replaced 4 methods with imports from shared modules
- Task 4c: Updated `CourseInfoCard.vue` — replaced inline `getLocalDateString` with `formatLocalDateTime` import; removed empty `data()`
- Task 5: No remaining deprecated logic found — all duplicated code removed during tasks 4a–4c
- Task 5b: Created `lib/roles.js` with `SYSTEM_ROLES`, `roleOptions`, and `describeRoles()`; updated `AllCourse.vue` (removed `features` data + `getFeatures` method) and `ManageAccount.vue` (removed hardcoded `roleOptions` array)
- Production build verified: `npm run prod` compiles successfully

---

**Last updated**: 2026-02-10
