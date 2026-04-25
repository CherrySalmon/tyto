# Feature: Assignments — Slice 3 (File Storage + File Uploads)

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`feature-assignments` (continues the branch that shipped Slices 1 and 2).

## Goal

Wire up file-upload support for submissions end-to-end via direct-to-S3 presigned URLs, with a local-filesystem gateway used in dev/test. After this slice, a student can upload a file (e.g., `.Rmd`, `.pdf`) to fulfill a `submission_format: 'file'` requirement and a teaching-staff member can download it. Storage infrastructure is designed so a future course-materials feature can reuse the Gateway + shared constraints helpers without rework.

## Strategy: Vertical Slice (test-first, hard gate)

1. **Backend test (red)** — write failing tests for Mapper, LocalGateway, Gateway, gateway selection, presign/confirm routes. Run `bundle exec rake spec`. **Record the failure count on the task line before touching implementation.**
2. **Backend implementation (green)** — minimal code to pass. Re-run tests. Record pass count + total.
3. **Frontend update** — enable the currently-disabled file-type submission path; call presign → upload → submit.
4. **Verify** — Claude-in-Chrome walkthrough with a real two-account scenario (staff + student). Manual pass by developer before PR.

> **TDD HARD GATE — NON-NEGOTIABLE**
>
> Slices 1 and 2 both had repeated violations where tests and implementation were written together. Every backend task marked with 🚦 below requires:
>
> 1. Write test file(s) **only** — reference classes/methods that do not exist.
> 2. Run `bundle exec rake spec` — confirm failures. Record `red: NF` on the task line. **STOP. Do not proceed until the red count is recorded.**
> 3. Only then write implementation.
> 4. Re-run tests. Record `green: NP, total T`.
>
> No exceptions. "The shape was obvious" is not an exception.

## Reference Documents

| Document | Role in Slice 3 | Disposition |
|----------|-----------------|-------------|
| `PLAN.assignments-ddd-architecture.md` | Source of truth for Gateway/Mapper/LocalGateway design, S3 key pattern, upload flow, CORS | **Keep** — implemented by this slice |
| `PLAN.assignments-design-decisions.md` | Resolved Q3 (S3), R2 (key pattern + `.url` files), R9 (orphans), R10 (presign response), Q-B (`.url` format), R-P1 … R-P11 | **Keep** — gated decisions for this slice |

### Doc Retention Decision

- **Slices 1–2 history retired.** `CLAUDE.feature-assignments-1-2.md` (the previous plan/history file) was deleted in the same commit as this rename — the detailed task state, pain-points table, and merge log no longer inform ongoing work, and Slice 2's context is captured in commit messages + the PR body that will land on merge.
- **Keep both architecture and design-decisions docs as active references** during Slice 3. The architecture doc literally describes what this slice implements (Gateway/Mapper/LocalGateway paths, S3 key pattern, upload/download flows, CORS). The design-decisions doc pins the semantics (un-unified storage per Q3, key format without `submission_id`, no `pending/` prefix, dev/prod URL parity, R-P1 … R-P11). Both stay compact and don't need folding into this plan.
- **Do not duplicate architecture content in this plan.** Refer to the architecture doc sections by name (e.g., "Mapper per `PLAN.assignments-ddd-architecture.md` → Gateway/Mapper Pattern") rather than restating them.

## Current State

- [x] Plan created
- [x] Slices 1 and 2 complete (assignments + submissions backend, frontend, verification, review fixes 2.10a–2.10e all closed)
- [x] Current test state: 1205 tests / 0 failures / 0 errors / 1 skip / 98.31% coverage (post-2.10d)
- [x] Current submission behavior: `content` column stays polymorphic (S3 key for file-type, raw URL for URL-type), disambiguated by `submission_format` — revisited R2/Q-B, see Q3 decision below
- [x] Q1 resolved (batched presign at Submit, A1 flow) — 2026-03-02
- [x] Q2 resolved (single `POST .../submissions` endpoint with HEAD-check inside `CreateSubmission`; presign route moved to `POST .../assignments/:aid/upload_urls` for REST cleanliness) — 2026-03-02
- [x] Q3 resolved (un-unify storage — URLs stay as strings, only files go to S3; R2/Q-B revisited) — 2026-03-02
- [x] Q4 resolved (LocalGateway: Option A — presign returns signed local URL; route branch mounted only when `RACK_ENV != 'production'`) — 2026-03-02
- [x] Q5 resolved (Option A — presigned GET for file-type; URL-type rendered as plain `<a>` link; revisit post-3.21 if audit/runtime-check needs surface) — 2026-03-02 (**superseded by R-P4 on 2026-04-24 — download goes via a backend redirect endpoint, not a representer-rendered presigned URL**)
- [x] All Q1–Q5 resolved; 3.0f applied — 2026-03-02
- [x] Pre-implementation review refinements (R-P1 … R-P11) recorded as Phase 0.5 — 2026-04-24
- [ ] Backend tests + implementation (Mapper, LocalGateway, Gateway, selection, `limits.rb`, upload-urls service + route, download redirect route, `CreateSubmission` updates, representer `download_url`)
- [ ] Frontend file-upload UI (enable the file-format path, form-POST direct, confirm; download via backend redirect)
- [ ] Integration test (R-P11) covering the full upload → submit → download path
- [ ] Chrome walkthrough verification
- [ ] S3 setup guide written

## Key Findings

### What's already in place

