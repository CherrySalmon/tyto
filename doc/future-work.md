# Future Work

Planned improvements and features to be addressed in future tasks.

## Database Migrations

- [ ] **Add timestamps to accounts table** - The `accounts` table is missing `created_at` and `updated_at` columns. Create a migration to add these columns, then update the Account ORM with `plugin :timestamps`. The Account entity and representer are already prepared to handle timestamps once available. **Requires production migration.**

## Infrastructure & DevOps

- [x] **Automated migrations on deploy** — shipped 2026-04-21 (Slice 1 of `feature-multi-event`). `Procfile` declares `release: bundle exec rake db:migrate`; every Heroku deploy runs migrations in the release phase and fails atomically if any migration raises.
- [ ] **CI/CD pipeline** - Set up continuous integration for automated testing on PRs
- [ ] **Heroku Review Apps** - Configure `app.json` to enable auto-provisioned review environments for PRs

## Application Layer

- [ ] **Input validation contracts** - Replace raw hash parameters (`attendance_data`, `location_data`, etc.) with dry-validation contracts. This would move validation out of services, provide consistent error formatting, and allow services to trust their input. See `CLAUDE.md` architecture notes on contracts.

## Security (Priority)

- [ ] **Input whitelisting on PUT routes** - Prevent mass assignment vulnerabilities. PUT routes currently accept arbitrary JSON fields that get written to DB (e.g., users could potentially update their own roles). Implement Sequel's `set_allowed_columns` or manual input filtering in services. *Note: Input validation contracts (above) would also address this.*
- [ ] **Review Policy::Role** - Exists but unused. Either wire it into AccountService for role assignment authorization, or remove if not needed.
- [ ] **Security tests** - Add tests verifying that sensitive fields (roles, etc.) cannot be modified via API without proper authorization.
- [ ] **CVE sweep of Ruby gem lockfile** — `bundle exec rake audit` (wired in Slice 1 of `feature-multi-event`) currently reports 17 pre-existing advisories as of 2026-04-21: 1 on `puma` (medium, CVE-2024-45614 header clobbering — Heroku also flags this on every deploy, recommends Puma 7.0.3+), 11 on `rack 3.0.9.1` (mix of medium and high — log injection, escape-sequence injection, path traversal), and 6 on `rexml 3.2.6` (medium/high — DoS via crafted XML). Each gem needs a minor-version bump plus regression testing; deferred from Slice 1 to avoid scope creep during a refactor-only deploy. Follow-up task: open a dedicated `security/cve-sweep` branch, bump puma → 7.x, rack → 3.1.x (or 2.2.x line depending on public API compat), rexml → 3.3+, run full spec suite + manual route smoke, deploy to prod.

## Testing

- [ ] **Test suite** - Implement backend tests using Minitest/Rack::Test
- [ ] **Frontend tests** - Add Vue component and integration tests

## Domain Layer (Prepared for Future Use)

The following domain functionality has been implemented but is not yet used by the application. These are available for future features:

### Geolocation Accuracy Check for Attendance Anti-Spoofing

Backend geo-fence proximity validation (Haversine, 55m radius) and time-window enforcement are now implemented. However, the system trusts whatever coordinates the client sends. The browser Geolocation API provides a `coords.accuracy` value (radius in meters) that can help detect naive spoofing attempts (e.g., Chrome DevTools Sensors panel often reports accuracy of `0`).

**Suggested implementation:**

- Frontend: send `coords.accuracy` alongside latitude/longitude when recording attendance
- Backend: reject submissions where accuracy is `0` or exceeds a threshold (e.g., > 100m)
- Real GPS typically reports 5-20m accuracy; unrealistic values suggest spoofing or poor signal
- Low effort: one additional field in the request, one check in the service

**Limitations:** sophisticated spoofers can set realistic accuracy values. This blocks naive spoofing only. For stronger anti-spoofing, consider rotating check-in codes (physical presence proof) or motion sensor verification.

### Scheduling Conflict Detection

**Available domain objects:**

- `Value::TimeRange#overlaps?(other)` - Check if two time ranges overlap
- `Value::TimeRange#contains?(time)` - Check if a time falls within the range

**Use cases:**

- Prevent scheduling overlapping events in the same location
- Detect course schedule conflicts for students
