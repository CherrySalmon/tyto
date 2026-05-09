# Bulk Downloads (Instructor)

Status: **planning** — no implementation yet. This document captures the problem, the options considered, and the recommended path.

## The problem

Once an assignment has more than a handful of submissions, instructors need to download files one student at a time through the existing per-upload download route. For a class of 100+ students with multiple file requirements per assignment, that's hundreds of clicks. Grading workflows (download all submissions → grade locally → upload feedback) are blocked.

## Scope

In scope:

- Instructor (teaching staff) bulk-downloads **all submissions for a single assignment** as one ZIP.
- File-type uploads are included as actual files.
- URL-type entries are included as a `manifest.csv` (per Slice 3 R2 revisit — `.url` files are platform-biased and graders prefer a single CSV).

Out of scope (for now):

- Course-wide bulk download across multiple assignments.
- Per-requirement bulk download (e.g., "all journal papers across the class as a single folder").
- Student-side bulk download (students would only ever download their own submission, which is small).

## Scale assumptions

Real classes that drive this work: **100+ students**, multiple file requirements per assignment, files capped at `MAX_SIZE_BYTES` (10MB). Plausible per-assignment ZIP size: 200MB typical, 1GB+ worst case. Architecture choices below are evaluated against this scale, not a 5-student demo.

## Options considered

### A. Backend-streamed ZIP (synchronous)

Backend pulls each S3 object via the Gateway and streams them into a ZIP response. Heroku dyno is pinned to one instructor's connection for the duration of their download.

- **Pro**: simplest implementation; no new infra; reuses existing Gateway.
- **Con**: violates the "backend never proxies file bytes" principle (architecture/assignments.md).
- **Con**: web dyno tied up for minutes per download; one slow connection degrades API throughput for everyone else.
- **Con**: Heroku H12 router timeout (55s of stalled bytes) can kill mid-stream on a flaky instructor connection.
- **Verdict**: workable for tens of students, fragile at 100+. Not recommended.

### B. Client-side ZIP (manifest of presigned URLs + JSZip)

Backend returns an array of `{filename, presigned_url}` entries. Frontend downloads each in parallel and assembles a ZIP in browser memory using JSZip.

- **Pro**: backend stays simple — no proxying, no new services.
- **Pro**: presigned-URL approach is consistent with existing single-file download flow.
- **Con**: browser memory bound. Soft fail around 500MB ZIP — entire archive lives in a tab. 100 × 5MB = 500MB borderline; 100 × 10MB = guaranteed crash on most browsers.
- **Con**: 100 parallel S3 fetches from one browser will hit per-host connection limits and rate-limit themselves.
- **Verdict**: works for small classes (<30 students) with small files. Doesn't scale to 100+.

### C. AWS Lambda + S3 (recommended)

Instructor clicks "Download all submissions". Backend invokes a Lambda function that streams the requested S3 objects into a ZIP, writes the ZIP to a temp S3 prefix, and returns a presigned GET URL. Frontend downloads the ZIP directly from S3.

- **Pro**: Lambda runs in the same AWS region as the bucket — fast S3 reads, no inter-service egress, no Heroku dyno time.
- **Pro**: doesn't require Sidekiq/Redis/worker dyno on Heroku.
- **Pro**: scales transparently — each download is its own Lambda invocation.
- **Pro**: 15-minute Lambda execution limit is plenty for assignment-scale ZIPs.
- **Pro**: Tyto's web dyno is uninvolved end-to-end (presign → invoke → return URL → user downloads from S3).
- **Con**: net-new AWS infrastructure. Adds a deployment surface (Lambda function + IAM role) separate from Heroku.
- **Con**: Lambda cold starts add ~1s latency on the first invocation in a while.
- **Con**: requires wiring the IAM permissions correctly (Lambda needs S3 read on the uploads prefix and write on the `_downloads/` prefix).

## Recommended path: Lambda + S3

For 100+ student classes this is the right architecture. Heroku-side options either tie up dynos (A) or push too much load to the browser (B). Lambda sidesteps both by doing the work where the data already is.

## Rough flow

```text
┌──────────┐                                        ┌──────────┐
│  Vue.js  │  1. POST .../bulk_download             │  Tyto    │
│ (Browser)│ ──────────────────────────────────→   │ Backend  │
│          │                                        │ (Heroku) │
│          │                                        └────┬─────┘
│          │                                             │ 2. authorize (teaching staff)
│          │                                             │ 3. fetch submission keys + URL entries from DB
│          │                                             │ 4. invoke Lambda with payload
│          │                                             ▼
│          │                                        ┌──────────┐
│          │                                        │  Lambda  │  5. read each S3 object
│          │                                        │ tyto-zip │  6. write ZIP + manifest.csv
│          │                                        │          │     to s3://bucket/_downloads/<token>.zip
│          │                                        └────┬─────┘
│          │                                             │ 7. return zip key
│          │  8. presigned GET URL                       │
│          │  ←──────────────────────────────────────────┘
│          │
│          │  9. GET <presigned URL>                ┌──────────┐
│          │ ─────────────────────────────────────→ │    S3    │
│          │  10. ZIP streams to browser            │          │
│          │  ←──────────────────────────────────── │          │
└──────────┘                                        └──────────┘
```

