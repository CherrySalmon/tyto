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
- [ ] Slice 2: Submissions with local storage (backend → frontend → verify)
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
- Policies: AssignmentPolicy (teaching staff CRUD; students view published only), SubmissionPolicy (students create/view own; teaching staff view all)
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

> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

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

**Backend test (red)**:

- [ ] 2.1a Failing tests for Submission entity, RequirementUpload entity, and value objects
- [ ] 2.1b Failing tests for Submission repository
- [ ] 2.1c Failing tests for Submission services (create/overwrite, list, get — including late resubmit policy)
- [ ] 2.1d Failing tests for Submission policy (authorization, visibility)
- [ ] 2.1e Failing tests for Submission routes

**Backend implementation (green)**:

- [ ] 2.2 Domain: Submission entity, RequirementUpload entity, collection value objects
- [ ] 2.3 Infrastructure: migrations (submissions + submission_entries), ORM models, repository
- [ ] 2.4 Infrastructure: file storage — LocalGateway (dev/test filesystem adapter), Mapper, storage abstraction interface
- [ ] 2.5 Application: services (create/overwrite with file validation, late resubmit enforcement), policy, routes (including presign-upload and presign-download endpoints). Note: file extension validation against `allowed_types` must be case-insensitive (e.g., uploading `Report.PDF` should match `pdf`).
- [ ] 2.6 Presentation: Submission representer (including nested entries)
- [ ] 2.7 All backend tests pass

**🔍 REVIEW CHECKPOINT**: Pause for developer review of Slice 2 backend (domain, infrastructure, application, presentation). All backend tests should pass. Resume with frontend after review.

**Frontend**:

- [ ] 2.8 Submission form on assignment detail (per-requirement: file upload or URL input)
- [ ] 2.9 Student's own submission view (with resubmit capability)
- [ ] 2.10 Teaching staff submissions list (all students, late indicators)

**Verify**:

- [ ] 2.11 Hybrid verification: Chrome walkthrough of submission flows + manual developer pass

### Slice 3: Production S3 Infrastructure

- [ ] 3.1 Add `aws-sdk-s3` gem; S3 config entries in secrets.yml template
- [ ] 3.2 Gateway: real AWS SDK implementation (presign_upload, presign_download, head, delete)
- [ ] 3.3 Environment-based gateway selection (LocalGateway for dev/test, Gateway for production)
- [ ] 3.4 Guided walkthrough: AWS S3 bucket creation, IAM policy, CORS config, credentials in secrets.yml
- [ ] 3.5 Tests for Gateway (mocked AWS SDK) and gateway selection logic
- [ ] 3.6 All tests pass (including Slice 1 and 2 regression)

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
- **Timezone display**: GitHub issue #47 (cross-cutting UX improvement)
- **Markdown sanitization** (1.12e): `v-html` + `marked` in AssignmentDetailDialog — add DOMPurify after Slice 2 (may apply to submissions too)

## Hybrid Testing Pain Points (meta-review after Slice 2)

> Track observations here during Slice 2 hybrid testing. After Slice 2, review this list to decide whether automated interface acceptance tests (Playwright/Capybara) are warranted before merging to main.

| # | Pain Point | Slice | Impact |
|---|-----------|-------|--------|
| — | *(none yet — populate during Slice 2 verification)* | — | — |

---

Last updated: 2026-03-04 (added hybrid testing meta-review tracking; Slice 1 extension complete)
