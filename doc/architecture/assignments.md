# Assignments

> Authoritative definition of the Assignments bounded context — domain model, persistence, and file-storage infrastructure. For the rationale behind these choices, see [Design Decisions](decisions/assignments.md).

## Bounded Context

Sits alongside Accounts, Courses, Attendance, and Shared. References other contexts by ID only — no direct entity imports across boundaries.

## Aggregate Roots

### Assignment

A task assigned to students within a course. Created by teaching staff. Has a `draft` → `published` → `disabled` lifecycle (one-way transitions).

#### Entity: Assignment

| Attribute              | Type                              | Notes                                                      |
|------------------------|-----------------------------------|------------------------------------------------------------|
| id                     | Integer, optional                 | PK, nil before persistence                                 |
| course_id              | Integer                           | FK → courses (required)                                    |
| event_id               | Integer, optional                 | FK → events (nullable, must reference an event in the same course) |
| title                  | AssignmentTitle (constrained)     | Required, max 200 chars                                    |
| description            | String, optional                  | Markdown content                                           |
| status                 | AssignmentStatus                  | Enum: `draft`, `published`, `disabled` (default: `draft`)  |
| due_at                 | Time, optional                    | Stored UTC, displayed in user's local timezone             |
| allow_late_resubmit    | Bool                              | Default: `false`                                           |
| created_at             | Time, optional                    |                                                            |
| updated_at             | Time, optional                    |                                                            |
| submission_requirements| SubmissionRequirements, optional  | Typed collection; `nil` = not loaded                       |

#### Child Entity: SubmissionRequirement

One required piece of a submission (e.g., "R Markdown source" or "GitHub repo link"). Belongs to Assignment — loaded and saved through the Assignment aggregate.

| Attribute         | Type                | Notes                                                                                  |
|-------------------|---------------------|----------------------------------------------------------------------------------------|
| id                | Integer, optional   | PK                                                                                     |
| assignment_id     | Integer             | FK → assignments                                                                       |
| submission_format | RequirementType     | Enum: `file`, `url`                                                                    |
| description       | String              | e.g., "R Markdown source file"                                                         |
| allowed_types     | String, optional    | Comma-separated extensions, e.g., `.Rmd,.qmd`. Only meaningful for `submission_format='file'`. |
| sort_order        | Integer             | Display ordering                                                                       |
| created_at        | Time, optional      |                                                                                        |
| updated_at        | Time, optional      |                                                                                        |

**Value Object: SubmissionRequirements** (typed collection)

Wraps an array of `SubmissionRequirement` entities. Follows the Events / Locations / Enrollments pattern (`Dry::Struct`, includes `Enumerable`, `.from()` constructor).

### Submission

A student's submission for an assignment. One submission per student per assignment (overwrite model).

#### Entity: Submission

| Attribute           | Type                            | Notes                                              |
|---------------------|---------------------------------|----------------------------------------------------|
| id                  | Integer, optional               | PK                                                 |
| assignment_id       | Integer                         | FK → assignments                                   |
| account_id          | Integer                         | FK → accounts (the student)                        |
| submitted_at        | Time                            | When the submission was made or last overwritten   |
| created_at          | Time, optional                  |                                                    |
| updated_at          | Time, optional                  |                                                    |
| requirement_uploads | RequirementUploads, optional    | Typed collection; `nil` = not loaded               |

#### Child Entity: RequirementUpload

One entry per submission requirement fulfilled. Belongs to Submission — loaded and saved through the Submission aggregate.

| Attribute      | Type              | Notes                                                                                       |
|----------------|-------------------|---------------------------------------------------------------------------------------------|
| id             | Integer, optional | PK                                                                                          |
| submission_id  | Integer           | FK → submissions                                                                            |
| requirement_id | Integer           | FK → submission_requirements                                                                |
| content        | String            | Polymorphic per `submission_format`: an S3 key when `'file'`, a raw URL string when `'url'`. |
| filename       | String, optional  | Original filename (file uploads only). Untrusted display metadata.                          |
| content_type   | String, optional  | MIME type (file uploads only). Untrusted display metadata — client-asserted, never used as a security signal. |
| file_size      | Integer, optional | Bytes (file uploads only). Capped at `Tyto::FileStorage::MAX_SIZE_BYTES` (10 MB).           |
| created_at     | Time, optional    |                                                                                             |
| updated_at     | Time, optional    |                                                                                             |