## Components

- **New backend route**: `POST /api/course/:course_id/assignments/:assignment_id/bulk_download`. Authorizes the requestor (teaching staff only), gathers all submission `RequirementUpload` rows for the assignment, separates file-type from URL-type entries, invokes the Lambda, returns a presigned GET URL for the resulting ZIP.
- **New service**: `Service::Submissions::PrepareBulkDownload` — orchestrates auth, data fetch, Lambda invoke, presigned-URL minting.
- **New gateway method**: `Gateway#invoke_bulk_zip(assignment_id:, file_keys:, url_manifest:)` — wraps the Lambda invocation. Returns the resulting ZIP's S3 key on success.
- **New Lambda function** (separate deployable): receives the file-keys list and url-manifest, streams files into a ZIP under `s3://<bucket>/_downloads/<token>.zip`, returns the key. Suggested runtime: Node.js (mature streaming ZIP libraries like `archiver`) or Python (`zipfile`). Either works.
- **S3 lifecycle rule**: expire objects under `_downloads/` after 24h. Keeps the bucket clean automatically.
- **IAM**: existing Tyto IAM user gets `lambda:InvokeFunction` for the new function. Lambda's execution role gets `s3:GetObject` on the uploads prefix and `s3:PutObject` on `_downloads/`.

## ZIP layout (proposed)

```text
HW_A_submissions.zip
├── manifest.csv                          # all URL-type entries, one row per (student, requirement)
├── <student_email>/
│   ├── Journal_Paper.pdf                 # one file per file-type requirement
│   └── ...
└── ...
```

`manifest.csv` columns:

```text
student_email,student_name,requirement,url,submitted_at,is_late
```

Student-keyed folders (one per submitter) are more natural for grading — instructors usually want to see all of a single student's work together. If grading by requirement is the dominant workflow, requirement-keyed layout is a flag away.

## Open questions

These need answers when implementation begins:

1. **Lambda runtime + ZIP library** — Node `archiver` or Python `zipfile`? Either works; pick whichever you're more comfortable maintaining.
2. **Synchronous vs. async invocation** — for a 100-student / 500MB ZIP, Lambda execution is plausibly 30-60s. Synchronous backend → Lambda → response means the Tyto request waits. Async (Tyto returns immediately, frontend polls or receives a webhook) is more robust but adds a job-status table. Probably start synchronous; revisit if real-world ZIPs get slow.
3. **In-zip filename collision** — student emails are unique, so per-student folders won't collide. But what if a requirement description contains characters illegal on Windows (`:`, `?`)? Sanitize at ZIP-write time.
4. **Empty-submission handling** — a student who submitted nothing: skip entirely, or include an empty folder? Skipping is cleaner and matches "manifest reflects reality."
5. **Late labeling** — surface `is_late` in `manifest.csv` and as a suffix on folder names? Suffix is loud; manifest is sufficient.
6. **CSV-only assignments** — if the assignment has no file-type requirements (only URL entries), skip the ZIP and return the CSV directly? Simpler UX, but adds a branch. Probably ZIP-everything is fine.
7. **Authorization scope** — `Policy::Submission#can_view_all?` is the right check (teaching staff). Already exists; reuse.
8. **Rate limiting** — instructor accidentally clicking the button 10 times produces 10 Lambda invocations. Either debounce in the frontend or short-cache by `(assignment_id, last_modified)` so identical requests within N minutes return the same ZIP.

## Why not the alternatives

- **Sidekiq + Redis + worker dyno on Heroku**: more Heroku addons, more dyno cost, still proxies bytes through Heroku for the upload-to-S3 step. Lambda is closer to the data and cheaper at this scale.
- **Pre-built S3 ZIP feature**: doesn't exist. AWS S3 has no native "download a prefix as ZIP" capability for browser users (see discussion in conversation transcript).
- **AWS Transfer Family / DataSync**: built for ongoing file movement, not on-demand user downloads. Wrong tool.

## Progress reporting

A 100-student × 5-requirement ZIP could take 30–90s. Frontend needs a progress bar so instructors don't think it's stuck.

