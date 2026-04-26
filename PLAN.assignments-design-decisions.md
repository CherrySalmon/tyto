# Assignments: Design Decisions

> Resolved design questions for the Assignments feature. Referenced from `PLAN.feature-assignments-3.md` (active Slice 3 plan). Slices 1–2 history is captured in commit messages on the `feature-assignments` branch.

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

  **Revisited 2026-03-02 (Slice 3)**: the name `RequirementUpload` stays. After un-unifying storage (see R2 revisit), "upload" is a slight overstatement for URL-type entries (they're not uploaded anywhere), but renaming would churn Slice 1 + 2 code for marginal gain. Treat the name as historical and accept that it now means "requirement fulfillment" more than "upload artifact." Revisit if the name ever actively misleads a reader.

### S3 Storage

- [x] **R2: S3 key pattern.** **Decision: `<assignment_id>/<requirement_id>/<account_id>.<extension>`.** No `submission_id` (avoids chicken-and-egg). `requirement_id` before `account_id` (groups all student uploads per requirement for batch download). S3 key is fully computable from IDs + extension — no stored filename. URL entries stored as `.url` files for unified storage model. On resubmit with changed extension: read old extension from DB → delete old S3 object → upload new file → update DB.

  **Revisited 2026-03-02 (Slice 3 — see `PLAN.feature-assignments-3.md` Q3 decision)**: the S3 key pattern stands for file-type entries, but the "URL entries stored as `.url` files for unified storage model" clause is **reversed**. Rationale: (a) store things in their natural form — URLs are text, files are blobs; (b) YAGNI — unified storage solved no concrete need and forced a Gateway write-path the backend otherwise doesn't need; (c) bulk download would re-process `.url` files into a manifest CSV anyway, so write-time materialization was wasted; (d) `.url` (Windows Internet Shortcut) format is platform-biased — a clickable `<a href={raw_url}>` beats a downloadable `.url` file on every OS. Going forward: `content` is polymorphic per `submission_format` — an S3 key when `file`, a raw URL string when `url`. Extension-change cleanup only applies to file-type entries. URL-type entries never touch S3.

  **Extended 2026-04-24 (Slice 3 pre-implementation review — see `PLAN.feature-assignments-3.md` R-P2 and R-P6)**:
  - **R-P2 — server reconstructs the key**: the S3 key is fully computable from IDs + extension per this rule, so the service must not trust a client-supplied `content` value for file-type entries. `CreateSubmission` reconstructs `<assignment_id>/<requirement_id>/<account_id>.<ext>` from (route `assignment_id` + body `requirement_id` + **authenticated** `account_id` + extension from the submitted filename), HEAD-checks that reconstructed key, and ignores any key the client tries to submit. This closes the gap where a student could reference another student's S3 key as their own submission. The key-pattern rule was always designed for this, but the security-relevant implication had to be made explicit.
  - **R-P6 — extension-change cleanup is best-effort, outside the DB transaction**: the original "read old ext → delete old S3 object → upload new → update DB" ordering is refined to "persist new entry inside the DB transaction → call `Gateway#delete(old_key)` outside the transaction, log and swallow failures." An S3 blip must not roll back a valid submission; the resulting orphan is acceptable per R9.

- [x] **R9: Orphaned file cleanup.** **Decision: no automated cleanup.** Upload directly to final S3 path — no `pending/` prefix, no lifecycle rules. Orphans are rare (confirm step failure only), harmless (capped at 10MB, naturally overwritten on resubmit since keys are deterministic). Deferred: on-demand reconciliation button for teaching staff to cross-validate S3 against DB for a given assignment.

- [x] **R10: Local gateway detection.** **Decision: presign response provides upload URL.** In production it's a presigned S3 URL; in dev it's a local backend URL. Frontend uploads to whatever URL it receives — no mode flag, no build-time env vars, no branching logic. Backend controls the behavior.

  **Extended 2026-03-02 (Slice 3 — see `PLAN.feature-assignments-3.md` Q4 decision)**: the dev-side endpoint (`PUT /api/_local_storage/upload`, `GET /api/_local_storage/download/:key`) is mounted under `if Tyto::Api.environment != :production` in the Roda route tree — the branch literally doesn't exist in production, so the endpoint can't leak into a prod deploy even by misconfiguration. Additional defense: HMAC-signed token (key + expiry) required on every request, chrooted under `LOCAL_STORAGE_ROOT`. Frontend still uploads to whatever URL it receives — no change to R10's core principle, just hardening on the backend side.

  **Refined 2026-04-24 (Slice 3 pre-implementation review — see `PLAN.feature-assignments-3.md` R-P1, R-P3, R-P5, R-P8)**:
  - **R-P3 — env guard is an allowlist, not a denylist**: replace `Tyto::Api.environment != :production` with `Tyto::Api.environment.in?(%i[development test])`. Future staging / preview / ci-branch environments (where `environment` is some symbol other than `:production` but we still want the real S3 Gateway) won't silently mount dev-only routes. Same principle applies to the gateway selector. **Source of truth (2026-04-26)**: Roda's `:environments` plugin (already enabled in `backend_app/config/environment.rb:8`) exposes `Tyto::Api.environment` as a Symbol — the selector and any other env-dependent code consults this method, never `ENV['RACK_ENV']` directly.
  - **R-P1 — dev endpoint is `POST`, not `PUT`**: frontend uploads via multipart form-POST in both dev and prod, matching AWS's presigned-POST flow. PUT cannot enforce `content-length-range` at S3 (header is client-set); POST's signed policy doc can. The LocalGateway endpoint mirrors this so the frontend code path is identical across environments.
  - **R-P5 — download route uses a splat**: the S3 key is multi-segment (`<a>/<r>/<acc>.<ext>`) and Roda's named params don't cross `/`. Dev route: `GET /api/_local_storage/download/*key`.
  - **R-P8 — HMAC tokens are single-use**: token payload `{key, op, exp, nonce}`; backend keeps consumed nonces in an in-process bounded cache until `exp`. Prevents replay from a leaked dev log. TTL: 15 min upload, 5 min download. Dev-only — no Redis needed.

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

  **Revisited 2026-03-02 (Slice 3 — REVERSED)**: when Slice 3 implementation was mapped out, Q-B's cost became concrete and the benefit stayed abstract. Reversal rationale (full discussion in `PLAN.feature-assignments-3.md` Q3 decision):

  - **Cost of unified storage** (as originally specified): a Gateway direct-write method the backend otherwise doesn't need; a second upload path (file → client-to-S3 presigned; URL → backend-to-S3 direct) for the client to reason about; a `.url` format decision that's platform-biased (clickable on Windows only).
  - **Benefit of unified storage**: conceptual ("everything is an S3 object"). But bulk-download would immediately break the abstraction — a manifest CSV of URLs is more useful to graders than a pile of `.url` files, so write-time materialization would be re-processed at read time anyway.
  - **New decision**: `content` is **polymorphic per `submission_format`** — S3 key when `'file'`, raw URL string when `'url'` (tagged union — `submission_format` already disambiguates). URL-type entries stored and returned exactly as Slice 2 already persists them. Only file-type entries go through the presign + upload flow. Backend Gateway drops the direct-write method entirely.
  - **No migration needed**: Slice 2's URL-string storage becomes the permanent model, not a transitional state.
  - **Consequences for other decisions**: R2's "URL entries stored as `.url` files" clause is reversed (see R2 revisit). R5's "all entries are S3 objects" premise no longer holds (see R5 revisit). Everything else stands.

## Slice 3 Pre-implementation Refinements (2026-04-24)

> A second pre-implementation review (after Q-A/Q-B were answered) produced eleven refinements R-P1 … R-P11. Items that refine an existing R- entry are folded into that entry's revisit block above (R-P2 + R-P6 into R2; R-P1 + R-P3 + R-P5 + R-P8 into R10). Items that introduce genuinely new decisions are recorded here. Full discussion in `PLAN.feature-assignments-3.md` Phase 0.5.

- [x] **R-P1: Upload protocol — presigned POST, not PUT.** Gateway + Mapper emit AWS presigned **POST** URLs with a signed policy document carrying `content-length-range` and `key` equality conditions. Frontend uploads as multipart form-POST using server-supplied `fields`. Rationale: presigned PUT cannot enforce size at S3 — `Content-Length` is a client-set header, unsigned; a malicious client can exceed the intended cap and S3 accepts the object. POST's policy doc is signed server-side and S3 rejects uploads that violate it. Overwrite semantics are unchanged — S3 replaces at the same key for both PUT and POST, so R2's deterministic-key idempotent retries still work exactly as specified.

- [x] **R-P4: Download protocol — backend redirect, not render-time presigned URL.** Supersedes Q5 (design-decision was Option A: representer emits presigned GET URL directly). **New route**: `GET /api/course/:course_id/assignments/:assignment_id/submissions/:submission_id/uploads/:upload_id/download`. Handler authorizes the requestor via `Policy::Assignment#can_view_submission?`, mints a fresh presigned GET from the Gateway (15 min TTL), and 302-redirects. Representer emits `download_url` as a link to *this* backend route, not a presigned S3 URL. Rationale: render-time presigned URLs silently expire on long-open staff views (typical TTL ≤ 15 min; typical staff workflow ≫ 15 min), producing a cryptic S3 error on click. The redirect pattern keeps URLs fresh per click and gives a natural seam for download auditing later. Presigned URLs still never touch the DB — they're minted on demand.

- [x] **R-P7: File-size limit has a single source of truth.** Define `Tyto::FileStorage::MAX_SIZE_BYTES = 10 * 1024 * 1024` in one Ruby constant (`infrastructure/file_storage/limits.rb`). Referenced by: Mapper's policy-doc `content-length-range`, `CreateSubmission`'s Slice-2 validator, and the frontend (distribution TBD — `GET /api/config/file_storage_limits` endpoint or build-time env var). Replaces the previous pattern where 10 MB was a magic number scattered across validator + any future emitter of the constraint. Supersedes the bare "10 MB" mention in Q8 as the source of truth — Q8 sets the number, R-P7 sets how that number is wired.

- [x] **R-P9: `content_type` is untrusted display metadata.** Stored value is whatever the browser sent in the upload POST's `Content-Type` form field. It's **never** used as a security signal (extension check is authoritative for type enforcement; if we later need content-based validation, a virus/MIME-sniff pass gets added at a defined seam — out of scope for Slice 3). Document this inline on the `RequirementUpload` entity attribute so nobody assumes the value is vetted. `filename` has the same trust level and the same treatment.

- [x] **R-P10: Service name — `IssueUploadUrls`, not `CreateUploadUrls`.** Cosmetic but consistent with what the service actually does: mint short-lived credentials, not persist a resource. "Create" reads like a write service; "Issue" reads like a credential mint.

  **Renamed again 2026-04-26**: `IssueUploadUrls` → `IssueUploadGrants`, and the route resource `/upload_urls` → `/upload_grants`. Triggered by a REST-naming review during 3.10: the response is a 4-field credential `{requirement_id, key, upload_url, fields}`, not just a URL, so naming the collection after one field undersells what's returned. "Grant" borrows OAuth/IAM vocabulary for scoped, time-limited authorizations and reads as a noun. Field name `upload_url` inside each grant is unchanged.

- [x] **R-P11: Integration test is an explicit deliverable.** A thin Rack::Test-driven end-to-end test covers the full presign → upload → submit → download path using the LocalGateway. Not a substitute for unit tests; catches hybrid-layer bugs of the kind that consumed disproportionate time in Slice 2 (pain point P5). Scheduled as task 3.14a.

## Related Issues

- [#46](https://github.com/CherrySalmon/tyto/issues/46): Rename API routes to follow REST plural conventions

---

Last updated: 2026-04-26 (Resource rename: `/upload_urls` → `/upload_grants`, service `IssueUploadUrls` → `IssueUploadGrants` — see R-P10 revisit block. Previous footer (2026-04-24): Slice 3 second pre-implementation review — recorded R-P1 … R-P11: presigned POST, server-reconstructed keys and best-effort cleanup folded into R2; allowlist env guard, POST dev endpoint, splat download route, single-use HMAC tokens folded into R10; backend download redirect supersedes Q5 Option A; size constant, `content_type` trust level, and integration test recorded as new entries.)
