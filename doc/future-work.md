# Future Work

Planned improvements and features to be addressed in future tasks.

## Infrastructure & DevOps

- [ ] **Automated migrations on deploy** - Add `release: bundle exec rake db:migrate` to Procfile to run migrations automatically before each deploy
- [ ] **CI/CD pipeline** - Set up continuous integration for automated testing on PRs
- [ ] **Heroku Review Apps** - Configure `app.json` to enable auto-provisioned review environments for PRs

## Security (Priority)

- [ ] **Input whitelisting on PUT routes** - Prevent mass assignment vulnerabilities. PUT routes currently accept arbitrary JSON fields that get written to DB (e.g., users could potentially update their own roles). Implement Sequel's `set_allowed_columns` or manual input filtering in services.
- [ ] **Review RolePolicy** - Exists but unused. Either wire it into AccountService for role assignment authorization, or remove if not needed.
- [ ] **Security tests** - Add tests verifying that sensitive fields (roles, etc.) cannot be modified via API without proper authorization.

## Testing

- [ ] **Test suite** - Implement backend tests using Minitest/Rack::Test
- [ ] **Frontend tests** - Add Vue component and integration tests