**Recommendation: poll a job-status row.** Lambda writes `{job_id, status, current, total, download_url, error}` to a `bulk_download_jobs` Postgres table (via a callback to Tyto's backend, every ~25 file fetches to bound DB writes). Frontend polls `GET /api/.../bulk_download/:job_id/status` every 2s.

- Zero new infra. Reuses the existing HTTP + JWT stack.
- 2-second granularity is invisible to a human waiting on a 60s job — same UX as Google Takeout, GitHub export, Slack export.
- Each poll is ~50ms; doesn't tie up Heroku dyno threads.

**Alternatives rejected for now:**

- **Faye / AnyCable / ActionCable on Heroku**: every progress stream pegs a Puma thread for its duration. Default 5 threads/dyno → ~5 concurrent download-watchers before regular API traffic queues. Faye specifically is also largely unmaintained.
- **AWS API Gateway WebSocket**: cleanest long-term answer (push from Lambda direct to browser, Heroku uninvolved), but adds non-trivial AWS infra (WebSocket route, connection table, separate auth). Worth revisiting if real-time pub/sub is needed by other features later.

If a future feature needs real-time multi-tenant push (live attendance, chat), revisit and consolidate on API Gateway WebSocket then.

## Related design docs

Read before implementing — these set context and constraints this feature must respect:

- **[`doc/architecture/assignments.md`](architecture/assignments.md)** — Assignments bounded context: aggregate roots (`Submission`, `RequirementUpload`), the S3 upload/download flow, the "backend never proxies file bytes" principle, and the `Gateway` / `Mapper` / `SubmissionMapper` infrastructure layout. Bulk download is a new read-side capability over the same data.
- **[`doc/architecture/decisions/assignments.md`](architecture/decisions/assignments.md)** — Design decisions for the Assignments context. Especially relevant:
  - **R2** (S3 key pattern) — bulk download reads keys built by this rule. Note: the `_downloads/<token>.zip` keys this feature introduces are *system-generated*, separate from the per-upload pattern; R2 may want a revisit block noting that the bucket now contains two key namespaces.
  - **R2 revisit (2026-03-02)** — URL-type entries are stored as raw URL strings, not `.url` files. Drives the decision to emit a `manifest.csv` rather than per-student `.url` files inside the ZIP.
  - **R-P2** — server reconstructs S3 keys from authenticated context. Bulk download must look up keys via the existing `RequirementUpload.content` field, not trust any client-supplied list.
  - **R-P4** — download protocol uses backend redirect to a presigned GET. Bulk download follows the same shape: backend mints a fresh presigned URL per click, no caching of presigned URLs in the DB.
- **[`doc/s3.md`](s3.md)** — S3 bucket setup, IAM user policy, CORS. Implementing bulk download will extend this:
  - IAM user gains `lambda:InvokeFunction` on the bulk-zip Lambda.
  - Bucket gains a lifecycle rule on the `_downloads/` prefix (24h expiry).
  - Lambda execution role needs its own IAM policy (read on uploads prefix, write on `_downloads/`).
- **[`doc/s3-smoke-test.md`](s3-smoke-test.md)** — production smoke-test pattern. A parallel smoke test for bulk download should be added (small assignment, click button, verify ZIP downloads, inspect contents).
- **[`doc/security.md`](security.md)** — all crypto goes through `Tyto::Security`. Any signed tokens used to authorize Lambda invocations or scope the resulting presigned URL use `Tyto::Security::Signer`, never `OpenSSL::HMAC` or `SecureRandom` directly.
- **[`doc/architecture/ddd-patterns.md`](architecture/ddd-patterns.md)** — DDD conventions. The new service (`Service::Submissions::PrepareBulkDownload`), route handler, and any gateway extension follow these patterns.

### Docs that will need updates when implementing

- `doc/s3.md`: add the IAM/lifecycle/CORS deltas for the Lambda + `_downloads/` prefix.
- `doc/architecture/assignments.md`: extend the "File Storage Infrastructure" section to mention the Lambda + `_downloads/` keyspace, and add a "Bulk Download Flow" subsection alongside Upload Flow / Download Flow.
- `doc/architecture/decisions/assignments.md`: add a new section (or revisit R2) for the bulk-download decision record.
- `doc/s3-smoke-test.md`: add a bulk-download smoke step.

## Migration / rollout notes

- This is a net-new feature. No data migration needed.
- The S3 bucket needs a new lifecycle rule for the `_downloads/` prefix (24h expiry). Add to `doc/s3.md` once implementation starts.
- Tyto IAM user policy needs `lambda:InvokeFunction` added — small policy update.
- Lambda function lives in a separate AWS deployment. Suggested location: a `lambda/` subdirectory in this repo with its own `package.json` / `requirements.txt` and a deploy script (or use AWS SAM / Serverless Framework). Keeps everything in one repo without coupling to Heroku.
