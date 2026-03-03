# Assignments: Design Decisions

> Resolved design questions for the Assignments feature. Referenced from `CLAUDE.feature-assignments.md`.

## Scope and Boundaries

- [x] **Q1: New bounded context or extension of Courses?** **Decision: new `assignments` bounded context** with two aggregate roots: **Assignment** (references course_id and optional event_id by ID) and **Submission** (references assignment_id and account_id by ID). Follows the Attendance pattern — separate context with its own aggregates that reference other contexts by ID. Submission is its own aggregate root (not a child of Assignment) because submissions are created concurrently by many students and have independent lifecycles.

- [x] **Q2: Is grading in scope?** **Decision: out of scope.** Defer grading (scores, rubrics, feedback) to a future branch. This branch focuses on assignment creation + student submission only.

- [x] **Q3: File storage strategy?** **Decision: AWS S3.** Heroku has ephemeral filesystem, so local storage is not viable. S3 chosen over Postgres bytea because submissions may include multiple files (Rmd/Quarto, PDFs, etc.) and S3 scales independently. Use a storage abstraction so the adapter can be swapped (e.g., local filesystem for dev/test).

## Behavior

- [x] **Q4: Multiple submissions?** **Decision: overwrite model.** One submission per student per assignment. Resubmitting before the deadline always overwrites. Late resubmits controlled by `allow_late_resubmit` (boolean, default false) on the assignment. When false, all resubmission after the deadline is blocked. When true, students can resubmit anytime. Submission history deferred to grading branch — overwrite is sufficient until then. Overwrite uses upsert per requirement — individual entries matched by `(submission_id, requirement_id)` are updated or inserted; entries for other requirements are preserved (see R3).

- [x] **Q5: Late submissions?** **Decision: always accepted (first-time).** A student who hasn't submitted can always submit after the deadline. The `submitted_at` timestamp records when it was submitted; late/on-time status is derived by comparing to `due_at` at read time (no stored status). The `allow_late_resubmit` flag (Q4) controls resubmission only — when false, any resubmission after `due_at` is blocked regardless of whether the existing submission was on-time or late (see R6).

