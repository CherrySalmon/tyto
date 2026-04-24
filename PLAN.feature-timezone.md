# Timezone-Aware Event Scheduling

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`feature-timezone`

## Goal

Fix timezone handling so events display at the correct local time regardless of where the server runs or where the user's browser is.

## Strategy: Vertical Slice

Two slices. Slice 1 fixes the immediate production bug with a pure frontend change. Slice 2 (deferred) adds course-level timezone metadata for richer UX and display labelling.

1. **Backend test** — Write a failing test proving the API accepts offset-aware ISO8601 and round-trips the correct UTC (Slice 1 only)
2. **Frontend fix** — Change bulk event string construction to emit UTC ISO8601
3. **Production repair** — Run a targeted SQL update to fix already-created wrong events
4. **Verify** — Manual smoke test confirms new bulk events land at the right time

## Current State

- [x] Plan created
- [x] Q1 resolved (production repair scope)
- [x] Q2 resolved (Slice 2 scope decision)
- [x] Slice 1 complete

## Key Findings

**Root cause of the bug** — only bulk events are broken:

| Path | How time is sent | Effect |
|---|---|---|
| Single event (`confirmSingle`) | `el-date-picker` → JS `Date` → Axios JSON-serialises as UTC ISO8601 with `Z` | ✓ Correct |
| Edit event (`ModifyAttendanceEventDialog`) | Same picker → same serialisation | ✓ Correct |
| **Bulk events (`confirmBulk`)** | Naive string `` `${r.date}T${r.startTime}:00` `` (no TZ) | ✗ **Bug** |

**Why naive strings break:** `Time.parse('2026-04-24T09:00:00').utc` on a UTC server (Heroku always runs UTC) interprets the string as UTC and stores `09:00 UTC`. A user in UTC+8 who typed "9am" now sees `17:00`. User's report of events being "much later" is consistent with an eastern timezone.

**Backend already correct:** `Value::TimeRange.parse_time` calls `Time.parse(raw).utc` which correctly handles offset-bearing strings like `2026-04-24T09:00:00+08:00`. No backend changes needed for Slice 1.

**Display already correct:** `formatLocalDateTime` in `frontend_app/lib/dates.js` uses `new Date(utcStr)` — JS automatically converts UTC to browser local time for display.

**Representer already correct:** `event.rb` representer always serialises via `.utc.iso8601`, so the API always returns UTC with `Z` suffix.

**The fix (Slice 1):** In `CreateEventsDialog.vue:294-298` (`confirmBulk`), replace:

```javascript
start_at: `${r.date}T${r.startTime}:00`,
end_at: `${r.date}T${r.endTime}:00`
```

with:

```javascript
start_at: new Date(`${r.date}T${r.startTime}`).toISOString(),
end_at: new Date(`${r.date}T${r.endTime}`).toISOString()
```

`new Date('2026-04-24T09:00:00')` (naive string in browsers) is treated as local time, so `.toISOString()` produces the correct UTC representation.

**Existing production events:** Already stored with wrong timestamps. Need a targeted SQL update. The offset to apply equals the user's browser timezone offset at the time of creation. See Q1.

**Slice 2 (deferred):** Add `courses.timezone` + `events.timezone` string columns (IANA tz name). Store the intended timezone so the UI can label times ("9:00 am JST") and the attendance window check can use the event's tz rather than the server's. Schema migration + data backfill required. Not needed to fix the immediate bug.

## Questions

> Questions must be numbered (Q1, Q2, ...) and crossed off when resolved.

- [x] Q1. **Production repair scope.** ~~What is your browser timezone?~~ **Asia/Taipei (UTC+8).** User will supply the exact event IDs to fix after Slice 1 ships — targeted `UPDATE` with explicit `WHERE id IN (...)`, shift = `- INTERVAL '8 hours'`.
- [x] Q2. **Slice 2 in this branch or defer?** ~~Deferred~~ — Slice 1 is sufficient. Browser-timezone approach handles all current use cases including cross-timezone attendance windows.
- [x] Q3. **Plan lifecycle.** Archive before merge — same convention as `feature-multi-event`.

## Scope

### Slice 1 — Fix the bug (this PR)

**What's in scope:**

- Fix `confirmBulk` in `CreateEventsDialog.vue` to emit UTC ISO8601 (one-line change)
- Add a backend route test proving offset-aware timestamps are stored and round-tripped correctly
- Document + execute the production SQL repair for already-wrong events
- Manual verification of bulk event creation from a non-UTC browser

**What's out of scope:**

- Schema changes — no new columns in Slice 1
- Per-course or per-event timezone column
- Display labels (e.g. "9am JST")
- Attendance window timezone logic
- Single event / edit event forms (already correct, no change needed)

### Slice 2 — Timezone metadata (deferred, pending Q2)

- `courses.timezone` column (IANA tz name, e.g. `Asia/Taipei`)
- `events.timezone` column defaulting to course timezone
- Event creation inherits course tz; picker shows tz label
- Attendance window check uses `events.timezone`
- Display labels everywhere

## Tasks

> **Check tasks off as soon as each one (or each grouped set) is finished** — do not batch completions before updating the plan.
>
> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

### Slice 1

- [x] 1a. Write failing backend test: POST `/api/course/:id/events` with offset-aware timestamps (e.g. `2026-04-24T09:00:00+08:00`) returns `start_at` as `2026-04-24T01:00:00Z` — verifying the round-trip is correct. Add to `spec/routes/event_route_spec.rb`.
- [x] 1b. Confirm test passes (backend already handles this — test should go green immediately, but we write it to lock in the contract). ✓ 20/20 route tests pass.
- [x] 2. Fix `CreateEventsDialog.vue:297-298` — change naive string construction to `new Date(...).toISOString()`.
- [x] 3. Resolve Q1 and run targeted SQL repair on production events with wrong timestamps. ✓ Events 591–597 shifted back 8 hours via `Tyto::Api.db.run(...)`.
- [x] 4. Manual verification: confirmed correct in production — events 591–597 repaired and new events created correctly.

### Slice 2 (pending Q2 decision)

- [ ] S2.1a Write failing migration test for `courses.timezone` column
- [ ] S2.1b Write failing migration test for `events.timezone` column
- [ ] S2.2 Migration: add `courses.timezone` (varchar, nullable) + `events.timezone` (varchar, nullable, defaults to course tz)
- [ ] S2.3 Update Course and Event ORM models
- [ ] S2.4 Update Course and Event domain entities + representers
- [ ] S2.5 Event creation service: inherit course timezone, allow per-event override
- [ ] S2.6 Frontend: show tz label on event cards; add tz picker on create form
- [ ] S2.7 Attendance policy: use `event.timezone` for window check

## Manual test feedback

> Captured during in-browser / staging verification. Each item: observation → fix direction → decision → status.

(none yet)

## Completed

(none yet)

---

Last updated: 2026-04-24
