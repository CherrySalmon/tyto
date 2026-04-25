# Assignments Domain Model

> Referenced from `PLAN.feature-assignments-3.md` (active Slice 3 plan). Slices 1–2 history is captured in commit messages on the `feature-assignments` branch. This is the authoritative definition of the Assignments bounded context domain model.
>
> **2026-03-02 revision note**: Slice 3 pre-implementation review revisited R2 / Q-B and **reversed the unified `.url` storage model**. `content` on `RequirementUpload` is now polymorphic per `submission_format` — an S3 key when `'file'`, a raw URL string when `'url'`. Inline edits below reflect this.
>
> **2026-04-24 revision note**: Second pre-implementation review produced refinements R-P1 … R-P11. Architectural impact (reflected inline below): upload protocol is presigned **POST** (not PUT) so S3 enforces the size cap server-side; server **reconstructs** the S3 key from auth context and never trusts a client-supplied key; download flow is a **backend redirect endpoint** (`GET .../uploads/:id/download` → 302 to freshly-minted presigned GET) rather than render-time presigned URLs — avoids silent staleness on long-open views; LocalGateway env guard is an **allowlist** (`development`/`test`) with single-use HMAC tokens; `content_type` is documented as untrusted display metadata. See `PLAN.assignments-design-decisions.md` R2 / R5 / R10 / Q-B revisit blocks + Slice 3 Pre-implementation Refinements section for full rationale.

## Bounded Context: Assignments

New bounded context alongside Accounts, Courses, Attendance, Shared. References other contexts by ID only (no direct entity imports across boundaries).

## Aggregate Roots

### 1. Assignment (aggregate root)

Represents a task assigned to students within a course. Created by teaching staff. Has a draft/published/disabled lifecycle.

#### Entity: Assignment

| Attribute              | Type                          | Notes                                      |
|------------------------|-------------------------------|--------------------------------------------|
| id                     | Integer, optional             | PK, nil before persistence                 |
| course_id              | Integer                       | FK → courses (required)                    |
| event_id               | Integer, optional             | FK → events (nullable, same course)        |
| title                  | AssignmentTitle (constrained) | Required, max 200 chars                    |
| description            | String, optional              | Markdown content                           |
| status                 | AssignmentStatus              | Enum: 'draft', 'published', 'disabled' (default: draft)|
| due_at                 | Time, optional                | Stored UTC, displayed in user's local TZ   |
| allow_late_resubmit    | Bool                          | Default: false                             |
| created_at             | Time, optional                |                                            |
| updated_at             | Time, optional                |                                            |
| submission_requirements| SubmissionRequirements, optional | Typed collection, nil = not loaded      |

#### Child Entity: SubmissionRequirement

Defines one required piece of a submission (e.g., "R Markdown source" or "GitHub repo link"). Belongs to Assignment — loaded/saved through the Assignment aggregate.

| Attribute     | Type                    | Notes                                        |
|---------------|-------------------------|----------------------------------------------|
| id            | Integer, optional       | PK                                           |
| assignment_id | Integer                 | FK → assignments                             |
| submission_format | RequirementType     | Enum: 'file', 'url' (R1: renamed from `type` to avoid Sequel STI collision) |
| description   | String                  | e.g., "R Markdown source file"               |
| allowed_types | String, optional        | Comma-separated extensions, e.g., ".Rmd,.qmd". Only for submission_format='file'. |
| sort_order    | Integer                 | Display ordering                             |
| created_at    | Time, optional          |                                              |
| updated_at    | Time, optional          |                                              |

**Value Object: SubmissionRequirements** (typed collection)

Wraps an array of SubmissionRequirement entities. Follows the Events/Locations/Enrollments pattern (Dry::Struct, includes Enumerable, `.from()` constructor).

### 2. Submission (aggregate root)

Represents a student's submission for an assignment. One submission per student per assignment (overwrite model).

#### Entity: Submission

| Attribute     | Type              | Notes                                           |
|---------------|-------------------|-------------------------------------------------|
| id            | Integer, optional | PK                                              |
| assignment_id | Integer           | FK → assignments                                |
| account_id    | Integer           | FK → accounts (the student)                     |
| submitted_at  | Time              | When the submission was made/last overwritten    |
| created_at    | Time, optional    |                                                 |
| updated_at    | Time, optional    |                                                 |
| requirement_uploads | RequirementUploads, optional | Typed collection, nil = not loaded     |

#### Child Entity: RequirementUpload