- `Domain::Assignments::Entities::RequirementUpload` carries `content`, `filename`, `content_type`, `file_size`. The domain model is already file-shaped.
- `Application::Services::Submissions::CreateSubmission` validates filename / file_size / extension for `submission_format == 'file'` (see `backend_app/app/application/services/submissions/create_submission.rb:88`). It just doesn't verify that the file actually exists in storage yet — the service treats `content` as an opaque string.
- `frontend_app/components/FileUpload.vue` already exists in the codebase — candidate for reuse or light adaptation.
- Routes for submissions are mounted under `/api/course/:course_id/assignments/:aid/submissions` in `course.rb:327–365`. Adding `POST .../presign` is a drop-in.
- No `aws-sdk-s3` gem, no `infrastructure/file_storage/` directory, no presign endpoint — this slice builds that from zero.

### What needs a behavioral change

- **File requirement uploads only** (URL-type behavior unchanged from Slice 2). `content` is polymorphic per `submission_format`: S3 key when `submission_format = 'file'`, raw URL string when `submission_format = 'url'`. Document the semantics on the entity + column.
- **Submission service**: for file-type entries, the service verifies the S3 key exists (HEAD) before persisting; extension is derived from the key. URL-type entries bypass storage entirely — stored and returned as strings, same as Slice 2.

### Pattern to follow

- Two existing infrastructure boundaries use the Gateway + Mapper split cleanly: `infrastructure/auth/auth_token/` (gateway = RbNaCl; mapper = JWT claims ↔ `AuthCapability`) and `infrastructure/auth/sso_auth/` (gateway = Google HTTP; mapper = Google payload ↔ domain fields). Slice 3 adds a third: `infrastructure/file_storage/`.

### Generic-first design for future reuse

A course-materials feature is planned (instructor/staff uploads attached to courses / weeks / assignments with public vs. staff-only visibility). The Gateway + shared constraints layer must stay generic. **Submission-specific vocabulary (key pattern, allowed_types sourced from SubmissionRequirement) belongs in a submission mapper that layers on top of the generic mapper.** Keep the seam:

- `file_storage/gateway.rb`, `local_gateway.rb` — generic `presign_upload(key, constraints)`, `presign_download(key)`, `head(key)`, `delete(key)`. No direct-write method — the backend only uses the gateway for client-mediated flows (presign) plus read/verify/cleanup.
- `file_storage/constraints.rb` (or a helper in `mapper.rb`) — generic encoding of max size + allowed extensions → presigned POST conditions.
- **Submission key construction** (`<assignment_id>/<requirement_id>/<account_id>.<ext>`) lives in either a dedicated `infrastructure/file_storage/submission_mapper.rb` or inside the submissions repository. Not in the generic gateway.
- Gateway selector (env → LocalGateway in dev/test, Gateway in production) is generic.

## Questions

> Resolve these before task 3.1a. Cross off with the decision chosen; keep rejected alternatives visible.

- [x] ~~**Q1: Presign endpoint granularity.** One presign call per file, or one batched presign call for the whole submission?~~
  - ~~Option A: `POST /api/course/:course_id/assignments/:aid/submissions/presign` — body lists `[{requirement_id, filename}, ...]`, response returns an array of `{requirement_id, upload_url, key, fields}`.~~
  - ~~Option B: `POST .../submissions/presign/:requirement_id` — one call per file. More HTTP round-trips but simpler route.~~
  - ~~Option C: embed presign fetching into a submission "draft" object the frontend builds up progressively.~~
  - **Decision: Option A — batched presign at Submit click** (2026-03-02). Form holds `File` refs locally (cheap — refs, not bytes) until user clicks Submit. Submit then orchestrates: presign batch → parallel PUTs to S3 → single POST `/submissions` with keys. Presign happens seconds before upload, so TTL is never an issue. Nothing lands in S3 until Submit, so Cancel = no orphans. See "Failure Recovery" below for retry semantics.

- [x] ~~**Q2: Confirm step design.** Where does S3-existence verification happen?~~
  - ~~Option A: reuse `POST .../submissions` (the existing Slice 2 endpoint) and add HEAD-checks inside `CreateSubmission`. One endpoint, internal verification.~~
  - ~~Option B: add a dedicated `POST .../submissions/confirm` endpoint. Separates presign → upload → confirm cleanly.~~
  - **Decision: Option A — single `POST .../submissions` endpoint** (2026-03-02). `CreateSubmission` gets HEAD-check + URL-to-`.url` materialization + extension-change cleanup as internal steps. The HEAD-check is validation (alongside auth + input validation), not a separate responsibility. No routing split; no two-endpoint orchestration; confirm stays atomic with persistence. Presign route moved to `POST /api/course/:course_id/assignments/:assignment_id/upload_urls` (not under `/submissions/presign`) — upload URLs are a resource, the path stays all-nouns, and the `/submissions/:id` slot is not polluted by an action name. Future course-materials feature can use the same `/upload_urls` pattern scoped to its own resource.

- [x] ~~**Q3: URL-type behavior.** When does URL-to-`.url` file materialization happen?~~
  - ~~Option A: frontend constructs the `.url` body, calls presign for it, uploads like any file.~~
  - ~~Option B: backend materializes the `.url` file inline during `POST .../submissions` for URL-type requirements. Frontend only sends the URL string.~~
  - **Decision: revisit R2 / Q-B — un-unify storage** (2026-03-02). Both original options were solving a problem we shouldn't have. URLs stay as raw strings in the `content` column (current Slice 2 behavior); only file-type entries go to S3. The `content` column is polymorphic, disambiguated by the sibling `submission_format` field on the requirement (tagged union). Rationale: (a) "store things in their natural form" — URLs are text, files are blobs; (b) YAGNI — unified storage solved no concrete need and added a write path the gateway doesn't otherwise need; (c) bulk download would re-process `.url` files into a manifest CSV anyway, so R2/Q-B's write-time materialization was wasted; (d) `.url` format is platform-biased (Windows-only clickable). See `PLAN.assignments-design-decisions.md` for the revised R2/Q-B entry.