**Value Object: RequirementUploads** (typed collection)

Wraps an array of `RequirementUpload` entities. Same pattern as `SubmissionRequirements`.

## Domain Types

Additions to `types.rb`:

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
========================            ========================

Course ──────────────────────────→  Assignment (aggregate root)
  (course_id FK)                      ├─ SubmissionRequirement (child, 1:many)
                                      │
Event ───────────────────────────→  Assignment (optional event_id FK)
  (event_id FK, nullable)             │
                                      │
Accounts context (external)         Submission (aggregate root)
========================              ├─ RequirementUpload (child, 1:many)
                                      │     └─ requirement_id FK → SubmissionRequirement
Account ─────────────────────────→  Submission
  (account_id FK)                     (one per student per assignment)
```

## Database Tables

### `assignments`

```sql
assignments
  id                  (PK, auto-increment)
  course_id           (FK → courses, NOT NULL)
  event_id            (FK → events, nullable)
  title               (String, NOT NULL)
  description         (Text, nullable)
  status              (String, NOT NULL, default: 'draft')
  due_at              (DateTime, nullable)
  allow_late_resubmit (Boolean, NOT NULL, default: false)
  created_at          (DateTime)
  updated_at          (DateTime)
```

### `submission_requirements`

```sql
submission_requirements
  id                (PK, auto-increment)
  assignment_id     (FK → assignments, NOT NULL)
  submission_format (String, NOT NULL)        -- 'file' or 'url'
  description       (String, NOT NULL)
  allowed_types     (String, nullable)        -- e.g., ".Rmd,.qmd,.pdf"
  sort_order        (Integer, NOT NULL, default: 0)
  created_at        (DateTime)
  updated_at        (DateTime)
```

### `submissions`

```sql
submissions
  id            (PK, auto-increment)
  assignment_id (FK → assignments, NOT NULL)
  account_id    (FK → accounts, NOT NULL)
  submitted_at  (DateTime, NOT NULL)
  created_at    (DateTime)
  updated_at    (DateTime)

  UNIQUE(assignment_id, account_id)  -- one submission per student per assignment
```

### `submission_entries`

```sql
submission_entries
  id             (PK, auto-increment)
  submission_id  (FK → submissions, NOT NULL)
  requirement_id (FK → submission_requirements, NOT NULL)
  content        (String, NOT NULL)   -- S3 key when submission_format='file'; raw URL when 'url'
  filename       (String, nullable)   -- original filename (files only)
  content_type   (String, nullable)   -- MIME type (files only)
  file_size      (Integer, nullable)  -- bytes (files only)
  created_at     (DateTime)
  updated_at     (DateTime)
