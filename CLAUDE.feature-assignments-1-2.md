# Feature: Assignments and Submissions

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`feature-assignments`

## Goal

Allow teaching staff to create assignments (with description, due date, submission requirements) for a course, and students to submit solutions (file upload or URL).

## Strategy: Vertical Slice

Deliver a complete, testable feature end-to-end:

1. **Backend test** — Write failing test for new behavior (red)
2. **Backend implementation** — Make the test pass (green)
3. **Frontend update** — Build UI to consume new API
4. **Verify** — Hybrid: Claude-in-Chrome walkthrough + manual pass by developer before merge

> **Meta-review note**: Track pain points encountered during hybrid testing (flakiness, missed regressions, re-verification cost, edge cases discovered late, etc.) in a section below. After Slice 2, use these observations to decide whether to invest in automated interface acceptance tests (e.g., Playwright/Capybara) before merging to main.

## Reference Documents

| Document | Contents | Status |
|----------|----------|--------|
| `CLAUDE.assignments-ddd-architecture.md` | Aggregate roots, entities, value objects, DB schemas, domain rules, repository patterns, direct-to-S3 presigned URL storage design | Reviewed — all review items (R1–R10) resolved and moved to design decisions doc |
| `CLAUDE.assignments-design-decisions.md` | All resolved design questions (Q1–Q12) and architecture review decisions (R1–R10) | Reviewed |

## Current State

- [x] Plan created
- [x] Design questions resolved (see design decisions doc)
- [x] Domain model defined (see domain model doc)
- [x] File storage strategy decided: direct-to-S3 via presigned URLs (see domain model doc)
- [x] **Architecture review complete** — R1–R10 resolved, decisions in design decisions doc
- [x] **Scope and tasks updated to reflect domain model** — reconciled with design decisions (R1–R10) on 2026-03-03
- [x] Slice 1: Assignments backend (domain, infrastructure, application, presentation — 983 tests passing)
- [x] Slice 1: Assignments frontend (tab, list, create/edit dialogs, detail view — build compiles)
- [x] Slice 1: Assignments verification (Chrome walkthrough complete — see review notes below)
- [x] Slice 2: Submissions backend (domain, infrastructure, application, presentation, routes, policy predicates)
- [x] Slice 2: Submissions frontend (submission form, own-view, teaching staff list — build compiles)
- [x] **Merge of `origin/main`** (47 commits absorbed: policy namespace refactor, multi-event + attendance management features, events schema invariants, timezone fixes, content-hashed prod bundles). Post-merge adaptation: policies renamed to `Policy::Assignment`/`Policy::Submission`, migrations renumbered 012–015, 1166 tests / 0 failures / 98.27% cov. See Merge Log below.
- [x] Slice 2: Submissions verification (task 2.9) — Claude-in-Chrome walkthrough complete. Flows A/B/C/D/F + backend of E pass; bugs/gaps found in G, frontend of E, and event-linkage. See Slice 2 Review Log.
- [x] Slice 2: Review fixes (tasks 2.10a–2.10e) — all five done. Ready for branch squash + PR to main, pending any final manual regression.
- [ ] Slice 3: Production S3 infrastructure (gateway, config, docs)

## Key Findings

### Existing Architecture

The codebase has four bounded contexts: **Accounts**, **Courses**, **Attendance**, **Shared**. The pattern for adding a new feature is well-established:

- **Domain**: entities (dry-struct), values, policies under `app/domain/<context>/`
- **Infrastructure**: ORM models (Sequel) + repositories that map ORM ↔ domain entities
- **Application**: services (Dry::Operation with monadic results), policies (authorization), routes (Roda)
- **Presentation**: Roar representers for JSON serialization
- **Tests**: Minitest spec-style, organized by layer

### Relevant Existing Pieces