- [x] **Q6: Submission visibility?** **Decision: private.** Students see only their own submissions. Teaching staff see all. Peer review (students viewing each other's submissions) deferred to a future branch.

- [x] **Q7: Assignment lifecycle?** **Decision: `draft` → `published` → `disabled`.** All transitions are one-way. Students see only `published` assignments. Teaching staff see all. `disabled` hides an assignment from students without deleting data — use instead of deletion when submissions exist. "Closed" (not accepting submissions) is not a stored state — it's derived at read time from `due_at`, `allow_late_resubmit`, and whether the student has an existing submission. No state machine gem — plain domain logic sufficient for one-way transitions. `AssignmentStatus = Types::String.enum('draft', 'published', 'disabled')`.

## Event Association

- [x] **Q10: Event association model?** **Decision: optional single event FK.** One-to-many from events → assignments. An assignment has an optional `event_id`. An event can have multiple assignments. No join table needed. `due_at` remains an independent field. `on_delete: :set_null` — deleting an event clears the assignment's event link without losing assignment data (see R-minor).

- [x] **Q11: Event association required?** **Decision: optional.** Assignments can exist without an event link (e.g., semester project). The `event_id` FK is nullable.

## Timezone

- [x] **Q12: Timezone handling?** **Decision: user-local timezone.** All timestamps stored as UTC. Frontend detects user's browser timezone for display and input conversion. No timezone column on courses or assignments. Users in different timezones see dates converted to their local time.

## Technical

- [x] **Q8: File size limits?** **Decision: 10 MB per file** for now. Enforced at the infrastructure layer (S3 upload + backend validation).

- [x] **Q9: Allowed file types?** **Decision: per-requirement, no system-wide allowlist.** Teaching staff defines allowed extensions (e.g., `.Rmd,.pdf`) on each submission requirement. The system validates the uploaded file's extension against the requirement's `allowed_types` string. Nothing hardcoded — the constraint is entirely user-defined data.

## Architecture Review

Decisions from reviewing the domain model against existing codebase patterns.

### Naming

- [x] **R1: `type` column naming collision.** **Decision: rename to `submission_format`.** Avoids Sequel's STI collision on `type`. More descriptive — reads as `submission_format: 'file'` or `submission_format: 'url'`. Domain type: `RequirementType = Types::String.enum('file', 'url')` (unchanged), but the DB column and entity attribute are `submission_format`.

- [x] **R5: Child entity naming.** **Decision: `RequirementUpload`** (collection: `RequirementUploads`). Renamed from `SubmissionEntry` — avoids ambiguity with the parent `Submission` aggregate. "Upload" is accurate since all entries are S3 objects (URLs stored as `.url` files). The cross-aggregate FK (`requirement_id` → `SubmissionRequirement`) is accepted as a deliberate trade-off — the reference target is stable (requirements frozen after publishing per R7).

### S3 Storage

- [x] **R2: S3 key pattern.** **Decision: `<assignment_id>/<requirement_id>/<account_id>.<extension>`.** No `submission_id` (avoids chicken-and-egg). `requirement_id` before `account_id` (groups all student uploads per requirement for batch download). S3 key is fully computable from IDs + extension — no stored filename. URL entries stored as `.url` files for unified storage model. On resubmit with changed extension: read old extension from DB → delete old S3 object → upload new file → update DB.

- [x] **R9: Orphaned file cleanup.** **Decision: no automated cleanup.** Upload directly to final S3 path — no `pending/` prefix, no lifecycle rules. Orphans are rare (confirm step failure only), harmless (capped at 10MB, naturally overwritten on resubmit since keys are deterministic). Deferred: on-demand reconciliation button for teaching staff to cross-validate S3 against DB for a given assignment.

- [x] **R10: Local gateway detection.** **Decision: presign response provides upload URL.** In production it's a presigned S3 URL; in dev it's a local backend URL. Frontend uploads to whatever URL it receives — no mode flag, no build-time env vars, no branching logic. Backend controls the behavior.

### Repository and Authorization

- [x] **R4: Repository stays authorization-agnostic.** **Decision: add `find_by_course_and_status(course_id, status)`.** Repository has no knowledge of caller roles. Service layer decides which method to call: teaching staff → `find_by_course(course_id)` (all), students → `find_by_course_and_status(course_id, 'published')`. Consistent with CoursesRepository and AttendancesRepository patterns.

### Submission Behavior

- [x] **R3: Overwrite mechanics.** **Decision: upsert per requirement.** On resubmit, update or insert each entry matched by `(submission_id, requirement_id)`. Entries for other requirements are preserved. Parent `Submission.submitted_at` updated on every upsert. Upsert match key is `requirement_id` (stable), not S3 key or extension (derived).

- [x] **R6: `allow_late_resubmit` semantics.** **Decision: simple binary.** `allow_late_resubmit=false` blocks all resubmission after deadline — regardless of whether existing submission was on-time or late. Logic: block IF `now > due_at` AND `allow_late_resubmit == false` AND existing submission exists.

### Published Assignment Rules

- [x] **R7: Published assignment mutability.** **Decision: metadata mutable, requirements frozen.** After publishing, allow edits to: title, description, due_at, allow_late_resubmit, event_id. Freeze: submission requirements (cannot add, remove, or modify). If different requirements are needed, create a new assignment.

- [x] **R8: Deletion behavior.** **Decision: block delete if submissions exist.** Hard delete allowed for draft or submission-free published assignments. Use `disabled` lifecycle state instead of soft delete — hides from students without losing data. Draft assignments can be freely deleted (students can't see them, so no submissions).

### Minor

- [x] **Event FK on_delete.** **Decision: `:set_null`.** Deleting an event clears the assignment's `event_id` without losing assignment data.

- [x] **`RequirementUpload.updated_at`.** **Decision: added.** Tracks when each individual requirement entry was last resubmitted. Consistent with every other entity.

## Implementation Decisions

Resolved during pre-implementation review (2026-03-03).

- [x] **Q-A: Route mounting path.** **Decision: use current singular `/api/course/:course_id/assignments/`.** Matches existing codebase. Issue #46 will rename to plural later.

- [x] **Q-B: URL storage model.** **Decision: unified `.url` files from the start.** URL-type requirement uploads are stored as `.url` files (Windows Internet Shortcut format) in S3, consistent with R2. Format: `[InternetShortcut]\nURL=<url>`. Extension is self-documenting; format is simpler than freedesktop.org `.desktop`. No branching between file/URL storage paths — `content` is always an S3 key.

## Related Issues

- [#46](https://github.com/CherrySalmon/tyto/issues/46): Rename API routes to follow REST plural conventions

---

Last updated: 2026-03-03 (added implementation decisions Q-A, Q-B)