One entry per submission requirement fulfilled. Belongs to Submission — loaded/saved through the Submission aggregate.

| Attribute      | Type              | Notes                                          |
|----------------|-------------------|-------------------------------------------------|
| id             | Integer, optional | PK                                             |
| submission_id  | Integer           | FK → submissions                               |
| requirement_id | Integer           | FK → submission_requirements                   |
| content        | String            | Polymorphic per `submission_format`: S3 key when `'file'`, raw URL string when `'url'` (R2/Q-B revisited 2026-03-02) |
| filename       | String, optional  | Original filename (file uploads only)          |
| content_type   | String, optional  | MIME type (file uploads only). **Untrusted display metadata** per R-P9 — client-asserted, never used as a security signal. |
| file_size      | Integer, optional | Bytes (file uploads only). Max 10 MB.          |
| created_at     | Time, optional    |                                                |
| updated_at     | Time, optional    |                                                |

**Value Object: RequirementUploads** (typed collection)

Wraps an array of RequirementUpload entities. Same pattern as SubmissionRequirements.

## Domain Types (additions to `types.rb`)

```ruby
# Assignment types
AssignmentTitle  = Types::String.constrained(min_size: 1, max_size: 200)
AssignmentStatus = Types::String.enum('draft', 'published', 'disabled')

# Submission requirement types
RequirementType = Types::String.enum('file', 'url')
```

## Relationships

```text
Courses context (external)          Assignments context
========================           ========================

Course ──────────────────────────→ Assignment (aggregate root)
  (course_id FK)                     ├─ SubmissionRequirement (child, 1:many)
                                     │
Event ───────────────────────────→ Assignment (optional event_id FK)
  (event_id FK, nullable)           │
                                     │
Accounts context (external)         Submission (aggregate root)
========================             ├─ RequirementUpload (child, 1:many)
                                     │     └─ requirement_id FK → SubmissionRequirement
Account ─────────────────────────→ Submission
  (account_id FK)                    (one per student per assignment)
```

## Database Tables

### assignments

```sql
assignments
  id            (PK, auto-increment)
  course_id     (FK → courses, NOT NULL)
  event_id      (FK → events, nullable)
  title         (String, NOT NULL)
  description   (Text, nullable)
  status        (String, NOT NULL, default: 'draft')
  due_at        (DateTime, nullable)
  allow_late_resubmit (Boolean, NOT NULL, default: false)
  created_at    (DateTime)
  updated_at    (DateTime)
```

### submission_requirements

```sql
submission_requirements
  id              (PK, auto-increment)
  assignment_id   (FK → assignments, NOT NULL)
  submission_format (String, NOT NULL)        -- 'file' or 'url' (R1: renamed from type)
  description     (String, NOT NULL)
  allowed_types   (String, nullable)          -- e.g., ".Rmd,.qmd,.pdf"
  sort_order      (Integer, NOT NULL, default: 0)
  created_at      (DateTime)
  updated_at      (DateTime)
```

### submissions

```sql
submissions
  id              (PK, auto-increment)
  assignment_id   (FK → assignments, NOT NULL)
  account_id      (FK → accounts, NOT NULL)
  submitted_at    (DateTime, NOT NULL)
  created_at      (DateTime)
  updated_at      (DateTime)

  UNIQUE(assignment_id, account_id)  -- one submission per student per assignment
```

### submission_entries

```sql
submission_entries
  id              (PK, auto-increment)
  submission_id   (FK → submissions, NOT NULL)
  requirement_id  (FK → submission_requirements, NOT NULL)
  content         (String, NOT NULL)          -- S3 key when submission_format='file'; raw URL when 'url' (R2/Q-B revisited 2026-03-02)
  filename        (String, nullable)          -- original filename (files only)
  content_type    (String, nullable)          -- MIME type (files only)
  file_size       (Integer, nullable)         -- bytes (files only)
  created_at      (DateTime)
  updated_at      (DateTime)
```

## Key Domain Rules

1. **Assignment lifecycle**: `draft` → `published` → `disabled`. All transitions are one-way. Students see only `published` assignments. Teaching staff see all. `disabled` hides an assignment from students without deleting data — use instead of deletion when submissions exist. "Closed" (not accepting submissions) is not a stored state — it's derived at read time from `due_at`, `allow_late_resubmit`, and whether the student has an existing submission (see rules #3, #4).

2. **Overwrite model**: One submission per student per assignment (enforced by unique constraint). Resubmitting overwrites existing entries.

