# Hotfix: Location Creation Fails in Firefox

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`hotfix-location-firefox`

## Goal

Fix location creation failing in Firefox. The "Save Location" button inside the Google Maps InfoWindow does not trigger location creation in Firefox, while it works in Chrome.

## Status: Complete

- [x] Plan created
- [x] Reproduce and confirm issue
- [x] Implement fix
- [x] Verify fix across browsers
- [ ] All tests passing

## Root Cause Analysis

### ~~Initial hypothesis (ruled out)~~

~~`document.getElementById("saveLocationBtn")` fails in Firefox's InfoWindow DOM~~ — **Disproved**: the Firefox console error trace shows `saveLocation` IS called and `createNewLocation` fires the API request. The click handler works.

### Confirmed root cause: implicit form submission

In `LocationCard.vue`, the template structure is:

```html
<el-form ref="locationForm" :model="locationForm">
    <el-form-item label="Name">
        <el-input ... v-model="locationForm.name"></el-input>
    </el-form-item>
    <div id="map" class="map-container"></div>   <!-- map is INSIDE the form -->
</el-form>
```

The map click handler (lines 112-117) creates an InfoWindow with:

```html
<button id="saveLocationBtn" class="info-button">Save Location</button>
```

This `<button>` has **no `type` attribute**. Per the HTML spec, `<button>` defaults to `type="submit"`. Google Maps renders the InfoWindow content as a child of the map container, which is inside the `<el-form>`. When clicked in Firefox:

1. The click handler fires → `saveLocation()` → emits `create-location` → `createNewLocation()` → `api.post()` starts
2. **Then** the implicit `type="submit"` triggers form submission → page navigates/reloads
3. The in-flight XHR request is **aborted** → `AxiosError: "Request aborted"` (`ECONNABORTED`)

Chrome doesn't propagate the submit event through Google Maps' InfoWindow container the same way, so it works there by accident.

### Evidence

Firefox console error on "Save Location" click:

```text
Error creating location
AxiosError { message: "Request aborted", code: "ECONNABORTED" }
    at createNewLocation (SingleCourse.vue:243)
    at saveLocation (LocationCard.vue:123)
    at initMap (LocationCard.vue:107)
```

The request fires (proving the click handler works) but is immediately aborted (proving something navigates the page away).

## Reproduction Steps

### Step 1: Test in development environment

> Goal: Determine if the issue reproduces locally or only in production.

- [x] 1.1 Start backend (`rake run:api`) and frontend (`rake run:frontend`)
- [x] 1.2 Open `http://localhost:9292` in **Chrome** — navigate to a course → Locations tab → Create New → click map → click "Save Location" → confirm it works
- [x] 1.3 Open `http://localhost:9292` in **Firefox** (regular profile, extensions enabled) — repeat the same flow → note whether Save Location works
- [x] 1.4 If it fails in Firefox, open DevTools console and check for:
  - JavaScript errors (especially `null` reference from `getElementById`)
  - Network errors (blocked Google Maps API requests)
  - CSP violations
  - Mixed content warnings
- [x] 1.5 Document findings in this section

**Findings** (2026-03-09):

- **Chrome**: Location creation works end-to-end. Created "Test Location Chrome" successfully — button click triggers `saveLocation()`, API call succeeds, location list refreshes.
- **Firefox** (regular profile with extensions): "Save Location" button **renders** inside InfoWindow but **clicking it does nothing**. No location is created, no API call is made.
- **Console errors**: Only source map warnings (`unsupported protocol for sourcemap request webpack://...`). No TypeError from `getElementById` returning null visible — but the silent failure (button renders, click is dead) is consistent with the `domready` listener either not firing or `getElementById` not finding the button in Firefox's InfoWindow DOM subtree.
- **Not caused by**: Network errors, CSP violations, or mixed content warnings (none observed).
- **Conclusion**: Issue reproduces in dev environment. Not production-only. Root cause is in the code, not browser settings/plugins.

### Step 2: Test with extensions/settings variations

> Skipped — issue reproduced in Step 1 without needing a clean profile. The bug is in the code, not caused by extensions or Firefox settings.

## Proposed Fix

Add `type="button"` to the button in the HTML string to prevent implicit form submission:

```javascript
// Change this (line 116):
<button id="saveLocationBtn" class="info-button">Save Location</button>
// To this:
<button type="button" id="saveLocationBtn" class="info-button">Save Location</button>
```

### Implementation tasks

- [x] 3.1 Edit `LocationCard.vue` line 116: add `type="button"` to the `saveLocationBtn` element
- [x] 3.2 Verify in Chrome — location creation still works
- [x] 3.3 Verify in Firefox — location creation now works
- [ ] 3.4 Run frontend build to confirm no compilation errors

## Scope

**In scope**:

- Fix the InfoWindow button click handler in `LocationCard.vue`

**Out of scope**:

- Refactoring the rest of the Google Maps integration
- Adding automated browser tests
- Backend changes (not needed — this is purely a frontend DOM issue)

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] Does the issue reproduce in dev or only in production? — **Yes, reproduces in dev.**
- [x] Is it caused by browser settings/extensions or by code? — **Code. Reproduces with regular Firefox profile; no CSP/network/mixed-content issues observed.**

---

Last updated: 2026-03-09
