# Future Work

Planned improvements and features to be addressed in future tasks.

## Database Migrations

- [ ] **Add timestamps to accounts table** - The `accounts` table is missing `created_at` and `updated_at` columns. Create a migration to add these columns, then update the Account ORM with `plugin :timestamps`. The Account entity and representer are already prepared to handle timestamps once available. **Requires production migration.**

## Infrastructure & DevOps

- [ ] **Automated migrations on deploy** - Add `release: bundle exec rake db:migrate` to Procfile to run migrations automatically before each deploy
- [ ] **CI/CD pipeline** - Set up continuous integration for automated testing on PRs
- [ ] **Heroku Review Apps** - Configure `app.json` to enable auto-provisioned review environments for PRs

## Application Layer

- [ ] **Input validation contracts** - Replace raw hash parameters (`attendance_data`, `location_data`, etc.) with dry-validation contracts. This would move validation out of services, provide consistent error formatting, and allow services to trust their input. See `CLAUDE.md` architecture notes on contracts.

## Security (Priority)

- [ ] **Input whitelisting on PUT routes** - Prevent mass assignment vulnerabilities. PUT routes currently accept arbitrary JSON fields that get written to DB (e.g., users could potentially update their own roles). Implement Sequel's `set_allowed_columns` or manual input filtering in services. *Note: Input validation contracts (above) would also address this.*
- [ ] **Review RolePolicy** - Exists but unused. Either wire it into AccountService for role assignment authorization, or remove if not needed.
- [ ] **Security tests** - Add tests verifying that sensitive fields (roles, etc.) cannot be modified via API without proper authorization.

## Testing

- [ ] **Test suite** - Implement backend tests using Minitest/Rack::Test
- [ ] **Frontend tests** - Add Vue component and integration tests

## Domain Layer (Prepared for Future Use)

The following domain functionality has been implemented but is not yet used by the application. These are available for future features:

### Backend Attendance Proximity Validation

Currently, attendance check-in proximity validation is done only in the frontend (bounding box check in `AttendanceTrack.vue`). This can be bypassed by malicious users sending fake coordinates.

**Available domain objects for backend validation:**

- `Value::GeoLocation#distance_to(other)` - Haversine formula, returns distance in km
- `Entity::Location#distance_to(other_location)` - Delegates to GeoLocation
- `Value::NullGeoLocation` - Safe handling when coordinates are missing

**Suggested implementation:**

```ruby
# In AttendanceService or a domain service
def validate_proximity(user_coords, event_location, max_distance_km: 0.5)
  user_geo = Value::GeoLocation.new(longitude: user_coords[:lng], latitude: user_coords[:lat])
  distance = event_location.geo_location.distance_to(user_geo)
  distance <= max_distance_km
end
```

### Scheduling Conflict Detection

**Available domain objects:**

- `Value::TimeRange#overlaps?(other)` - Check if two time ranges overlap
- `Value::TimeRange#contains?(time)` - Check if a time falls within the range

**Use cases:**

- Prevent scheduling overlapping events in the same location
- Detect course schedule conflicts for students