3. **Late submission policy**: First-time late submissions are always accepted (never blocked). `allow_late_resubmit` (default false) controls whether resubmission is allowed after the deadline. When false, any resubmission after `due_at` is blocked — regardless of whether the existing submission was on-time or late.

4. **Late/on-time derived**: No stored status — compare `submission.submitted_at` against `assignment.due_at` at read time. Assignments without `due_at` have no late concept.

5. **Submission visibility**: Students see only their own submissions. Teaching staff see all submissions for an assignment.

6. **File validation**: Uploaded file extension validated against `submission_requirement.allowed_types`. Max 10 MB per file. No system-wide allowlist — constraints are per-requirement.

7. **Event association**: Optional. An event can have multiple assignments. Assignment's `event_id` must reference an event in the same course (validated in service layer).

## Repository Loading Patterns

Following the composable loading pattern established by CoursesRepository:

**AssignmentRepository**:

- `find_id(id)` — Assignment only (requirements = nil)
- `find_with_requirements(id)` — Assignment + SubmissionRequirements
- `find_by_course(course_id)` — All assignments for a course
- `find_by_course_and_status(course_id, status)` — Assignments filtered by status (service calls this with `'published'` for students)
- `find_by_course_with_requirements(course_id)` — All assignments + their requirements

**SubmissionRepository**:

- `find_by_account_assignment(account_id, assignment_id)` — Single student's submission
- `find_by_account_assignment_with_entries(account_id, assignment_id)` — With entries loaded
- `find_by_assignment(assignment_id)` — All submissions for an assignment (teaching staff)
- `find_by_assignment_with_entries(assignment_id)` — All submissions + entries

## Infrastructure: File Storage

Direct-to-S3 uploads via presigned URLs. The backend never proxies file bytes — it generates short-lived presigned credentials, and the browser uploads directly to S3. This offloads upload work to clients and avoids tying up Ruby processes.

### Upload Flow (presigned direct-to-S3)

```text
┌──────────┐  1. POST /upload_urls        ┌──────────┐
│  Vue.js  │ ──────────────────────────→  │   Roda   │
│ Frontend │  ←────────────────────────── │ Backend  │
│          │  2. Return POST URL          │          │
│          │     + signed fields          └──────────┘
│          │  3. multipart form-POST        ┌────────┐
│          │ ────────────────────────────→  │   S3   │
│          │  4. Success/failure            │        │
│          │  ←──────────────────────────── │        │
└──────────┘                               └────────┘
            5. POST /submissions
               (filename + metadata only)
               → backend reconstructs key + HEAD
```

**Step 1–2 (presign)**: `POST /api/course/:course_id/assignments/:assignment_id/upload_urls` validates the request (authorization, file extension against requirement's `allowed_types`), then generates a presigned **POST** URL with constraints baked into a signed policy document (`content-length-range: [1, MAX_SIZE_BYTES]`, `key` equality). S3 enforces the policy server-side per R-P1. Response: array of `{requirement_id, key, upload_url, fields}` — the `fields` hash contains the signed policy, signature, and AWS form-POST fields the browser must include.

**Step 3–4 (upload)**: Browser sends each file as multipart form-POST to `upload_url`, submitting `fields` alongside the file. S3 rejects uploads that violate the policy. Frontend can show native progress events.

**Step 5 (confirm)**: Frontend sends `POST /submissions` with only `{requirement_id, filename, content_type, file_size}` per file-type entry — **no key**. Backend **reconstructs** the S3 key server-side from (route `assignment_id` + body `requirement_id` + authenticated `account_id` + extension from filename) per R-P2, HEAD-checks the reconstructed key, and persists the `requirement_upload` record (DB table: `submission_entries`). Client-supplied keys are ignored — prevents cross-account key references.

### Download Flow

Backend exposes `GET /api/course/:course_id/assignments/:assignment_id/submissions/:submission_id/uploads/:upload_id/download` per R-P4. Handler authorizes the requestor, mints a fresh presigned GET (15 min TTL) from the Gateway, and 302-redirects. Browser follows the redirect; bytes stream directly from S3 to the client. Representer emits `download_url` as a link to *this* backend route, **not** a presigned S3 URL — avoids the silent-staleness problem where a long-open staff view holds URLs past their TTL.

### S3 Key Pattern

`<assignment_id>/<requirement_id>/<account_id>.<extension>`

No `submission_id` in key (R2: avoids chicken-and-egg with persistence). `requirement_id` before `account_id` groups all student uploads per requirement for batch download. Key is fully computable from IDs + extension — no stored filename needed. Key construction lives in `SubmissionMapper` and is used by **both** the presign service (to build keys from authenticated context) and `CreateSubmission` (to **reconstruct** and verify keys per R-P2). **URL entries do NOT get S3 keys** — they're stored as raw strings in the `content` column (R2/Q-B revisited 2026-03-02 — see design decisions doc). On resubmit with changed extension (file-type only): persist new entry inside the DB transaction → call `Gateway#delete(old_key)` outside the transaction (best-effort per R-P6, log and swallow failures so an S3 blip doesn't roll back a valid submission).

