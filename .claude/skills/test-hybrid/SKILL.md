---
name: test-hybrid
description: Frontend testing for web apps. Analyze branch changes, generate a test plan for the web UI, execute it via Chrome browser automation, and capture review notes for the developer.
---

# Hybrid Frontend Test Skill

Test the **frontend (web UI)** of a web application by planning test scenarios from the branch diff, executing them via Chrome browser automation, and producing a review-notes summary for the developer.

This skill tests what users see and interact with in the browser — pages, components, forms, dialogs, navigation, and visual state. It does **not** test backend logic directly (that's what unit/integration tests are for). It verifies that the frontend correctly consumes the backend API and renders the expected UI.

## Usage

```
/test-hybrid [<scope>]
```

- `/test-hybrid` — test all frontend/UI changes on the current branch
- `/test-hybrid slice-1` — test only the named scope (matches a section heading or tag in the branch plan)

## Prerequisites

- A running backend and frontend (or instructions in the branch plan for how to start them)
- Chrome browser with the Claude-in-Chrome extension connected
- A seeded development database with test data (users, courses, etc.)

If servers are not running, offer to start them for the user before proceeding.

## Instructions for Claude

### Phase 1: Discover what to test

1. **Read the branch plan** (`CLAUDE.*.md` referenced in `CLAUDE.local.md`) to understand the feature, its scope, and which tasks are marked complete.
2. **Identify frontend changes**: Read the frontend files that were added or modified. Focus on:
   - New routes / navigation entries (router config)
   - New or modified page components and dialogs
   - User-facing actions wired to UI elements (create, edit, delete, publish, view, etc.)
   - Data displayed in the browser (lists, detail views, status indicators, formatted dates, rendered content)
3. **Identify the API surface the frontend consumes**: Read API routes, serializers, or schema definitions to understand endpoint paths, request shapes, and response fields — only enough to know what the UI should display.
4. **Check for design decisions** that affect frontend behavior (e.g., frozen fields after a lifecycle transition, role-based visibility, confirmation dialogs).

### Phase 2: Build a test plan

Produce a numbered test plan covering these categories (skip categories with no applicable scenarios):

| Category | What to verify |
|----------|---------------|
| **Navigation** | New tabs/routes/links appear in the UI, page transitions work, no regression on existing navigation |
| **CRUD flows** | Create → item appears in list; Edit → changes reflected; Delete → item removed (with confirmation dialog) |
| **Lifecycle / state transitions** | Status changes (e.g., draft → published) update badges, available actions, and frozen fields in the UI |
| **Detail views** | All fields render correctly in the browser (dates formatted, markdown rendered, nested data in tables, linked references resolved) |
| **Form validation & edge cases** | Required fields enforced in forms, empty states handled, confirmation dialogs shown for destructive/irreversible actions |
| **Role-based UI** | Different roles see appropriate content and actions (if testable with available accounts) |
| **Regression** | Existing pages/components on the same screen still work after the changes |

Keep the plan concise — one line per test scenario. Group by category. Example:

```
## Test Plan

### Navigation
1. Assignments tab visible in course sidebar
2. Click Assignments tab → AssignmentsCard loads
3. Switch to other tabs and back → no errors

### CRUD: Assignments
4. Click Create Assignment → dialog opens with all fields
5. Fill form with requirements → submit → card appears with correct title, status, due date
6. Click edit icon → dialog pre-populated with current values
7. Modify title → save → card reflects new title
8. Click delete icon → confirmation dialog → confirm → card removed

### Lifecycle
9. Click publish on draft → confirmation dialog warns about frozen requirements → confirm → status badge changes to "published"
10. Published assignment: publish icon no longer shown

### Detail View
11. Click assignment card → detail dialog shows rendered markdown, requirements table, linked event name, late resubmit policy

### Regression
12. Switch to Attendance Events tab → still loads correctly
13. Switch to Locations tab → still loads correctly
14. Switch to People tab → still loads correctly
```

Present the test plan to the user before executing. If the user has feedback, revise before proceeding.

### Phase 3: Execute tests

For each test scenario:

1. **Start with `tabs_context_mcp`** to get current browser state. Create a new tab if needed.
2. **Navigate** to the starting page if not already there.
3. **Execute the action**: use `read_page` to find interactive elements, then `computer` (click, type, etc.) to interact.
4. **Verify the result**: take a screenshot and/or read the page to confirm the expected outcome.
5. **Record the result**: pass, fail, or note (unexpected behavior worth flagging but not a blocker).

Execution guidelines:

- **Screenshot at key moments**: after page loads, after form submission, after state transitions, after deletions. These serve as evidence for the developer's manual review.
- **Wait briefly after actions** (0.5–1s) that trigger API calls before verifying results.
- **If a test fails**: note the failure, take a screenshot of the broken state, and continue with remaining tests. Do not stop the entire run.
- **If the browser becomes unresponsive** (e.g., modal dialog triggered): inform the user and pause. Do not retry more than twice.
- **Collect review notes as you go**: anything surprising, inconsistent, or worth the developer's attention — even if not strictly a bug. Examples: misleading wording, missing loading states, confusing UX, design decisions that might need revisiting.

### Phase 4: Report results and update plan

1. **Produce a results summary** in the conversation:

```
## Hybrid Test Results

### Passed
- [1] Assignments tab visible ✓
- [2] Tab navigation works ✓
...

### Failed
- [N] [description]: [what happened vs. what was expected]

### Review Notes
- [observation]: [context and suggestion]
```

2. **Update the branch plan** (`CLAUDE.*.md`):
   - Mark the verification task as complete (or partially complete if failures exist).
   - Add a **Review Notes** section (or append to an existing one) with items the developer should consider. Include:
     - Design questions surfaced during testing
     - UX inconsistencies or confusing wording
     - Bugs found and whether they were fixed during the run
     - Any workarounds applied (e.g., missing `require` statements)
   - Update the `Last updated` line.

3. **Do not auto-fix issues** unless they are clearly bugs that block testing (e.g., a missing require that crashes the server). For design questions and UX concerns, document them in review notes for the developer to decide.

4. **Add a follow-up task to the branch plan**: Insert a checklist item after the verification task for the developer to resolve review notes before moving on. Example:

```
- [x] 1.11 Hybrid verification: Chrome walkthrough of assignment flows (see review notes)
- [ ] 1.12 Resolve review notes from hybrid verification
```

This ensures review notes are not forgotten — they become a tracked task that must be checked off before the slice is considered complete.

## Principles

- **Developer has final say**: This is a hybrid process — automation provides thoroughness, the developer provides judgment. Always surface findings as review notes, never silently "fix" design decisions.
- **Test the feature, not the implementation**: Verify what users see and do, not internal code paths. If a button should be hidden after a state transition, verify it's hidden — don't inspect the Vue component's data.
- **Regression is not optional**: Always check that existing features on the same page still work. Tab switching, navigation, and shared UI elements are common regression points.
- **Keep review notes actionable**: Each note should state what was observed and suggest what to consider. Avoid vague "this seems wrong" — explain the tension (e.g., "dialog says X but design doc says Y").
- **Capture evidence**: Screenshots at failure points and key state transitions help the developer during their manual pass.
