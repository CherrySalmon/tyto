# Heroku Build Chore: Build Frontend on Deploy

## Goal
Move the frontend build process from local development to Heroku's deployment pipeline, allowing us to remove `dist/` from version control.

## Current State
- **Build**: `npm run prod` must be run locally before each deploy
- **dist/**: Committed to git (6 files, ~1.4MB bundled JS)
- **Procfile**: Only runs puma web server
- **Buildpack**: Heroku auto-detects Ruby only (no Node.js build step)
- **Environment**: `VUE_APP_GOOGLE_CLIENT_ID` is read from `frontend_app/.env.local` during webpack build

## Proposed Approach: Multi-Buildpack with heroku-postbuild

### How It Works
1. Add **Node.js buildpack** before Ruby buildpack
2. Heroku runs `npm install` (installs devDependencies needed for build)
3. Add `heroku-postbuild` script that runs after npm install
4. Node.js buildpack executes `heroku-postbuild` to create `dist/`
5. Ruby buildpack then runs and starts the server
6. Remove `dist/` from git tracking

### Required Changes

#### 1. Configure Heroku Buildpacks (run once)
```bash
heroku buildpacks:clear
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add heroku/ruby
```

#### 2. Update package.json
Add `heroku-postbuild` script:
```json
"scripts": {
  "dev": "webpack serve --config webpack/webpack.dev.js",
  "test": "echo \"Error: no test specified\" && exit 1",
  "prod": "webpack --config webpack/webpack.prod.js",
  "heroku-postbuild": "npm run prod"
}
```

#### 3. Handle Environment Variables
The webpack build reads `VUE_APP_GOOGLE_CLIENT_ID` from `.env.local`. On Heroku:
- Set via: `heroku config:set VUE_APP_GOOGLE_CLIENT_ID=<value>`
- Modify `webpack.common.js` to also read from `process.env` (Heroku sets config vars as environment variables)

#### 4. Update .gitignore
Add:
```
dist/
```

#### 5. Remove dist/ from Git
```bash
git rm -r --cached dist/
git commit -m "Remove dist/ from version control (now built on Heroku)"
```

---

## Questions & Decisions

### Q1: How should webpack handle environment variables on Heroku?
**Current behavior**: Reads from `frontend_app/.env.local` file only

**Options**:
- **A) Modify dotenv loading** - Check for env vars directly, fall back to .env.local
- **B) Create .env.local on Heroku** - Use a build script to write env vars to file
- **C) Remove dotenv dependency for prod** - Use process.env directly in webpack config

**Recommendation**: Option A - Check `process.env.VUE_APP_GOOGLE_CLIENT_ID` first, then fall back to dotenv for local development.

**Decision**: **Option A** - Modify webpack config to check process.env first, fall back to .env.local for local dev.

---

### Q2: Should devDependencies remain as devDependencies?
**Issue**: By default, Heroku's Node.js buildpack only installs production dependencies (`npm install --production`).

**Options**:
- **A) Set NPM_CONFIG_PRODUCTION=false** on Heroku (installs all deps including devDependencies)
- **B) Move build tools to dependencies** (not recommended - bloats production)

**Recommendation**: Option A - Set `heroku config:set NPM_CONFIG_PRODUCTION=false`

**Decision**: **Option A** - Set `NPM_CONFIG_PRODUCTION=false` on Heroku.

**Note**: User will manually set `VUE_APP_GOOGLE_CLIENT_ID` on Heroku with a production Google OAuth client ID (the local .env.local value is for localhost only).

---

### Q3: What about CI/CD and testing?
**Current**: Tests run locally with `bundle exec rake spec`

**Consideration**: If dist/ isn't in git, CI pipelines that don't build the frontend first may fail integration tests that expect static files.

**Options**:
- **A) CI builds frontend first** - Add npm build step to CI workflow
- **B) Backend tests don't need dist/** - If tests only hit API, this is fine
- **C) Create separate CI buildpack config** - Different setup for CI vs deploy

**Question for you**: Do your CI/test workflows currently depend on dist/ being present?

**Decision**: **N/A** - No CI/CD workflows or tests currently exist. This will be addressed in a future task when testing is set up.

---

### Q4: Should we add an app.json for review apps?
**Benefit**: Enables Heroku Review Apps with proper buildpack configuration

**Contents would include**:
- Buildpack order
- Required env vars
- Database addon

**Question for you**: Do you use Heroku Review Apps or plan to?

**Decision**: **Defer** - Not currently using Review Apps. Can add `app.json` later if needed.

---

### Q5: Should we add a release phase for migrations?
**Current**: Migrations are run manually via `heroku run rake db:setup`

**Option**: Add `release` process to Procfile:
```
release: bundle exec rake db:migrate
web: bundle exec puma config.ru -t 1:5 -p ${PORT:-9292} -e ${RACK_ENV:-production}
```

**Note**: This is orthogonal to the main task but worth considering while we're updating Heroku config.

**Decision**: **Defer** - Good idea but not for this task. Track as future work alongside tests, CI, and Review Apps.

---

## Summary of Changes (Once Decisions Made)

| File | Change |
|------|--------|
| package.json | Add `heroku-postbuild` script |
| webpack/webpack.common.js | Handle env vars from process.env |
| .gitignore | Add `dist/` |
| Procfile | Potentially add `release` command |
| app.json | Create if using review apps |
| Heroku config | Set buildpacks, NPM_CONFIG_PRODUCTION, VUE_APP_GOOGLE_CLIENT_ID |

## Risks & Rollback Plan

**Risk**: First deploy after changes may fail if env vars aren't set correctly
**Mitigation**:
1. Set all Heroku config vars before deploying
2. Test buildpack order with `heroku builds:info`
3. Keep a branch with dist/ committed for emergency rollback

---

## Next Steps (After Discussion)
1. Finalize decisions on questions above
2. Implement changes in order listed
3. Test locally that `npm run prod` still works
4. Set Heroku config vars
5. Configure buildpacks
6. Deploy and verify
7. Remove dist/ from git after successful deploy
