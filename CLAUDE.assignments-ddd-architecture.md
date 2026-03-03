# Assignments Domain Model

> Referenced from `CLAUDE.feature-assignments.md`. This is the authoritative definition of the Assignments bounded context domain model.

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
| content        | String            | Always an S3 key (R2: unified storage — URLs stored as `.url` files in S3) |
| filename       | String, optional  | Original filename (file uploads only)          |
| content_type   | String, optional  | MIME type (file uploads only)                  |
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
  content         (String, NOT NULL)          -- Always S3 key (R2: URLs stored as .url files)
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
┌──────────┐  1. Request presigned URL    ┌──────────┐
│  Vue.js  │ ──────────────────────────→  │   Roda   │
│ Frontend │  ←────────────────────────── │ Backend  │
│          │  2. Return presigned URL     │          │
│          │     (with constraints)       └──────────┘
│          │  3. PUT file directly          ┌────────┐
│          │ ────────────────────────────→  │   S3   │
│          │  4. Success/failure            │        │
│          │  ←──────────────────────────── │        │
└──────────┘                               └────────┘
            5. Confirm upload to backend
               (save metadata in DB)
```

**Step 1–2 (presign)**: Backend validates the request (authorization, file extension against requirement's `allowed_types`), then generates a presigned POST URL with constraints baked in (`content_length_range: 1..10_485_760`). S3 enforces size limits server-side.

**Step 3–4 (upload)**: Browser uploads directly to S3. Frontend can show native progress events.

**Step 5 (confirm)**: Frontend sends the S3 key and metadata to the backend. Backend verifies the object exists in S3 (via HEAD), persists the `requirement_upload` record (DB table: `submission_entries`).

### Download Flow

Backend generates a presigned GET URL → Frontend redirects/downloads. File bytes never touch the backend.

### S3 Key Pattern

`<assignment_id>/<requirement_id>/<account_id>.<extension>`

No `submission_id` in key (R2: avoids chicken-and-egg with persistence). `requirement_id` before `account_id` groups all student uploads per requirement for batch download. Key is fully computable from IDs + extension — no stored filename needed. URL entries stored as `.url` files for unified storage. On resubmit with changed extension: read old extension from DB → delete old S3 object → upload new → update DB.

### Gateway/Mapper Pattern

Follows the existing `auth_token` and `sso_auth` infrastructure patterns:

```text
infrastructure/
  file_storage/
    gateway.rb          # Raw AWS SDK calls (presign_upload, presign_download, head, delete)
    local_gateway.rb    # Filesystem adapter for dev/test (accepts direct upload)
    mapper.rb           # Domain concepts ↔ S3 concepts (key construction, constraint encoding)
```

- **Gateway**: Raw I/O boundary with AWS. `presign_upload(key, constraints)`, `presign_download(key)`, `head(key)`, `delete(key)`. Uses `aws-sdk-s3` gem. Returns `Success`/`Failure`.
- **LocalGateway**: Same interface for dev/test. Stores files on local filesystem. Frontend detects local mode and uploads to backend directly (no S3/CORS needed in development).
- **Mapper**: Translates domain vocabulary to S3 vocabulary. Takes requirement's `allowed_types` and max file size → encodes as presigned URL constraints. Constructs S3 key from `assignment_id`, `requirement_id`, `account_id`, `extension` (R2). Services inject the Mapper, never the Gateway.

### Orphaned File Cleanup

If the browser uploads to S3 but the confirm step fails (network issue, user closes tab), the file is orphaned. Orphans are rare and harmless — capped at 10MB each and naturally overwritten on resubmit (deterministic keys). No automated cleanup needed. Deferred: on-demand reconciliation for teaching staff to cross-validate S3 against DB for a given assignment.

### CORS Configuration

The S3 bucket requires CORS configuration to allow direct browser uploads from the application's origin(s).

---

Last updated: 2026-03-03 (reconciled with design decisions: R1 submission_format, R2 S3 key pattern + unified .url storage)