```

## Key Domain Rules

1. **Assignment lifecycle**: `draft` → `published` → `disabled`. All transitions are one-way. Students see only `published` assignments; teaching staff see all. `disabled` hides an assignment from students without deleting data — use it instead of deletion when submissions exist. "Closed" (not accepting submissions) is not a stored state — it's derived at read time from `due_at`, `allow_late_resubmit`, and whether the student has an existing submission.

2. **Overwrite model**: One submission per student per assignment, enforced by the unique constraint. Resubmitting overwrites existing entries (upsert per requirement, matched by `(submission_id, requirement_id)`).

3. **Late submission policy**: First-time late submissions are always accepted. `allow_late_resubmit` (default `false`) controls whether resubmission is allowed after the deadline. When `false`, any resubmission after `due_at` is blocked — regardless of whether the existing submission was on-time or late.

4. **Late / on-time derived**: No stored status. Compare `submission.submitted_at` against `assignment.due_at` at read time. Assignments without `due_at` have no late concept.

5. **Submission visibility**: Students see only their own submissions. Teaching staff see all submissions for an assignment.

6. **File validation**: Uploaded file extension is validated against `submission_requirement.allowed_types`. Size capped at `Tyto::FileStorage::MAX_SIZE_BYTES` (10 MB). No system-wide allowlist — constraints are per-requirement.

7. **Event association**: Optional. An event can have multiple assignments. An assignment's `event_id` must reference an event in the same course (validated in the service layer).

## Repository Loading Patterns

Composable loading following the pattern established by `CoursesRepository`.

**`AssignmentRepository`**:

- `find_id(id)` — Assignment only (requirements = nil)
- `find_with_requirements(id)` — Assignment + SubmissionRequirements
- `find_by_course(course_id)` — All assignments for a course
- `find_by_course_and_status(course_id, status)` — Assignments filtered by status (called with `'published'` for students)
- `find_by_course_with_requirements(course_id)` — All assignments + their requirements

**`SubmissionRepository`**:

- `find_by_account_assignment(account_id, assignment_id)` — A single student's submission
- `find_by_account_assignment_with_entries(account_id, assignment_id)` — With entries loaded
- `find_by_assignment(assignment_id)` — All submissions for an assignment (teaching staff)
- `find_by_assignment_with_entries(assignment_id)` — All submissions + entries

## File Storage Infrastructure

Direct-to-S3 uploads via presigned URLs. The backend never proxies file bytes — it generates short-lived presigned credentials, and the browser uploads directly to S3. Offloads upload work to clients and avoids tying up Ruby processes.

In `development` and `test`, an interface-compatible `LocalGateway` writes to the filesystem instead. See [doc/s3.md](../s3.md) for production setup.

### Upload Flow

```text
┌──────────┐  1. POST /upload_grants        ┌──────────┐
│  Vue.js  │ ──────────────────────────→   │   Roda   │
│ Frontend │  ←──────────────────────────  │ Backend  │
│          │  2. POST URL + signed fields  │          │
│          │                               └──────────┘
│          │  3. multipart form-POST        ┌────────┐
│          │ ──────────────────────────→   │   S3   │
│          │  4. Success / failure         │        │
│          │  ←──────────────────────────  │        │
└──────────┘                                └────────┘
            5. POST /submissions
               (filename + metadata only)
               → backend reconstructs key + HEAD
```

**Steps 1–2 (presign)**: `POST /api/course/:course_id/assignments/:assignment_id/upload_grants` validates the request (authorization; file extension against the requirement's `allowed_types`) and generates a presigned **POST** URL with constraints baked into a signed policy document (`content-length-range: [1, MAX_SIZE_BYTES]`, `key` equality). S3 enforces the policy server-side. Presigned PUT is rejected because `Content-Length` would be unsigned. Response: an array of `{requirement_id, key, upload_url, fields}` — the `fields` hash carries the signed policy, signature, and AWS form-POST fields the browser must include.

**Steps 3–4 (upload)**: Browser sends each file as multipart form-POST to `upload_url`, submitting `fields` alongside the file. S3 rejects uploads that violate the policy. The frontend can show native progress events.

**Step 5 (confirm)**: Frontend sends `POST /submissions` with only `{requirement_id, filename, content_type, file_size}` per file-type entry — **no key**. Backend reconstructs the S3 key server-side from `(route course_id + route assignment_id + body requirement_id + authenticated account_id + extension from the filename)`, HEAD-checks the reconstructed key, and persists the `requirement_upload` record. Client-supplied keys are ignored — prevents one student from referencing another student's S3 key as their own submission.

### Download Flow

`GET /api/course/:course_id/assignments/:assignment_id/submissions/:submission_id/uploads/:upload_id/download` authorizes the requestor, mints a fresh presigned GET (15 min TTL), and 302-redirects. The browser follows the redirect; bytes stream directly from S3 to the client.

The representer emits `download_url` as a link to *this* backend route, **not** a presigned S3 URL — avoids the silent-staleness problem where a long-open staff view holds URLs past their TTL. Each click mints a fresh URL.

### S3 Key Pattern

`<course_id>/<assignment_id>/<requirement_id>/<account_id>.<extension>`

- No `submission_id` in the key — avoids a chicken-and-egg with persistence (the key is computed before the submission row exists).
- `course_id` at the top so an operator can browse a course's uploads in the AWS console by prefix without a DB lookup.
- `requirement_id` before `account_id` groups all student uploads per requirement for batch download.
- Fully computable from IDs + extension — no stored filename needed.

Key construction lives in `SubmissionMapper` and is used by **both** the presign service (to build keys from authenticated context) and `CreateSubmission` (to reconstruct and verify keys).

URL-type entries do not get S3 keys — they're stored as raw strings in the `content` column. The `submission_format` column on the requirement disambiguates.

On resubmit with a changed extension (file-type only): persist the new entry inside the DB transaction, then call `Gateway#delete(old_key)` outside the transaction. The delete is best-effort — log and swallow failures so an S3 blip doesn't roll back a valid submission.