### Gateway/Mapper Pattern

Follows the existing `auth_token` and `sso_auth` infrastructure patterns:

```text
infrastructure/
  file_storage/
    gateway.rb           # Raw AWS SDK calls (presign_upload, presign_download, head, delete)
    local_gateway.rb     # Filesystem adapter for dev/test (receives form-POST; HMAC-signed single-use tokens)
    mapper.rb            # Generic constraint encoding (max size, allowed types → POST policy conditions)
    submission_mapper.rb # Submission-specific key construction; used by both presign service and CreateSubmission
    limits.rb            # MAX_SIZE_BYTES single source of truth (R-P7)
```

- **Gateway**: Raw I/O boundary with AWS. `presign_upload(key, constraints)` returns presigned **POST** (URL + signed `fields` hash) per R-P1 — PUT is rejected because `Content-Length` would be unsigned. Plus `presign_download(key)`, `head(key)`, `delete(key)`. Uses `aws-sdk-s3`. Returns `Success`/`Failure`.
- **LocalGateway**: Same interface for dev/test. Stores files on local filesystem at `LOCAL_STORAGE_ROOT/<key>`. Exposes `POST /api/_local_storage/upload` (form-POST receiver) and `GET /api/_local_storage/download/*key` (splat for the multi-segment key per R-P5). Route branch is mounted only when `Tyto::Api.environment.in?(%i[development test])` — **allowlist per R-P3**, not `!= :production`. Source of truth for the environment is Roda's `:environments` plugin (enabled in `backend_app/config/environment.rb:8`); no ad-hoc `ENV['RACK_ENV']` reads. HMAC-signed tokens are **single-use** within their TTL (R-P8) via an in-process nonce cache.
- **Gateway selection**: same allowlist. `environment in {development, test}` → `LocalGateway`; anything else → AWS `Gateway` (which fails loudly on missing S3 config). Frontend code is identical across environments — it form-POSTs to whatever URL the presign response returns.
- **Mapper**: Generic constraint encoder. Takes `allowed_types` + `MAX_SIZE_BYTES` (from `limits.rb`) → emits presigned POST policy fields. Reusable for the future course-materials feature.
- **SubmissionMapper**: Submission-specific key construction from `assignment_id`, `requirement_id`, `account_id`, `extension`. Called by `IssueUploadUrls` (builds keys from authenticated context to return in presign response) and by `CreateSubmission` (reconstructs keys to HEAD-check; ignores any client-supplied key per R-P2).

### Orphaned File Cleanup

If the browser uploads to S3 but the confirm step fails (network issue, user closes tab), the file is orphaned. Orphans are rare and harmless — capped at `MAX_SIZE_BYTES` each and naturally overwritten on resubmit (deterministic keys per R2). A second orphan source is extension-change cleanup: `CreateSubmission` deletes the old-extension S3 object after persisting the new entry, but per R-P6 that delete is **best-effort outside the DB transaction** — a delete failure logs and proceeds rather than rolling back a valid submission. Both orphan classes are bounded and accepted per R9. No automated cleanup needed. Deferred: on-demand reconciliation for teaching staff to cross-validate S3 against DB for a given assignment.

### CORS Configuration

The S3 bucket requires CORS configuration to allow direct browser uploads from the application's origin(s).

---

Last updated: 2026-04-24 (Slice 3 second pre-implementation review: upload flow is presigned **POST** with signed policy; server **reconstructs** S3 keys server-side and ignores client-supplied keys; download flow is a backend **302-redirect endpoint** (supersedes render-time presigned URLs); LocalGateway uses allowlist env guard + single-use HMAC tokens + splat route; `content_type` flagged as untrusted display metadata; `limits.rb` holds `MAX_SIZE_BYTES` as single source of truth. Full rationale in `PLAN.assignments-design-decisions.md` R-P1 … R-P11.)
