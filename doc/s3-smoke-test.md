# S3 Production Smoke Test

A one-shot walkthrough to run after the first production deploy with S3 wired up. Every step before this point in development used the `LocalGateway`; this exercises the real `Aws::S3::Client` path end-to-end. Each step describes what to do, what success looks like, and how to read the most likely failure mode.

Prerequisite: bucket, IAM user, CORS, and Heroku config vars all set per [doc/s3.md](s3.md).

You will need two browser sessions for the upload + download halves — one teaching-staff account and one student account in the same course. A regular window + an incognito window is the simplest setup.

## 1. App boots cleanly with S3 config

```bash
heroku logs --tail
heroku open
```

**Verify**: app loads; no boot errors in the log. The first request that needs the gateway calls `Tyto::FileStorage.build_gateway` — a missing or empty `S3_*` env var raises `Tyto::FileStorage::ConfigurationError` with the specific key name.

**Most likely failure**: `S3 credential :region is missing` (or similar). Re-check `heroku config` against the four required vars in [doc/s3.md § 4](s3.md#4-set-production-environment-variables).

## 2. Staff creates an assignment with a file requirement

In the staff session, create a course → assignment → add a submission requirement with `submission_format: file` and `allowed_types: txt,pdf` (any small extensions are fine for the smoke). Publish the assignment.

**Verify**: assignment appears in the student's view of the course.

## 3. Student uploads a file (presign + form-POST to S3)

Student opens the assignment, picks a small file (~100 KB), clicks Submit. Open DevTools → Network tab before clicking.

**Verify three sequential requests**:

1. `POST /api/course/<cid>/assignments/<aid>/upload_grants` → 201 with a JSON array containing `upload_url` (looks like `https://<bucket>.s3.<region>.amazonaws.com/`) and a `fields` hash.
2. `POST` to the `upload_url` (multipart form data) → **204 No Content** from S3.
3. `POST /api/course/<cid>/assignments/<aid>/submissions` → 201.

**Most likely failures**:

| Symptom | Cause | Fix |
|---|---|---|
| Step 2: browser console shows CORS error | Bucket CORS missing or wrong origin | Re-check [doc/s3.md § 3](s3.md#3-configure-cors-on-the-bucket); allowed origin must match `window.location.origin` exactly |
| Step 2: 403 with `SignatureDoesNotMatch` | Region mismatch — `S3_REGION` doesn't match the bucket's actual region | Fix `heroku config:set S3_REGION=...` |
| Step 2: 403 with `AccessDenied` | IAM user missing `s3:PutObject` | Re-check the policy JSON in [doc/s3.md § 2](s3.md#2-create-the-iam-user) |
| Step 2: 400 `EntityTooSmall` / `EntityTooLarge` | File outside `1..MAX_SIZE_BYTES` (10 MB) | Pick a different test file |
| Step 3: 400 `Uploaded file not found in storage` | Step 2 silently failed, or bucket name mismatch — backend HEAD'd a key that isn't there | Compare `S3_BUCKET` against the bucket the form-POST actually went to |

Confirm the object exists in the AWS console: `<your-bucket>` → Objects → `<assignment_id>/<requirement_id>/<account_id>.<ext>`.

## 4. Staff downloads the file (backend redirect → presigned GET)

In the staff session, open the All Submissions table for the assignment, expand the student's row, click the filename link.

**Verify**: file downloads with the expected bytes. Check DevTools → Network:

1. `GET /api/course/<cid>/.../uploads/<uid>/download` → **302** with a `Location` header pointing at `https://<bucket>.s3.<region>.amazonaws.com/<key>?...&X-Amz-Signature=...`.
2. The redirect target → 200 with the file body.

**Most likely failures**:

| Symptom | Cause | Fix |
|---|---|---|
| Step 1: 403 from the backend | Auth missing — staff JWT didn't reach the route. Frontend uses `axios` with a `Bearer` interceptor; plain `<a href>` won't carry it. | Should be impossible after the 3.22a fix — verify the frontend deploys the post-3.22a build |
| Step 2: 403 `SignatureDoesNotMatch` | Presigned URL was generated for the wrong region (rare — same root cause as step 3 above) | Same as step 3 fix |
| Step 2: 403 `AccessDenied` | IAM user missing `s3:GetObject` | Add `s3:GetObject` to the policy |
| Step 2: CORS error in console | Bucket CORS doesn't list `GET` in `AllowedMethods` | Fix the CORS JSON |

## 5. Resubmit with a different extension (delete-old-key path)

Student resubmits the same requirement with a file of a *different* extension (e.g., `.txt` first, `.pdf` second).

**Verify**:

- New submission persists; download from staff view returns the new file.
- AWS console: the old-extension object (`<aid>/<rid>/<acc>.txt`) is **gone**; the new-extension object (`<aid>/<rid>/<acc>.pdf`) is present.

**Most likely failure**: old object remains. The likely cause is IAM missing `s3:DeleteObject`. The submission still succeeds (delete is best-effort outside the DB transaction per R-P6), so the only signal is checking the bucket. Add `s3:DeleteObject` to the policy and resubmit again to confirm cleanup works.

## 6. Resubmit with the same extension (overwrite path)

Student resubmits the same requirement with a *different* file but the *same* extension.

**Verify**: download returns the new bytes (the S3 key is unchanged; PUT semantics overwrite at the same key).

This step exists because step 5 only covers the delete path — same-extension resubmits should never call `delete_object` and should rely entirely on S3's overwrite behavior.

## After the smoke test

If all six steps pass, the production S3 path is good. Note in your deployment runbook the date and bucket name. The smoke test does not need to be re-run on subsequent deploys unless `S3_*` config or the IAM policy changes.