### Gateway / Mapper Layout

Follows the existing `auth_token` and `sso_auth` infrastructure patterns:

```text
infrastructure/
  file_storage/
    gateway.rb           # Raw AWS SDK calls (presign_upload, presign_download, head, delete)
    local_gateway.rb     # Filesystem adapter for dev/test
    mapper.rb            # Generic constraint encoding (max size, allowed types → POST policy conditions)
    submission_mapper.rb # Submission-specific key construction
    limits.rb            # MAX_SIZE_BYTES — single source of truth
```

- **Gateway**: I/O boundary with AWS. `presign_upload(key, constraints)` returns a presigned **POST** (URL + signed `fields` hash); plus `presign_download(key)`, `head(key)`, `delete(key)`. Uses `aws-sdk-s3`. Returns `Success` / `Failure`.
- **LocalGateway**: Same interface for `development` and `test`. Stores files at `LOCAL_STORAGE_ROOT/<key>`. Exposes `POST /api/_local_storage/upload` (form-POST receiver) and `GET /api/_local_storage/download/*key` (splat for the multi-segment key). The route branch is mounted only when `Tyto::Api.environment.in?(%i[development test])` — an allowlist, not a denylist, so future `staging` / `preview` / `ci` environments don't silently mount dev-only routes. Source of truth for the environment is Roda's `:environments` plugin (enabled in `backend_app/config/environment.rb`); no ad-hoc `ENV['RACK_ENV']` reads. HMAC-signed tokens are single-use within their TTL via an in-process nonce cache.
- **Gateway selection**: same allowlist. Environment in `{development, test}` → `LocalGateway`; anything else → AWS `Gateway` (fails loudly on missing S3 config). Frontend code is identical across environments — it form-POSTs to whatever URL the presign response returns.
- **Mapper**: Generic constraint encoder. Takes `allowed_types` + `MAX_SIZE_BYTES` (from `limits.rb`) and emits presigned-POST policy fields. Reusable for the future course-materials feature.
- **SubmissionMapper**: Submission-specific key construction from `course_id`, `assignment_id`, `requirement_id`, `account_id`, `extension`. Called by `IssueUploadGrants` (builds keys from authenticated context for the presign response) and by `CreateSubmission` (reconstructs keys to HEAD-check; ignores any client-supplied key).

### Orphaned File Cleanup

If the browser uploads to S3 but the confirm step fails (network blip, user closes the tab), the S3 object is orphaned. Orphans are rare and harmless — capped at `MAX_SIZE_BYTES` each, and naturally overwritten on resubmit thanks to deterministic keys.

A second orphan source is extension-change cleanup: `CreateSubmission` deletes the old-extension S3 object after persisting the new entry, but that delete is best-effort and runs outside the DB transaction — a delete failure logs and proceeds rather than rolling back a valid submission.

Both orphan classes are bounded and accepted. No automated cleanup runs.

Deferred: an on-demand reconciliation tool for teaching staff to cross-validate S3 against the DB for a given assignment.

### CORS

The S3 bucket requires CORS configuration to allow direct browser uploads from the application's origin(s). Production setup steps live in [doc/s3.md](../s3.md).