- [x] ~~**Q4: LocalGateway endpoint shape.** What does the presign response return in dev?~~
  - ~~Option A: a local URL like `http://localhost:9292/api/_local_storage/upload?key=...&token=...` with a signed single-use token. Frontend PUTs to it directly, backend writes the bytes to the filesystem.~~
  - ~~Option B: no upload URL in dev — frontend sends file bytes in the submission POST, backend writes them. (Breaks parity with prod flow.)~~
  - **Decision: Option A with dev-only route mounting** (2026-03-02). Presign response returns a local URL; frontend PUTs directly to it; backend writes to `LOCAL_STORAGE_ROOT/<key>`. The entire `r.on '_local_storage'` branch in the Roda route tree is guarded by `Tyto::App.environment != 'production'` — the route literally doesn't exist in prod, so it can't be accidentally shipped. Defense in depth: (a) env guard on the route branch; (b) HMAC signed token (key + expiry) required even in dev; (c) `LOCAL_STORAGE_ROOT` chrooted to a specific directory (e.g., `backend_app/tmp/local_storage/`) so filesystem traversal is blocked. Frontend code is identical across environments — it just PUTs to whatever URL the presign response hands it.

- [x] ~~**Q5: Download path.** How do staff download student uploads?~~
  - ~~Option A: backend always generates a presigned GET (prod: S3 URL; dev: signed local download URL). Frontend navigates/downloads.~~
  - ~~Option B: backend proxies file bytes for both modes.~~
  - **Decision: Option A — presigned GET for file-type entries only** (2026-03-02). Post-Q3 un-unifying, Q5 applies only to files: `Representer::RequirementUpload` emits a short-lived `download_url` (prod: S3 presigned GET; dev: signed local download URL) when the requestor is permitted to view. URL-type entries need nothing from the gateway — the raw URL in `content` is rendered as a clickable `<a>` link (Slice 2 behavior). Revisit after 3.21 verification if we see real needs for download auditing / extra runtime checks (which would push toward B for a subset of use cases); noted in Deferrals.

  **Superseded by R-P4 (2026-04-24)**: pre-implementation review identified a UX hole — render-time presigned URLs silently expire on long-open staff views (TTL ≤ 15 min, typical staff workflow ≫ 15 min). Revised design: representer emits `download_url` pointing at a backend route that authorizes and redirects to a freshly-minted presigned GET. Option A's "Option B revisit" note is obsolete — the new design also provides the audit seam.

## Phase 0.5 — Pre-implementation refinements (2026-04-24)

> Codifies recommendations from the pre-implementation review of Phase 0 decisions. Each item ships as part of this slice — no further gating decisions before 3.1a. Each refinement is cross-referenced from the task lines it changes.

- **R-P1 — Presigned POST (not PUT).** Gateway + Mapper emit AWS presigned **POST** with a policy document carrying `content-length-range` and `key` equality conditions. Frontend uploads as multipart form-POST using the server-supplied `fields`. Rationale: presigned PUT cannot enforce size at S3 — `Content-Length` is a client-set header, unsigned. POST's policy doc is signed server-side and S3 rejects uploads that violate it. Overwrite semantics unchanged — S3 replaces at the same key for both PUT and POST, so deterministic-key idempotent retries still work exactly as the Failure Recovery matrix describes. Affects: 3.1a (Mapper emits policy fields), 3.1c (Gateway calls `presigned_post`), 3.5, 3.15/3.16 (frontend form-POST with fields).

- **R-P2 — Server reconstructs the S3 key; never trusts client-supplied keys.** `CreateSubmission` for file-type entries recomputes `<assignment_id>/<requirement_id>/<account_id>.<ext>` from (route `assignment_id` + body `requirement_id` + authenticated `account_id` + extension derived from the submitted `filename`). Any client-supplied `content` value for a file-type entry is ignored (or rejected). HEAD-checks the reconstructed key. Prevents a student from referencing another student's S3 key as their own submission. Affects: 3.8c (add explicit "rejects a body whose content points at another account's key" test), 3.11.

- **R-P3 — Environment gate is an allowlist, not a denylist.** LocalGateway route-branch mount and gateway selection guard on `Tyto::App.environment.in?(%w[development test])`, not `!= 'production'`. Future staging/preview/ci environments won't silently mount dev-only routes. Affects: 3.1d, 3.6, 3.8d, 3.12. Update design-decisions R10 revisit block to match.

- **R-P4 — Download via backend redirect endpoint, not render-time presigned URL.** Revises Q5. New route: `GET /api/course/:course_id/assignments/:assignment_id/submissions/:submission_id/uploads/:upload_id/download`. Handler authorizes the requestor via `Policy::Assignment#can_view_submission?` (or equivalent), mints a fresh presigned GET (15 min TTL), and 302-redirects. Representer emits `download_url` as a link to this backend route rather than a presigned URL directly. Solves: (a) silent URL staleness on long-open staff views; (b) download auditing seam for free. Affects: 3.8e (test shifts from representer-presigning to representer-link-building + a new route spec), 3.13 (add route handler), and a new red test for the download route (3.8e split into 3.8e-repr and 3.8e-route).

- **R-P5 — Route splat for the multi-segment local-storage key.** Key has three `/`-separated segments; Roda named params don't cross `/`. LocalGateway download route must use splat (`r.on "download" do r.is(/.+/) do |key| ... end end`) or base64url-encode the full key into a single segment. Pick splat for readability. Affects: 3.8d, 3.12.

- **R-P6 — Extension-change cleanup is best-effort.** `CreateSubmission` persists the new entry inside the DB transaction, then calls `Gateway#delete(old_key)` outside the transaction. A delete failure is logged and swallowed — the orphan is acceptable per R9, and an S3 blip must not roll back a valid submission. Commit this ordering in a comment on the service. Affects: 3.8c (add test: "delete failure is logged and does not affect the submission result"), 3.11.