- **Course enrollment system**: `account_course_roles` join table supports multiple roles (owner, instructor, staff, student) per account per course
- **CoursePolicy**: Existing pattern for role-based authorization (`can_view?`, `can_update?`, etc.)
- **Courses repository**: Demonstrates composable loading strategies (`find_with_events`, `find_full`, etc.)
- **Routes**: Currently singular (`/api/course/:course_id/`) — new routes will use plural convention (issue #46)
- **Domain types**: `types.rb` has constrained types and string enums for roles
- **FileUpload.vue**: A file upload component already exists in the frontend

## Scope

### In Scope

**Backend changes**:

- New `assignments` bounded context in domain layer
- Assignment aggregate root with SubmissionRequirement child entities
- Submission aggregate root with RequirementUpload child entities
- Domain types: AssignmentTitle, AssignmentStatus (draft/published/disabled), RequirementType (file/url)
- Draft/published/disabled lifecycle for assignments
- Database migrations for 4 tables: assignments, submission_requirements, submissions, submission_entries
- ORM models and repositories with composable loading
- Services: CreateAssignment, UpdateAssignment, DeleteAssignment, PublishAssignment, ListAssignments, GetAssignment, CreateSubmission, ListSubmissions, GetSubmission
- Policies: `Policy::Assignment` (teaching staff CRUD; students view published only), `Policy::Submission` (students create/view own; teaching staff view all)
- Routes nested under `/api/course/:course_id/assignments/` (singular `course` matches current codebase; issue #46 will rename to plural later)
- Representers for Assignment and Submission JSON
- S3 file upload with storage abstraction (local adapter for dev/test)
- Input validation (contracts or inline)
- Late resubmit policy enforcement (`allow_late_resubmit` flag)

**Frontend changes**:

- Assignment list view (within course detail page)
- Assignment detail view (rendered markdown description, due date, linked event, submission requirements)
- Assignment creation/edit dialog (teaching staff): title, markdown description, due date, optional event, submission requirements, publish action
- Submission form per requirement (file upload or URL input)
- Submission list view (teaching staff: all students; students: own only)

### Out of Scope (deferred)

- Grading, scores, rubrics, feedback
- Submission file versioning / history
- Bulk assignment operations
- Assignment categories/tags
- Notifications (email/push) for new assignments or approaching deadlines
- Peer review (students viewing each other's submissions)

## Tasks

> **TDD HARD GATE — NON-NEGOTIABLE**
>
> Every backend task that touches implementation code MUST follow this sequence. There are NO exceptions — not for "small" changes, not for "obvious" additions, not for ad-hoc fixes discovered during review.
>
> 1. **Write test file(s) ONLY** — reference classes/methods that do not exist yet.
> 2. **Run `bundle exec rake spec`** — confirm failures. Record `red: NF` on the task line. **STOP. Do not proceed until this line is recorded.**
> 3. **Only then** open implementation files for editing.
> 4. **Run tests again** — confirm green. Record `green: NP, total T` on the task line.
>
> **The red run is the gate.** If you have not recorded a red run with failure count, you are not permitted to write implementation code. This applies to every task marked with 🚦 below.
>
> **Why this keeps failing**: The implementation shape is often clear before tests are written, creating a pull to "just do it all at once." That impulse must be overridden by procedure. The red run is proof that tests were written first — without it, there is no proof.

### Slice 1: Assignments (create, list, view, update, delete, publish — end-to-end)

**Backend test (red)**:

- [x] 1.1a Failing tests for Assignment entity, SubmissionRequirement entity, and value objects
- [x] 1.1b Failing tests for Assignment repository (including requirements loading, event loading)
- [x] 1.1c Failing tests for Assignment services (create, list, get, update, delete, publish — including submission requirements and optional event_id)
- [x] 1.1d Failing tests for Assignment policy (authorization, draft/published visibility)
- [x] 1.1e Failing tests for Assignment routes

**Backend implementation (green)**:

- [x] 1.2 Domain: Assignment entity, SubmissionRequirement entity, types, collection value objects
- [x] 1.3 Infrastructure: migrations (assignments + submission_requirements), ORM models, repository
- [x] 1.4 Application: services (CRUD + publish, with requirements management), policy, routes
- [x] 1.5 Presentation: Assignment representer (including nested requirements)
- [x] 1.6 All backend tests pass (983 tests, 0 failures, 98.31% coverage)

**🔍 REVIEW CHECKPOINT**: Pause for developer review of Slice 1 backend (domain, infrastructure, application, presentation). All backend tests should pass. Resume with frontend after review.

**Frontend**:

- [x] 1.7 Add assignments tab/route to course detail page
- [x] 1.8 Assignment list component (draft/published indicators for teaching staff)
- [x] 1.9 Create/edit assignment dialog with submission requirements builder
- [x] 1.10 Assignment detail view (rendered markdown, linked event, requirements list)

**Verify**:

- [x] 1.11 Hybrid verification: Chrome walkthrough of assignment flows (see review notes)
- [ ] 1.12 Resolve review notes from hybrid verification (see below)

**Review fixes (from 1.11 + developer review)**:

- [x] 1.12a Fix: Create Assignment card font/appearance larger than Create Event card — added `font-size: 14px`, `line-height: 2.5rem`, `text-align: center` to `.assignment-item` CSS (matching global `.event-item` style)
- [x] 1.12b Fix: "Late Resubmit" label → "Allow Late Resubmits?" in CreateAssignmentDialog + ModifyAssignmentDialog
- [x] 1.12c Issue: Date pickers don't show user's timezone — created GitHub issue #47 (cross-cutting, deferred)
- [x] 1.12d Fix: "+ Add Requirement" button disabled when empty requirement row exists (prevents adding blank rows)
- [ ] 1.12e Deferred: Sanitize markdown in AssignmentDetailDialog (DOMPurify) — add after Slice 2 (may apply to submissions too)

**Slice 1 extension — Draft requirements editing + Unpublish lifecycle**:

Resolves review note #1: requirements should be editable in draft mode, and published assignments with no submissions can be unpublished back to draft.

New lifecycle rules:
- **Draft**: full editing (metadata + requirements), can publish, can delete
- **Published (no submissions)**: can edit metadata, can unpublish back to draft, can delete
- **Published (with submissions)**: metadata only, no unpublish, no delete (use disable) — enforced when Slice 2 adds submissions

**Backend**:

- [x] 1.13a Policy: `can_unpublish?` method + summary hash already existed; added test coverage
- [x] 1.13b Repository: add `update_with_requirements` method (delete-and-replace) + 3 tests
- [x] 1.13c New service: `UnpublishAssignment` (published → draft, with `has_submissions?` placeholder for Slice 2) + 5 tests
- [x] 1.13d Update service: `UpdateAssignment` accepts optional `submission_requirements` (allow if draft, reject if published) + 2 tests
- [x] 1.13e Routes: add `POST .../unpublish` endpoint + 3 tests; add requirements update route tests + 2 tests
- [x] 1.13f All backend tests pass (998 tests, 0 failures, 98.32% coverage)

**Frontend**:

- [x] 1.14a `ModifyAssignmentDialog`: requirements builder for draft assignments; info alert for published
- [x] 1.14b `SingleCourse`: async fetch `editAssignment` (gets requirements); `unpublishAssignment` handler + event wiring; `currentAssignmentStatus` tracking
- [x] 1.14c `AssignmentsCard`: unpublish icon (Bottom) for published assignments + `unpublish-assignment` emit

**Verify**:

- [x] 1.15 Chrome walkthrough: create draft → edit requirements → publish → unpublish → edit requirements → republish (all 16 tests passed — see review notes)

### Slice 2: Submissions (create, view, overwrite — end-to-end)

**Backend** (2.1–2.3 were test+implementation combined — not true red-green. Strict test-first resumed at 2.4.):

- [x] 2.1 Domain: Submission entity, RequirementUpload entity, RequirementUploads collection VO + tests (33 new tests) *(combined — TDD violation)*
- [x] 2.2 Infrastructure: migrations (011, 012 — renumbered to 014, 015 after merge), ORM models (Submission, SubmissionEntry), repository (composable loading, create, upsert_entries, delete) + tests (30 new tests) *(combined — TDD violation)*
- [x] 2.3 Application: services (CreateSubmission with late resubmit enforcement + file validation, ListSubmissions, GetSubmission) + policy (students submit/view own, teaching staff view all) + tests (34 new tests) *(combined — TDD violation)*
- [x] 2.4 Routes + Presentation: Submission routes (nested under assignments), Submission representer (including nested RequirementUploadRepr) + SubmissionsList collection wrapper — red: 13F, green: 15P. CreateSubmission changed from `ok` to `created` (201 status). File extension validation is case-insensitive.
- [x] 2.5 All backend tests pass (1111 tests, 0 failures, 98.49% coverage)

File storage (LocalGateway, Mapper, storage abstraction) moved to Slice 3 — not needed until presigned URL upload flow is wired up.

**🔍 REVIEW CHECKPOINT**: Pause for developer review of Slice 2 backend (domain, infrastructure, application, presentation). All backend tests should pass. Resume with frontend after review.

**Policy predicates for frontend** (review fix — added during Slice 2 review):

- [x] 2.5a PolicyWrapper (SimpleDelegator), `Policy::Assignment#can_submit?`, representer + service wiring, 10 new tests *(TDD violation — tests and implementation written together)*
- [x] 2.5b All backend tests pass (1121 tests, 0 failures, 98.5% coverage)

**Frontend**:

- [x] 2.6 Submission form on assignment detail (per-requirement: URL input; file-type disabled with info note). Gated by `assignment.policies.can_submit`. Students see Assignments tab via restructured SingleCourse layout.
- [x] 2.7 Student's own submission view (with resubmit capability, prefilled URL values, late indicator)
- [x] 2.8 Teaching staff submissions list (all students, late indicators, entry counts). Gated by `submission.policies.can_view_all` or `assignment.policies.can_update`.

**Verify**:

- [x] 2.9 Hybrid verification: Chrome walkthrough of submission flows — **passes: Flows A, B, C, D, F (backend enforcement); partial/findings: Flows E, G, event-linkage regression**. Bugs + UX gaps logged below (Slice 2 Review Log). Follow-up tasks 2.10a–2.10e created.

### Slice 3: File Storage Infrastructure (Local + S3)

> **TDD record**: Slices 1–2 had repeated lapses where tests and implementation were written together. Every task below marked 🚦 requires the red-green gate sequence. No exceptions.

> **Design for future reuse — staff/instructor course materials feature** (2026-04-24): A planned follow-up feature will let instructors/staff upload files attached to courses, weeks (events), or assignments, with visibility rules (public-to-members vs. staff/instructor-only). That feature is **not** in this branch, but it will share this storage infrastructure. Design Slice 3 with that in mind:
>
> - **Gateway + LocalGateway**: keep them generic (`presign_upload(key, constraints)`, `presign_download(key)`, `head(key)`, `delete(key)`). No submission-specific vocabulary. Both features call the same gateway.
> - **Mapper**: the submission-specific key pattern `<assignment_id>/<requirement_id>/<account_id>.<ext>` belongs in a *submission mapper* (or in the submissions repository), not in the generic storage layer. The future course-materials feature will want a different key pattern (e.g., `course/<course_id>/materials/<material_id>.<ext>`). Draw the seam cleanly so course-materials can add its own mapper without touching the gateway.
> - **Constraints encoding** (max size, allowed extensions → presigned POST conditions) is generic and belongs in the shared mapper layer or as a reusable helper.
> - **Gateway selection**: environment-based selection logic should be shared (one selector, not per-feature).
> - **File listing/visibility**: out of scope for Slice 3 — that's a domain concern of the future feature. But do not bake submission-shaped assumptions (overwrite model, one-per-student) into the storage layer.
>
> The goal is: when the course-materials branch starts, it should be able to `require` the gateway + shared constraints helpers and add only its own mapper + domain/repository layer. No rework of Slice 3 expected.

**Backend test (red)** — write tests ONLY, run, record failures:

- [ ] 🚦 3.1a Failing tests for Mapper: S3 key construction from IDs + extension, constraint encoding (max size, allowed extensions), `.url` file content generation → `spec/infrastructure/file_storage/mapper_spec.rb` — **red: ___F** ← record before proceeding to 3.2
- [ ] 🚦 3.1b Failing tests for LocalGateway: filesystem round-trip (presign_upload → upload → head → presign_download → download → delete), error cases (missing key, invalid path) → `spec/infrastructure/file_storage/local_gateway_spec.rb` — **red: ___F** ← record before proceeding to 3.3
- [ ] 🚦 3.1c Failing tests for Gateway: mocked `aws-sdk-s3` (presign_upload, presign_download, head, delete), error handling (S3 errors → Failure monads) → `spec/infrastructure/file_storage/gateway_spec.rb` — **red: ___F** ← record before proceeding to 3.5
- [ ] 🚦 3.1d Failing tests for environment-based gateway selection (dev/test → LocalGateway, production → Gateway) → `spec/infrastructure/file_storage/gateway_selection_spec.rb` — **red: ___F** ← record before proceeding to 3.6

**Backend implementation (green)** — BLOCKED until corresponding red run is recorded above:

- [ ] 🚦 3.2 Mapper → `infrastructure/file_storage/mapper.rb` — **BLOCKED by 3.1a red run** — **green: ___P, total ___**
- [ ] 🚦 3.3 LocalGateway → `infrastructure/file_storage/local_gateway.rb` — **BLOCKED by 3.1b red run** — **green: ___P, total ___**
- [ ] 3.4 Add `aws-sdk-s3` gem; S3 config entries in secrets.yml template *(no gate — config only)*
- [ ] 🚦 3.5 Gateway → `infrastructure/file_storage/gateway.rb` — **BLOCKED by 3.1c red run** — **green: ___P, total ___**
- [ ] 🚦 3.6 Environment-based gateway selection logic — **BLOCKED by 3.1d red run** — **green: ___P, total ___**
- [ ] 3.7 All tests pass (including Slice 1 and 2 regression)

**Setup guide** (no code):

- [ ] 3.8 Guided walkthrough: AWS S3 bucket creation, IAM policy, CORS config, credentials in secrets.yml

## Completed (Slice 1)

| Task | Summary | Tests |
|------|---------|-------|
| 1.1a–1.2 | Domain: Assignment + SubmissionRequirement entities, collection VO, types | 43 |
| 1.1b, 1.3 | Infrastructure: migrations, ORM models, repository with composable loading | 27 |
| 1.1d, 1.4 | Policy: role-based authorization (teaching staff CRUD, students view published) | 12 |
| 1.1c, 1.4 | Services: Create, List, Get, Update, Delete, Publish | 25 |
| 1.5 | Presentation: Assignment + SubmissionRequirement representers | — |
| 1.1e, 1.4 | Routes: full CRUD + publish under `/api/course/:course_id/assignments` | 18 |
| 1.6 | Full regression pass | 983 (98.31% cov) |
| 1.7–1.10 | Frontend: AssignmentsCard, Create/Modify/Detail dialogs, SingleCourse wiring | build clean |
| 1.11 | Chrome walkthrough verification (all flows + tab regression) | — |
| 1.13a–f | Extension backend: unpublish service, update-with-requirements, policy/route tests | 998 (98.32% cov) |
| 1.14a–c | Extension frontend: draft requirements builder, unpublish handler | build clean |
| 1.15 | Extension Chrome walkthrough (16 test steps, all passed) | — |

## Review Log (Slice 1)

**Resolved**: publish dialog wording (1.12a), `require 'ostruct'` Ruby 3.4 fix, card sizing matched to events, "Late Resubmit" → "Allow Late Resubmits?", "+ Add Requirement" disabled when empty row exists, publish confirmation mentions unpublish option.

**Deferred**:
- **Timezone display**: GitHub issue #47 (cross-cutting UX improvement). Main has since merged a `feature-timezone` PR (`bb9dd9d`, `9cf05b1`) that fixes browser-timezone handling for **bulk events**. Verify whether assignment due-date pickers benefit from that fix or still need work before closing #47.
- **Markdown sanitization** (1.12e): `v-html` + `marked` in AssignmentDetailDialog — add DOMPurify after Slice 2 (may apply to submissions too)

## Slice 2 Review Log (task 2.9 hybrid verification, 2026-04-24)

Test setup: fresh `db:reset` (branch had not yet run the renumbered migrations 012–015 against dev, so the first server start failed with "no such table: submissions" — resolved by `rake db:reset` after confirming with user). Two Google accounts used: admin/creator (owner of the course) and a second account enrolled as `student`.

### Flows verified — pass

| Flow | Scenario | Result |
|------|----------|--------|
| A | Student first-time submit URL, before deadline | PASS — "Your Submission" panel with timestamp, URL as link, no late indicator |
| B | Student resubmits before deadline | PASS — timestamp advances, URL replaces previous value (R3 upsert) |
| C | Staff views all submissions | PASS — "All Submissions (1)" table with Student ID / Submitted / Status / Entries. See findings 2.10d |
| D | Student first-time submit, past deadline | PASS — accepted per rule #3, red "Late" pill shown |
| F | Student resubmit, past deadline, `allow_late_resubmit=true` | PASS — resubmit accepted, timestamp advanced, Late indicator persists |

### Flows with bugs / gaps

**2.10a — BUG: `can_unpublish?` placeholder never wired up (Flow G)**

On Week 1 Report (which had a student submission), the instructor clicked Unpublish → succeeded. The assignment flipped from published → draft, hiding it from the student while their submission still exists in the DB. Per the Slice 1 extension rule ("Published with submissions: no unpublish, no delete, use disable"), this should have been blocked. Root cause is Slice 1 task 1.13c's note: "has_submissions? placeholder for Slice 2" — the placeholder was never replaced with a real check against the submissions repository now that Slice 2 created real submissions. The policy method `Policy::Assignment#can_unpublish?` always returns true for appropriately-roled users.

Additionally: the Modify Assignment dialog for published-with-submissions correctly locks the requirements section but its info message still advises "unpublish the assignment first" — actively misleading once the unpublish path is blocked.

Delete icon (trash) is also still visible on published-with-submissions cards. Not clicked (destructive); very likely has the same gap.

Fix scope: (1) wire `Policy::Assignment#can_unpublish?` / `can_delete?` to check submissions count via the repository; (2) `AssignmentsCard.vue` should hide the unpublish/delete icons when `assignment.policies.can_unpublish === false` / `can_delete === false`; (3) update the Modify dialog info message to branch on whether submissions exist.

**2.10b — UX GAP: Late resubmit blocked silently (Flow E)**

On `Past Due (no late resubmit)` with an existing submission, the student saw an enabled Resubmit button; clicking it opened the pre-filled edit form; submitting the change produced an `AxiosError` in the console and the form silently closed back to the previous read-only state. The backend correctly enforced R6 (existing submission stayed at v1, not v2-BLOCKED), but the student received zero feedback. Two UX fixes wanted: (1) frontend should hide / disable the Resubmit button when `allow_late_resubmit=false` AND `now > due_at` AND submission exists; (2) when the API does return an error, show an Element-Plus error toast with the reason.

**2.10c — GAP: Assignment detail view does not render linked event (Flow #9 regression)**

Directly setting `assignments.event_id = 1` via SQL (bypassing the broken event-creation UI from main — see 2.10e) was accepted by the DB. The assignment detail dialog afterward showed title, description, requirements, submissions list, and all else — but no "Linked Event" field anywhere. Slice 1 task 1.10 promised "linked event" in the detail view. Either Slice 1 silently skipped it, or the Assignment representer (likely needs updating post-merge since main's events schema changed) stopped exposing the event data. Needs investigation: check if `AssignmentRepresenter` exposes any event info, check if `AssignmentsRepository#find_with_requirements` eagerly loads the event.

**2.10d — UX GAP: Staff submissions list lacks student identity and content preview**

Flow C's "All Submissions (1)" table shows `Student ID` as the raw numeric `account_id` (e.g., "2"), not a name or email. Teaching staff can't tell which student submitted without cross-referencing. Additionally, the table gives no way to drill into a submission to see the submitted URL content. Both likely deferred for Slice 2 scope but worth fixing for usability: (1) representer/service should join/return account name; (2) table rows should be clickable to open a submission-detail dialog.

**2.10e — UX GAP: No "you are submitting late" warning before submit**

When a student opens a past-due assignment with no existing submission (Flow D setup), the only indication that the deadline has passed is that the due-date string is in the past. There is no prominent warning. Students could submit without realizing they're late. A pre-submit banner (e.g., "This assignment is past its due date. Your submission will be marked late.") would avoid surprises.

### Out-of-scope / pre-existing issues (main, not Slice 2)

These were encountered during verification but trace to main's merged attendance/events feature, not Slice 2. Logging them for awareness; should not block Slice 2 merge.

- **Locations UI silently failed to persist**: clicking "Save Location" appeared successful but `locations` table remained at 0 rows. Event creation (which requires a location) therefore couldn't be completed via the UI. Worked around by inserting event directly via SQL for the event_id regression test.
- **Student view of `/course/:id/attendance`**: even though the sidebar hides the Attendance Events link for students, the URL route still renders the "Create Event" / "Download Record" UI for them (visible but not reachable from nav). Defense-in-depth issue with main's role gating.
- **Stale names in `SingleCourse.vue`**: `showCreateAttendanceEventDialog` + `createAttendanceEvents` method names were preserved through the merge but now drive `CreateEventsDialog` (bulk). Rename opportunity flagged in merge log.

### Meta-review — are Playwright/Capybara tests warranted?

Hybrid testing cost for 2.9 was high: two manual account switches, four separate recording runs, and a `db:reset` to recover from a dev-DB mismatch after the merge. Two of the bugs (2.10a, 2.10b) would have been caught by a reasonably-simple Capybara test because they exercise backend enforcement where the HTTP response tells the story. A third (2.10c) would also have been catchable by checking the assignment detail JSON/HTML for the event field. The non-backend UX items (2.10d, 2.10e) are subjective and would need manual review anyway.

Recommendation: before adding Playwright/Capybara, **write backend integration tests** for each of 2.10a–2.10c (the hard bugs) and ensure they fail, then fix. The tests are cheap and high-signal. Leave the Playwright/Capybara decision for after Slice 3 once we've seen how file-upload flows behave end-to-end.

## Slice 2 Follow-up Tasks (created from 2.9 review — must be closed before PR to main)

- [x] 2.10a Fix `Policy::Assignment#can_unpublish?` / `can_delete?` to query the submissions repository (not the Slice 1 placeholder). **red: 17F (13 errors + 4 failures) — green: 1184P / 0 failures / 0 errors / 1 skip, 98.29% cov.** Tests written first across 4 files (policy, repo, 4 service specs); implementation then: (1) `Repository::Submissions#any_for_assignment?` + `#assignment_ids_with_submissions(ids)` (one batched query for the list path, no N+1); (2) `Policy::Assignment.new(requestor, enrollment, has_submissions: false)` — `can_unpublish?` / `can_delete?` now AND with `!has_submissions`; (3) `UnpublishAssignment` / `DeleteAssignment` do a role-only pre-check (avoids leaking existence to students), load the assignment, query submissions, then re-check via policy with `has_submissions:` — failures return `:forbidden`. Placeholder `has_submissions?` private method removed from `UnpublishAssignment`; (4) `GetAssignment` and `ListAssignments` emit per-assignment submission-aware policy summaries so the frontend gates correctly. Frontend: `AssignmentsCard.vue` hides unpublish/delete icons via `canUnpublish(a)` / `canDelete(a)` helpers that treat missing `policies` as permissive but explicit `false` as denial. `ModifyAssignmentDialog.vue` accepts a `canUnpublish` prop; when `false`, the info alert switches from "unpublish first" to "requirements are locked because this assignment has submissions — create a new assignment instead". `SingleCourse.vue` threads `assignment.policies.can_unpublish` from `editAssignment` into `currentAssignmentCanUnpublish`. `npm run prod` clean.
- [x] 2.10b Hide/disable Resubmit button when late-resubmit is disallowed and submission exists. Show Element-Plus error toast when submission API rejects. **Frontend-only, no new tests.** Changes: (1) `AssignmentDetailDialog.vue` adds `isPastDue` and `canResubmit` computeds — Resubmit button hidden when `mySubmission && !allow_late_resubmit && past_due`; a replacement info alert explains "The due date has passed and late resubmission is not allowed — your submission is final"; (2) `submitEntries` no longer closes the form optimistically — it sets `submitting=true`, emits, and relies on a `submissions` prop change (success) or a `submissionErrorNonce` prop bump (failure) to clear the in-flight state; (3) Submit/Cancel buttons show loading + disabled while `submitting`; (4) `SingleCourse.vue` `createSubmission.catch` now reads `data.details || data.error || 'Error submitting'` (previously read non-existent `.message` → always generic fallback), and bumps `submissionErrorNonce` to signal the dialog. Verified: `canResubmit` JS-replayed against the three live course-1 assignments gives the correct per-row result; error body shape confirmed `{error, details}` so the new toast wording works; admin-side detail-dialog regression clean (Description / Submission Requirements / All Submissions table still render). Student-side visual (Resubmit hidden + toast shows details) requires Google login — walkthrough steps in Slice 2 Review Log addendum below.
- [x] 2.10c Add linked event rendering to Assignment detail dialog. **red: 11F — green: 1195P / 0 failures / 0 errors / 1 skip, 98.29% cov.** Root cause: frontend's `linkedEventName` computed cross-referenced `attendanceEvents`, which is only populated for teaching staff (`fetchAttendanceEvents` is gated by `can_update`), so students always saw nothing. Fix: embed a minimal event summary on the assignment response itself so the detail view is self-sufficient. Changes: (1) New `Domain::Assignments::Values::LinkedEvent` value object (id, name, start_at, end_at) — lives in the Assignments context to avoid cross-context entity coupling; (2) Assignment entity gains optional `linked_event` attribute (nil when not loaded OR no event); (3) `Repository::Assignments#find_full(id)` loads requirements + event in one convention-consistent method; private `rebuild_entity` now takes a `load_event:` kwarg and `rebuild_linked_event` fetches and maps; (4) `GetAssignment` uses `find_full` instead of `find_with_requirements` — `CreateSubmission` keeps the lighter `find_with_requirements` since it doesn't need event data; (5) `Representer::Assignment` serializes a nested `linked_event` via new `LinkedEventRepr` (id, name, ISO-8601 start_at/end_at); (6) Frontend `AssignmentDetailDialog.vue` renames `linkedEventName` → `linkedEventSummary`, prefers `assignment.linked_event` (authoritative) and falls back to the `attendanceEvents` lookup; now shows name + formatted local start_at. Verified via Chrome student session: Past Due (allow late resubmit) shows "Linked Event — Lecture Week 1 — 2026-04-28 18:00"; Past Due (no late resubmit) correctly omits the section.
- [x] 2.10d Staff submissions table: replace numeric Student ID with account name/email; add click-to-view-submission detail. **red: 10F — green: 1205P / 0 failures / 0 errors / 1 skip, 98.31% cov.** Changes: (1) New `Domain::Assignments::Values::Submitter` value object (account_id, name optional, email required) — mirrors the LinkedEvent pattern; (2) `Submission` entity gains optional `submitter` attribute; (3) `Repository::Submissions#find_by_assignment_full` loads submissions + entries + submitters with ONE batched `accounts WHERE id IN (...)` query via a private `submitters_by_account_id` helper (no N+1); new `find_by_account_assignment_full` for the student's own-view path; `rebuild_entity` now takes a `submitter:` kwarg; (4) `Representer::Submission` serializes nested `submitter` via new `SubmitterRepr`; (5) `ListSubmissions` service uses the full loaders for both staff and student paths. Frontend: `AssignmentDetailDialog.vue`'s staff table now has an `el-table` expand column; `Student ID` column replaced with `Student` showing `studentDisplayName(row)` (name, falling back to email, falling back to `Account #id`) plus a small email subtitle; expand row renders the submission's `requirement_uploads` with requirement descriptions and clickable URL links. Chrome-verified on admin staff view: "All Submissions (1)" row shows "Soumya Ray / soumya.ray@iss.nthu.edu.tw" instead of a numeric ID; expand chevron reveals "Draft URL: https://…" with the link. Student regression clean. One side-effect: during the admin pass, the pre-existing 500 on `/api/course/1/events` surfaced (Event entity rejects `location_id = NULL`; locations table is empty because of main's "Locations UI save failure"). Not caused by 2.10d; already flagged in the Slice 2 Review Log as a main-originated follow-up.
- [x] 2.10e Add "past due" warning banner to Assignment detail dialog when `now > due_at` and the student has no submission yet. **Frontend-only, no new tests.** `AssignmentDetailDialog.vue` shows an `el-alert` type=warning at the top of the Submit form section when `!mySubmission && isPastDue` — reuses the `isPastDue` and `mySubmission` computeds added earlier. Copy: *"This assignment is past its due date. Your submission will be marked late."* Chrome-verified on a freshly created past-due assignment id=6 (no existing submission): banner appears. Negative case verified on Past Due (allow late resubmit) after clicking Resubmit (existing submission): banner correctly absent. Cleanup: assignment id=6 ("2.10e verify past due") can be deleted by admin when convenient.

Separate branch candidates (main-originated, not Slice 2):

- [ ] (Main) Locations UI save failure — investigate why "Save Location" doesn't persist.
- [ ] (Main) Role-gate student access to `/course/:id/attendance` URL content (not just the sidebar link).
- [ ] (Main) Rename `showCreateAttendanceEventDialog` / `createAttendanceEvents` in `SingleCourse.vue` to reflect that they now drive bulk `CreateEventsDialog`.

## Hybrid Testing Pain Points (meta-review after Slice 2)

| # | Pain Point | Slice | Impact |
|---|-----------|-------|--------|
| P1 | Post-merge dev DB required `rake db:reset` before server would boot (old `009_assignment_create` had already applied, so renumbered `012` collided). First migrate attempt left DB in half-applied state. | Merge / Slice 2 | One-time setup cost per developer machine after the merge. Document in `CLAUDE.feature-assignments-1-2.md` merge log so future machines know to reset dev DB. |
| P2 | Two-account login switching (admin ↔ student) was the main throughput bottleneck. Each switch: logout, re-enter Google OAuth, navigate back. Roughly 4 switches per full pass. | Slice 2 | Argues for seed fixtures that set up staff + student directly so verification can skip OAuth. Or: allow one admin account to enroll as both owner and student in one course (the "View" dropdown shown earlier might support this if admin can impersonate). |
| P3 | Element Plus `el-select` and `el-date-picker` do not accept `form_input` value assignment — required multi-step click sequences (open dropdown, click option, click OK). Increased Chrome-tool call count noticeably. | Slice 1/2 | Not fixable in our codebase, but worth noting: automated UI tests over this stack will need custom helpers for these components. |
| P4 | Frontend "cache on page load" behavior hid newly-created DB rows in related dropdowns (Location dropdown in Event create dialog, Event dropdown in Assignment edit dialog). Forced reloads revealed the real data. | Slice 2 + main | Either always refetch on dialog open, or use a reactive store. Not a Slice 2 regression — same pattern elsewhere. |
| P5 | Two real bugs (2.10a unpublish, 2.10b silent late-resubmit rejection) were ONLY caught by hybrid testing, not by the 1121-test backend suite. That's because both bugs are in the interaction between policy evaluation and the frontend's willingness to call the API. | Slice 2 | This is a real case for either (a) backend tests asserting the policies check submissions, or (b) an integration test that walks through the HTTP flow a real browser would take. See meta-review above. |
| P6 | No visible confirmation toast after any successful submit/resubmit. Easy for a user (and for the tester) to miss whether the action succeeded without inspecting state changes. | Slice 2 UX | Lumpable under 2.10b (add toasts), or spin out into its own task. |

## Merge Log

### 2026-04-24 — Merged `origin/main` (47 commits absorbed)

Branch had been idle while main shipped: policy namespace refactor (`c277f9b`), multi-event creation feature (Slices 1+2), attendance management feature, events schema invariants (`start <= end`, NOT NULL), timezone handling for bulk events, content-hashed prod bundles, repo-level skill removal (`5b0e961` and follow-ups), and `CLAUDE.md` → `.claude/CLAUDE.md` move.

**Merge commit**: `07ed17c`. Five conflicts resolved manually:

1. `.claude/CLAUDE.md` — kept the branch's stricter TDD Protocol bullet over main's shorter test-first bullet.
2. `.claude/skills/branch-plan/SKILL.md`, `.claude/skills/pr-create/SKILL.md`, and the branch-only `.claude/skills/test-hybrid/` — accepted main's deletion. Repo-level skills are gone; live versions (with potentially newer behavior than what was on the branch) live in `~/.claude/skills/`. Branch's improvements survive in git history (`git show 187a9e1`, `36f378a`) if they need to be ported to the global skills.
3. `backend_app/app/application/policies/attendance_authorization.rb` and `course_policy.rb` — accepted main's deletion (renamed under `Policy::` namespace). The branch's `4288629` rename of `self_enrolled?` → `enrolled?` was discarded; the merged tree uses `self_enrolled?` consistently across all policies.
4. `backend_app/app/application/controllers/routes/course.rb` — auto-merged.
5. `frontend_app/pages/course/SingleCourse.vue` — merged component registration; kept main's `CreateEventsDialog` swap and added the three assignment dialogs.

**Adaptation commit**: `bc4ec32`.

- Policy namespace: `AssignmentPolicy` → `Policy::Assignment` (file `assignment.rb`), `SubmissionPolicy` → `Policy::Submission` (file `submission.rb`). Spec files renamed to match. All 10 service callers updated.
- Migration renumbering to avoid collision with main's events migrations:
  - `009_assignment_create.rb` → `012_assignment_create.rb`
  - `010_submission_requirement_create.rb` → `013_submission_requirement_create.rb`
  - `011_submission_create.rb` → `014_submission_create.rb`
  - `012_submission_entry_create.rb` → `015_submission_entry_create.rb`

**Verification**: `bundle exec rake spec` → 1166 runs / 0 failures / 0 errors / 1 skip / 98.27% line coverage. `npm run prod` → compiles clean (size warnings only).

**Things to watch on next session**:

- `frontend_app/pages/course/SingleCourse.vue`: data key `showCreateAttendanceEventDialog` and method `createAttendanceEvents` were preserved during the merge but now drive `CreateEventsDialog` (plural, bulk). Names are stale relative to the new dialog — consider renaming during Slice 2.9 verification cleanup.
- The `event_id` linkage on assignments references events that, post-merge, must satisfy the new `start_at`/`end_at` NOT NULL + ordering constraints from migrations 010–011. Verify assignment-creation flows that pre-fill `event_id` still work.
- Issue #47 (timezone) may be partially closed by main's `feature-timezone` merge — verify and update or close.

---

Last updated: 2026-04-24 evening (Task 2.9 hybrid verification done via Claude-in-Chrome with two real Google accounts. Flows A/B/C/D/F and backend half of E all PASS. Flows E (frontend), G, and event-linkage regression uncovered bugs / UX gaps — logged as Slice 2 Review Log with tasks 2.10a–2.10e created. Pain-points table populated. 2026-03-02: Tasks 2.10a–2.10e ALL CLOSED: 2.10a (submission-aware policy, red 17F → green 1184P), 2.10b (resubmit gating + error toast), 2.10c (LinkedEvent + find_full, red 11F → green 1195P), 2.10d (Submitter + staff table name/email + expand, red 10F → green 1205P), 2.10e (past-due banner). All verified via Chrome. Ready for PR to main. Pre-existing issue to flag to maintainers: `/api/course/1/events` 500s on `location_id = NULL` — main-originated, documented as separate-branch follow-up.)
