# Future Work

Planned improvements and features to be addressed in future tasks.

## Infrastructure & DevOps

- [ ] **Automated migrations on deploy** - Add `release: bundle exec rake db:migrate` to Procfile to run migrations automatically before each deploy
- [ ] **CI/CD pipeline** - Set up continuous integration for automated testing on PRs
- [ ] **Heroku Review Apps** - Configure `app.json` to enable auto-provisioned review environments for PRs

## Testing

- [ ] **Test suite** - Implement backend tests using Minitest/Rack::Test
- [ ] **Frontend tests** - Add Vue component and integration tests