- **R-P7 — Single source of truth for file-size limit.** Define `Tyto::FileStorage::MAX_SIZE_BYTES` (value: `10 * 1024 * 1024`) in one Ruby constant (likely `infrastructure/file_storage/limits.rb`). Referenced by: Mapper's policy-doc `content-length-range`, `CreateSubmission`'s Slice-2 validator, the representer (if it ever emits a limit hint), and a new lightweight endpoint or compile-time frontend constant. Decide frontend distribution during 3.18 — either `GET /api/config/file_storage_limits` (dynamic) or a build-time env var (static). Affects: 3.4 (introduce constant), 3.1a, 3.11, 3.18.

- **R-P8 — LocalGateway HMAC tokens are single-use within their TTL.** Token payload: `{key, op, exp, nonce}` signed with `LOCAL_STORAGE_SIGNING_KEY`. Backend tracks consumed `(nonce)` tuples in an in-process bounded cache (LRU with max ~10k entries) until their `exp`. Rejects replay. TTL: 15 min for upload, 5 min for download. Dev-only, so a simple in-process set is sufficient — no Redis. Affects: 3.8d (add "replayed token is rejected" test), 3.12.

- **R-P9 — `content_type` provenance and trust level.** Stored value is whatever the browser sent in the upload POST's `Content-Type` form field. Treat as **untrusted display metadata only** — never a security signal. Document this inline on the `RequirementUpload` entity. No server-side MIME sniffing in this slice. Affects: 3.8c (one test asserting client-sent value is persisted as-is), 3.11.

- **R-P10 — Service naming: `CreateUploadUrls` → `IssueUploadUrls`.** Reads closer to "mint credentials" than "persist a resource." Affects: 3.8a, 3.9 (file + class names), scope section, route handler's service call.

- **R-P11 — Integration test as an explicit task (3.14a).** Thin end-to-end test using Rack::Test that drives: `POST /upload_urls` → `POST` to `/_local_storage/upload` with returned fields → `POST /submissions` (with HEAD passing) → `GET /uploads/:id/download` → follow redirect → read bytes match. Catches Slice 2's P5 class of hybrid-layer bugs before 3.21 Chrome walkthrough. Not a substitute for unit tests. Affects: new 3.14a task line.

## Failure Recovery (Q1 A1 flow)

The A1 flow is safe under partial failure because S3 keys are deterministic per R2 (`<assignment_id>/<requirement_id>/<account_id>.<ext>`). Re-submitting always POSTs to the same key for the same (requirement, extension), and S3 overwrites at the same key by default (both presigned PUT and POST), so retries overwrite rather than accumulate.

**Applies to file-type entries only.** URL-type entries (Q3: un-unified) never touch S3 — they're plain-string columns, so they have no upload, no presign, no partial-failure state. The scenarios below are about the file-type half of a mixed submission.

**Failure scenarios and recovery**:

| Scenario | State after failure | What retry does | Orphan cost |
|----------|--------------------|-----------------|-------------|
| Confirm fails after all uploads succeed | S3 objects exist at deterministic keys; no DB row | User clicks Submit again → presign returns same keys → form-POSTs overwrite (same bytes, no-op effectively) → confirm succeeds | Zero |
| User retries with a different file, same extension | As above | Overwrites previous bytes at same key | Zero |
| User retries with a different file, different extension | Old-ext object stays; new-ext object written at new key | Confirm records the new key; old-ext object is orphaned | One capped-at-10MB object per extension-change |
| User abandons without retrying | S3 objects sit; no DB row | Nothing — invisible to app (DB is source of truth) | Per R9: acceptable |
| User double-clicks Submit (first confirm actually succeeded but frontend didn't hear) | DB has submission; S3 has keys | Second confirm hits the upsert path (unique on `assignment_id+account_id` from Slice 2) — overwrites itself | Zero |
| Partial upload failure (one of N files didn't land) | Some keys exist, some don't | Confirm's HEAD-check per entry rejects with a clear error → user clicks Submit again → failed uploads retried, successful ones overwritten | Zero (no DB row was created) |

**Requirements this imposes on implementation**:

1. **HEAD-check per entry in `CreateSubmission`** (Task 3.11) — non-negotiable. The service **reconstructs** the expected key from (route `assignment_id` + body `requirement_id` + authenticated `account_id` + extension from submitted filename) per R-P2, then HEAD-checks the reconstructed key. Client-supplied keys are ignored.
2. **Frontend keeps picked `File` refs on confirm failure** — form state must not reset on a failed `/submissions` POST. Tasks 3.15–3.19 must implement this explicitly.
3. **Error copy is precise**: "We couldn't save your submission. Please click Submit again — your uploaded files are safe." Not "Upload failed" (which implies re-pick).
4. **Confirm endpoint is already idempotent** — Slice 2's `CreateSubmission` upserts on `assignment_id + account_id`. Document this in the service comment so it's not undone by future work.
5. **Presign TTL ≥ 15 min** — gives the batch upload plenty of headroom on slow networks. Configured in the Gateway adapter (Task 3.5).
6. **Submit button UX**: single per-submission progress indicator ("Submitting… 2 / 5 uploaded"), disabled during in-flight work, re-enabled on error so retry is one click.

## Scope

### In scope

**Backend — infrastructure**:

- `Gemfile`: add `aws-sdk-s3`.
- `backend_app/app/infrastructure/file_storage/`:
  - `gateway.rb` — AWS adapter. `presign_upload(key, constraints)` returns presigned **POST** (URL + `fields` hash, per R-P1). Plus `presign_download(key)`, `head(key)`, `delete(key)`. Returns Success/Failure.
  - `local_gateway.rb` — filesystem adapter with the same interface. Presign emits a local URL the frontend form-POSTs to; backend writes bytes at `LOCAL_STORAGE_ROOT/<key>`. Single-use HMAC tokens per R-P8.
  - `mapper.rb` — generic constraints encoder (max size from R-P7 constant, allowed extensions → presigned POST policy conditions).
  - `submission_mapper.rb` (or method on submissions repo) — submission-specific key construction `<assignment_id>/<requirement_id>/<account_id>.<ext>`. Used by `IssueUploadUrls` to construct keys server-side and by `CreateSubmission` to reconstruct/verify keys (R-P2).
  - `limits.rb` — `MAX_SIZE_BYTES = 10 * 1024 * 1024` constant (R-P7). Single source of truth.
  - Gateway selection driven by `Tyto::App.environment.in?(%w[development test])` (R-P3).
- `config/secrets_example.yml` gains `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `LOCAL_STORAGE_ROOT` (dev/test only), `LOCAL_STORAGE_SIGNING_KEY` (dev/test only).
- Migration? **None needed** — the schema already carries `content`, `filename`, `content_type`, `file_size` on `submission_entries`.

**Backend — application**:

- New route: `POST /api/course/:course_id/assignments/:assignment_id/upload_urls` (upload URLs as a resource — keeps the path all-nouns and avoids colliding with the `/submissions/:id` slot). Guarded by `Policy::Assignment#can_submit?`.
- New route: `GET /api/course/:course_id/assignments/:assignment_id/submissions/:submission_id/uploads/:upload_id/download` (R-P4). Handler authorizes the requestor, mints a fresh presigned GET (15 min TTL) from the Gateway, and 302-redirects. Replaces the "representer emits presigned URL directly" model from Q5.
- New routes (LocalGateway only, mounted via `if Tyto::App.environment.in?(%w[development test])` in the Roda route tree — **allowlist per R-P3**, not `!= 'production'`): `POST /api/_local_storage/upload` (form-POST receiver per R-P1) and `GET /api/_local_storage/download/*key` (splat per R-P5 for the multi-segment key). Single-use HMAC-signed tokens per R-P8. Chrooted under `LOCAL_STORAGE_ROOT`.
- `CreateSubmission` service:
  - For **file-type** entries: ignore any client-supplied `content`; reconstruct the S3 key server-side from (route `assignment_id` + body `requirement_id` + authenticated `account_id` + extension from submitted filename) per R-P2; HEAD-check the reconstructed key; reject if missing.
  - On extension change during resubmit (file-type only): persist new entry inside the DB transaction first, then call `Gateway#delete(old_key)` outside the transaction — log and swallow delete failures per R-P6. URL-type resubmits overwrite the `content` string with no storage side effects.
  - `content_type` stored from the client-sent value; treated as untrusted display metadata (R-P9). Document on the entity.
- New service: `Application::Services::Assignments::IssueUploadUrls` (renamed from `CreateUploadUrls` per R-P10) — validates authorization via `can_submit?`, validates each requested upload against its requirement (file-type only, extension matches `allowed_types`, size encoded into presigned POST policy via R-P7's `MAX_SIZE_BYTES`), constructs keys via SubmissionMapper, calls Gateway, returns array of `{requirement_id, key, upload_url, fields}` keyed by `requirement_id`.
- Policy: `Policy::Assignment#can_submit?` already exists (added in 2.5a). Verify no change needed. Download route needs `can_view_submission?` — check existence / add if missing.
- Representer: `RequirementUploadRepr` surfaces `content` as-is (polymorphic by `submission_format`). For file-type entries, emits `download_url` as a **link to the backend download route** (R-P4), not a presigned S3 URL — authorization + presign happen when the user clicks. URL-type entries render `content` as a plain clickable link (Slice 2 behavior).

**Frontend**:

- `AssignmentDetailDialog.vue`: enable the file-type requirement path (currently disabled per Slice 2 note in `Slice 2 → Frontend → 2.6`). Wire it to `FileUpload.vue`.
- On submit: for file-type requirements, call `POST .../upload_urls` → **multipart form-POST** (not PUT, per R-P1) each file to its returned `upload_url` with the `fields` payload in parallel → send POST `/submissions` with only `{requirement_id, filename, content_type, file_size}` per entry. The backend reconstructs the S3 key from auth context (R-P2), so the frontend does not send `content` for file-type entries.
- On submissions table (staff view) and own-submission view: render download links as `<a href={requirement_upload.download_url}>` where `download_url` is the backend redirect route (R-P4). Browser follows the 302 on click — no staleness.
- Pre-upload UX: extension + size validation before calling presign. Size limit from R-P7's single source of truth — either fetched via `GET /api/config/file_storage_limits` or compiled in as a build-time env var (decide during 3.18).
- Error surfaces: failed upload → clear error toast; failed confirm → re-upload option. Error copy per Failure Recovery section.

**Setup guide**:

- `doc/s3.md` (or extend existing docs): AWS S3 bucket creation, IAM policy (least-privilege: PutObject, GetObject, HeadObject, DeleteObject on bucket path), CORS config JSON, setting `S3_*` secrets.

### Out of scope

- Orphaned-file reconciliation UI (R9 — defer).
- Virus scanning / content inspection.
- Thumbnails, previews, image transforms.
- Versioned storage (history of resubmits — Slice 2 overwrite model stands).
- Course-materials feature (uses this infrastructure later — not this branch).
- No migration of URL-type entries needed — the un-unified model (Q3) preserves Slice 2's string-in-`content` storage. File-type entries didn't exist in production yet (the path was UI-disabled), so no file backfill either.

## Tasks

> Check tasks off as soon as each one (or each grouped set) is finished. Do NOT batch multiple completions before updating this plan.

### Phase 0 — Decisions

- [x] 3.0a Q1 — batched presign at Submit (A1 flow) — 2026-03-02
- [x] 3.0b Q2 — single `POST .../submissions` for confirm; presign route moved to `POST .../assignments/:aid/upload_urls` — 2026-03-02
- [x] 3.0c Q3 — un-unify storage; URLs stay as strings, files to S3; R2/Q-B revisited — 2026-03-02
- [x] 3.0d Q4 — LocalGateway Option A with dev-only route mounting (env-guarded branch + HMAC token + chrooted root) — 2026-03-02
- [x] 3.0e Q5 — presigned GET for file-type entries; URL-type uses raw `content` as an `<a>` link; revisit after 3.21 — 2026-03-02
- [x] 3.0f Updated `PLAN.assignments-design-decisions.md` (revisit blocks appended to R2, R5, Q-B; extension block on R10; footer + header refreshed) **and** `PLAN.assignments-ddd-architecture.md` (revision banner at top; inline edits to the `content` column description in the entity table + DB schema; `.url` note reversed in the S3 key-pattern section; footer refreshed) — 2026-03-02. Original decision text preserved in both; revisit blocks document the reversal rationale with back-references to the plan.
- [x] 3.0g Pre-implementation refinements R-P1 … R-P11 recorded in Phase 0.5 — 2026-04-24. Covers: presigned POST (R-P1), server-reconstructed keys (R-P2), env allowlist (R-P3), backend download redirect (R-P4 — supersedes Q5 Option A rendering), route splat (R-P5), best-effort cleanup (R-P6), `MAX_SIZE_BYTES` constant (R-P7), single-use HMAC tokens (R-P8), `content_type` as untrusted (R-P9), service rename `Create` → `Issue` (R-P10), integration test task (R-P11).
- [x] 3.0h Mirrored R-P1 … R-P11 into research docs — 2026-04-24:
  - `PLAN.assignments-design-decisions.md`: R2 revisit block extended with R-P2 (server-reconstructs key) + R-P6 (best-effort cleanup). R10 extension block extended with R-P3 (allowlist) + R-P1 (POST not PUT) + R-P5 (splat) + R-P8 (single-use tokens). New top-level section "Slice 3 Pre-implementation Refinements (2026-04-24)" with R-P1, R-P4 (supersedes Q5 Option A), R-P7 (size constant), R-P9 (content_type trust), R-P10 (service rename), R-P11 (integration test).
  - `PLAN.assignments-ddd-architecture.md`: top revision banner updated with 2026-04-24 note. Entity table `content_type` row annotated as untrusted. Upload Flow ASCII diagram + step text rewritten for POST-with-fields and server-key-reconstruction. Download Flow rewritten as backend 302-redirect. S3 Key Pattern annotated with reconstruction + best-effort cleanup. Gateway/Mapper Pattern expanded to include `submission_mapper.rb`, `limits.rb`, allowlist env guard, single-use HMAC. Orphaned File Cleanup annotated with both orphan sources + R-P6. Footer refreshed.

### Phase 1 — Generic storage layer (backend)

> Test-first hard gate. Each red run must be recorded before implementation.

**Red (tests only)**:

- [ ] 🚦 3.1a Failing tests: `Mapper` — generic constraints encoding. Emits presigned **POST** policy doc fields per R-P1: `content-length-range: [1, MAX_SIZE_BYTES]` pulled from R-P7 constant, `key` equality condition, allowed extensions encoded as a `$Content-Type` or `starts-with` condition on key suffix. File: `backend_app/spec/infrastructure/file_storage/mapper_spec.rb`. **red: ___F**
- [ ] 🚦 3.1b Failing tests: `LocalGateway` — filesystem round-trip (`presign_upload` returns POST target + signed token → form-POST bytes to it → `head` → `presign_download` → read bytes → `delete`). Error cases: missing key, invalid path, expired token, **replayed token (R-P8)**. File: `backend_app/spec/infrastructure/file_storage/local_gateway_spec.rb`. **red: ___F**
- [ ] 🚦 3.1c Failing tests: `Gateway` — mocked `aws-sdk-s3` client for `presign_upload` (asserts it calls `bucket.presigned_post` with the Mapper's policy conditions), `presign_download`, `head`, `delete`. Error handling: S3 errors → `Failure`. File: `backend_app/spec/infrastructure/file_storage/gateway_spec.rb`. **red: ___F**
- [ ] 🚦 3.1d Failing tests: gateway selection — **allowlist per R-P3**: `Tyto::App.environment.in?(%w[development test])` → `LocalGateway`; any other value (including `'staging'`, `'production'`) → `Gateway`; missing S3 config when Gateway is selected raises. File: `backend_app/spec/infrastructure/file_storage/gateway_selection_spec.rb`. **red: ___F**
- [ ] 🚦 3.1e Failing tests: `SubmissionMapper` (or submissions-repo method) — key construction `<assignment_id>/<requirement_id>/<account_id>.<ext>` for file-type requirements; rejects URL-type (URLs don't get keys); rejects missing/invalid IDs or missing extension. Same method is used by `IssueUploadUrls` to build keys and by `CreateSubmission` to reconstruct keys (R-P2). File: `backend_app/spec/infrastructure/file_storage/submission_mapper_spec.rb`. **red: ___F**
- [ ] 🚦 3.1f Failing test: `Tyto::FileStorage::MAX_SIZE_BYTES` constant exists and equals `10 * 1024 * 1024` (R-P7). File: `backend_app/spec/infrastructure/file_storage/limits_spec.rb`. **red: ___F**

**Green (implementation)** — each blocked by its red run above:

- [ ] 🚦 3.2 `infrastructure/file_storage/mapper.rb` — **BLOCKED by 3.1a red**. **green: ___P, total ___**
- [ ] 🚦 3.3 `infrastructure/file_storage/local_gateway.rb` + `backend_app/config/storage.rb` wiring. Includes in-process nonce cache for single-use token enforcement (R-P8). **BLOCKED by 3.1b red**. **green: ___P, total ___**
- [ ] 3.4 Add `aws-sdk-s3` gem + S3 config entries in `secrets_example.yml` and `config/storage.rb`. Create `infrastructure/file_storage/limits.rb` with `MAX_SIZE_BYTES` (R-P7). *(No gate — config + constant only.)*
- [ ] 🚦 3.5 `infrastructure/file_storage/gateway.rb` — uses `bucket.presigned_post` for upload (R-P1). **BLOCKED by 3.1c red**. **green: ___P, total ___**
- [ ] 🚦 3.6 Gateway selection logic — allowlist per R-P3. **BLOCKED by 3.1d red**. **green: ___P, total ___**
- [ ] 🚦 3.7 `infrastructure/file_storage/submission_mapper.rb` — **BLOCKED by 3.1e red**. **green: ___P, total ___**
- [ ] 🚦 3.7a `infrastructure/file_storage/limits.rb` — **BLOCKED by 3.1f red**. Trivial file but subject to the TDD gate so the constant is grounded by a spec. **green: ___P, total ___**

### Phase 2 — Application integration (backend)

**Red (tests only)**:

- [ ] 🚦 3.8a Failing tests: `IssueUploadUrls` service (R-P10) — success path (returns `{requirement_id, key, upload_url, fields}` per entry); forbidden-for-non-submitter; unknown requirement; URL-type requirement rejected (file-type only); extension mismatch vs `allowed_types`; `content-length-range` policy field populated from R-P7's `MAX_SIZE_BYTES`; key constructed server-side from authenticated `account_id` (never accepts an `account_id` from the body). File: `backend_app/spec/application/services/assignments/issue_upload_urls_spec.rb`. **red: ___F**
- [ ] 🚦 3.8b Failing tests: `POST /api/course/:course_id/assignments/:assignment_id/upload_urls` route — 201 success (returns array of `{requirement_id, key, upload_url, fields}` — `fields` is a hash of form-POST fields per R-P1), 403 as wrong role, 400 on invalid body, 404 on missing assignment. File: `backend_app/spec/application/controllers/routes/assignments_upload_urls_route_spec.rb`. **red: ___F**
- [ ] 🚦 3.8c Failing tests: `CreateSubmission` file-type path —
  - HEAD-check passes against a **reconstructed** key (R-P2): test asserts the service rejects a submission whose body's inferred account doesn't match auth, and that the key used for HEAD is recomputed server-side from (route + body.requirement_id + auth.account_id + ext);
  - client-supplied `content` field for file-type entries is ignored (server trusts only filename + requirement_id);
  - missing S3 key → `bad_request`;
  - URL-type path persists `content` as raw string (no gateway call);
  - resubmit with changed file extension deletes old key via `Gateway#delete` **outside the DB transaction**; a `Gateway#delete` failure is logged and does NOT fail the submission (R-P6);
  - URL-type resubmit overwrites `content` with no storage side effects;
  - `content_type` from the client is persisted as-is (R-P9 — display metadata, not validated).

  Extend `backend_app/spec/application/services/submissions/create_submission_spec.rb`. **red: ___F**
- [ ] 🚦 3.8d Failing tests: LocalGateway HTTP endpoints (`POST /_local_storage/upload`, `GET /_local_storage/download/*key`) — valid signed token succeeds; bad/expired/missing token 401; replayed token (same nonce) 401 (R-P8); reads/writes match; path-traversal key rejected; multi-segment key served correctly via splat (R-P5); route branch returns 404 when environment is not in `{development, test}` (allowlist verification per R-P3). File: `backend_app/spec/application/controllers/routes/local_storage_route_spec.rb`. **red: ___F**
- [ ] 🚦 3.8e Failing tests: `Representer::RequirementUpload` emits `download_url` for file-type entries when the requestor is permitted to view — value is a **backend route path** (R-P4: `/api/course/.../uploads/:upload_id/download`), NOT a presigned S3 URL directly. Omits `download_url` for URL-type entries and when the requestor is not permitted. Extend existing representer spec. **red: ___F**
- [ ] 🚦 3.8f Failing tests: `GET /api/course/:course_id/assignments/:assignment_id/submissions/:submission_id/uploads/:upload_id/download` route (R-P4) — 302 redirect to a freshly-minted presigned GET when authorized; 403 when not; 404 when upload doesn't exist; 404 for URL-type uploads (no storage to redirect to); does not leak the presigned URL back to an unauthorized requestor. File: `backend_app/spec/application/controllers/routes/upload_download_route_spec.rb`. **red: ___F**

**Green (implementation)**:

- [ ] 🚦 3.9 `Application::Services::Assignments::IssueUploadUrls` service (R-P10) — **BLOCKED by 3.8a red**. **green: ___P, total ___**
- [ ] 🚦 3.10 `POST .../assignments/:aid/upload_urls` route handler — **BLOCKED by 3.8b red**. **green: ___P, total ___**
- [ ] 🚦 3.11 `CreateSubmission` updates: server-reconstruct key (R-P2) + HEAD-check (file-type only) + extension-change cleanup with best-effort delete outside the DB transaction (R-P6); URL-type path unchanged from Slice 2. Add inline comment stating `content_type` is untrusted display metadata (R-P9). **BLOCKED by 3.8c red**. **green: ___P, total ___**
- [ ] 🚦 3.12 LocalGateway routes (`POST /_local_storage/upload` per R-P1, `GET /_local_storage/download/*key` splat per R-P5) mounted in the Roda route tree under `if Tyto::App.environment.in?(%w[development test])` (allowlist per R-P3); single-use HMAC token validation with in-process nonce cache (R-P8); chrooted under `LOCAL_STORAGE_ROOT` — **BLOCKED by 3.8d red**. **green: ___P, total ___**
- [ ] 🚦 3.13 Representer `download_url` emission as a backend route path (R-P4) — **BLOCKED by 3.8e red**. **green: ___P, total ___**
- [ ] 🚦 3.13a Download redirect route (R-P4) at `GET .../submissions/:sid/uploads/:upload_id/download` — authorizes, mints presigned GET, 302s. **BLOCKED by 3.8f red**. **green: ___P, total ___**
- [ ] 3.14 Full regression pass: `bundle exec rake spec`. **total: ___P / ___F / ___E / coverage: ___%.**
- [ ] 🚦 3.14a Integration test (R-P11) — thin Rack::Test end-to-end: `POST /upload_urls` → form-POST to `/_local_storage/upload` with returned fields → `POST /submissions` (HEAD passes, submission persists) → `GET /uploads/:id/download` → follow 302 → bytes match original upload. File: `backend_app/spec/integration/file_upload_flow_spec.rb`. **red: ___F / green: ___P, total ___**

### Phase 3 — Frontend file upload

- [ ] 3.15 Re-enable file-format requirement path in `AssignmentDetailDialog.vue` submit form. Adapt/use `FileUpload.vue`.
- [ ] 3.16 Implement client-side `POST .../upload_urls` → **parallel multipart form-POSTs** (R-P1: not PUT; send each file with the server-supplied `fields` hash as form fields) → send `POST /submissions` without `content` for file entries (backend reconstructs keys per R-P2). Single submit button kicks off the whole pipeline; progress indicator per file; form state preserved on failure per the Failure Recovery spec.
- [ ] 3.17 Render download links for file-type uploads as `<a href={requirement_upload.download_url}>` (R-P4: backend redirect route, not a presigned S3 URL). Browser follows the 302 on click; no staleness on long-open views.
- [ ] 3.18 Pre-upload client validation (extension + size) against the requirement — fail fast, avoid unnecessary presign calls. Size limit read from R-P7's single source of truth — decide here: `GET /api/config/file_storage_limits` endpoint (dynamic) or `VUE_APP_MAX_UPLOAD_BYTES` env var (static). Default to the endpoint unless that adds meaningful complexity.
- [ ] 3.19 Error toasts: failed upload, failed presign, failed confirm (with a clear "try again" affordance).
- [ ] 3.20 `npm run prod` compiles clean.

### Phase 4 — Verification (hybrid: Chrome + manual)

- [ ] 3.21 Chrome walkthrough (LocalGateway, dev DB reset): (a) staff creates assignment with mixed file + URL requirements; (b) student uploads a file + URL via the form; (c) staff views the submission, downloads the file, opens the `.url` entry; (d) student resubmits with a different extension; (e) error paths (file too large, extension mismatch) show inline errors. Record in Review Log below.
- [ ] 3.22 Resolve any bugs found in 3.21 as `3.22a`, `3.22b`, … (TDD gate still applies to any backend fixes).
- [ ] 3.23 Manual developer regression of Slice 1 + 2 flows against the latest build.

### Phase 5 — Setup guide (no code)

- [ ] 3.24 Write `doc/s3.md`: bucket creation, IAM least-privilege policy JSON, CORS JSON (origins to allow), secrets layout, dev vs. prod switches. Cross-link from `README.md`.
- [ ] 3.25 One-shot production smoke test walkthrough documented for the first deploy.

## Manual test feedback

> Captured during 3.21 Chrome walkthrough.

- [ ] (empty — populate during 3.21)

## Review Log (Slice 3)

### 3.21 Hybrid Verification

(To be populated.)

## Pain Points / Meta-review

Keep the Slice 2 pain-points list (P1–P6) in mind during this slice:

- P2 (two-account login switching) and P4 (dialog-open stale caches) will recur. If they cost more than a few minutes each again, that's the signal to revisit Playwright/Capybara before Slice 3 merge.
- P5 (bugs surface only at hybrid layer) is the strongest argument for writing a thin integration test that drives the HTTP flow end-to-end for the presign → upload → submit → download path once the backend stabilizes.

Update this section after 3.21.

## Deferrals / Follow-ups

- ~~**Revisit Q5 (download path) after 3.21 verification**~~ — superseded by R-P4 (backend redirect endpoint). Q5's audit-logging concern is now addressable without a further design pass; the redirect handler is the natural place to log.
- **Revisit R-P4 after 3.21 if the redirect adds noticeable latency** — typical S3 presign is a few ms, but if batch views (e.g., 50 uploads rendered at once with Download buttons) show a lag on click, consider pre-minting presigned URLs with a longer TTL and a manual-refresh button. Not expected to be an issue at current scale.
- Orphaned-file reconciliation UI (R9).
- Course-materials feature — uses this infrastructure, separate branch.
- Pre-existing main-originated issues still open: `/api/course/1/events` 500 on `location_id = NULL`; Locations UI save failure; student access to `/course/:id/attendance` URL; stale names in `SingleCourse.vue` (`showCreateAttendanceEventDialog` / `createAttendanceEvents`).
- Markdown sanitization (Slice 1 deferral 1.12e) — still open. Apply to assignment description + any markdown-rendered field in submissions.
- GitHub issue #47 (timezone display for due-date pickers) — verify status against the `feature-timezone` main merge before deciding.

## Completed

- 3.0a–3.0f Phase 0 decisions and doc sync complete.
- 3.0g Phase 0.5 pre-implementation refinements (R-P1 … R-P11) codified in the plan — 2026-04-24.
- 3.0h R-P1 … R-P11 mirrored into `PLAN.assignments-design-decisions.md` and `PLAN.assignments-ddd-architecture.md` — 2026-04-24.

---

Last updated: 2026-04-24 (Phase 0.5 complete: R-P1 … R-P11 recorded in the plan and mirrored into both research docs via 3.0h. Next action: 3.1a red run.)
