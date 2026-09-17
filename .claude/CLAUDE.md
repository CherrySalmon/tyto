# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TYTO is a full-stack course management and attendance tracking application with:
- **Backend**: Ruby Roda framework + Sequel ORM
- **Frontend**: Vue 3 + Vue Router + Element Plus UI
- **Build**: Webpack for frontend bundling
- **Auth**: Google OAuth with JWT tokens (RbNaCl encryption)

## Common Commands

### First-Time Setup
```bash
rake setup                     # Install deps, copy config files
bundle exec rake generate:jwt_key  # Generate JWT_KEY, copy output to secrets.yml
# Edit backend_app/config/secrets.yml - set JWT_KEY and ADMIN_EMAIL
# Edit frontend_app/.env.local - set VUE_APP_GOOGLE_CLIENT_ID (see doc/google.md)
bundle exec rake db:setup                 # Development database
RACK_ENV=test bundle exec rake db:setup   # Test database
```

### Running Locally
```bash
rake run:api                   # Start backend server (http://localhost:9292)
rake run:frontend              # Start webpack dev server (http://localhost:8080)
npm run prod                   # Production build to dist/
```

### Database
```bash
bundle exec rake db:migrate    # Run migrations
bundle exec rake db:seed       # Seed database
bundle exec rake db:setup      # Migrate + seed
bundle exec rake db:drop       # Delete dev/test database
bundle exec rake db:reset      # Drop + migrate + seed
bundle exec rake generate:jwt_key  # Generate JWT_KEY for secrets.yml
```

### Testing
```bash
bundle exec rake spec          # Run all tests, backend + frontend (default task)
bundle exec rake spec:backend  # Backend only (Minitest)
bundle exec rake spec:frontend # Frontend only (Vitest; same as npm test)
bundle exec rake test          # Alias for spec
RACK_ENV=test bundle exec rake db:migrate  # Setup test database first
```
The backend suite reports one intentional skip (`courses_spec.rb` — testing a missing `owner` role would require deleting seed data the suite depends on). Expected; not a regression.

## Architecture

### Backend Structure (`backend_app/`)

The backend follows **Domain-Driven Design (DDD)** architecture. See `/ddd` Claude skill for patterns and guidelines.

Top-level folders: `app/`, `config/`, `db/`, `spec/`

All runtime code lives in `app/`:

**Domain Layer** (`app/domain/`) - Pure domain, no framework dependencies:
- **types.rb**: Shared constrained types (dry-types)
- **\<context\>/entities/**: Aggregate roots and entities (dry-struct)
- **\<context\>/values/**: Value objects

**Infrastructure Layer** (`app/infrastructure/`):
- **database/orm/**: Sequel ORM models (thin, no business logic)
- **database/repositories/**: Maps ORM ↔ domain entities
- **auth/**: Authentication boundary adapters
  - `auth_token/` - JWT handling (Gateway for encryption, Mapper for AuthCapability ↔ token)
  - `sso_auth/` - Google OAuth (Gateway for HTTP, Mapper for Google data → domain fields)

**Application Layer** (`app/application/`):
- **controllers/routes/**: API route handlers (Roda). Routes are under `/api/` namespace
- **services/**: Use cases, orchestration
- **policies/**: Business rules that depend on actor/context (authorization, geo-fence, etc.)
- **contracts/**: Input validation (dry-validation, imports domain types)

**Presentation Layer** (`app/presentation/`):
- **representers/**: JSON serialization (Roar)

**Cross-cutting Utilities** (`app/lib/`):
- Currently empty (JWT handling moved to `infrastructure/auth/` and `domain/accounts/values/`)

**Refactoring status**: See `.claude/plans/005-PLAN-refactor-ddd/a-PLAN.md` for current progress.

### Frontend Structure (`frontend_app/`)
- **pages/**: Full-page Vue components (Login, ManageCourse, course/, etc.)
- **components/**: Reusable UI components
- **router/index.js**: Vue Router configuration
- **lib/cookieManager.js**: Cookie utilities for JWT storage

### Service → Policy Pattern
Services instantiate `Tyto::Policy::*` objects for authorization:
```ruby
policy = Policy::Course.new(requestor, enrollment)
return Failure(forbidden('No access')) unless policy.can_update?
```
Policies check global roles (admin, creator) and course enrollment roles (owner, instructor, staff, student). See `backend_app/app/application/policies/CLAUDE.md` for conventions.

### Authentication Flow
1. Frontend uses vue3-google-login for OAuth
2. Token sent to `/api/auth/verify_google_token`
3. Backend returns encrypted JWT (account_id + roles)
4. JWT stored in cookie, sent in Authorization header

### Cryptographic code
All crypto goes through `Tyto::Security` (`backend_app/app/lib/security.rb`). Application code does not call `RbNaCl`, `OpenSSL`, or `SecureRandom` directly. See `doc/security.md` for the rule, the available primitives, and how to add new ones.

## Configuration

### Required Setup Files (copied by `rake setup`)
- `backend_app/config/secrets.yml` - Backend secrets:
  - `JWT_KEY`: Generate with `rake generate:jwt_key`
  - `ADMIN_EMAIL`: Your Google account email for admin access
  - `DATABASE_URL`: PostgreSQL URL (production only)
- `frontend_app/.env.local` - Frontend config:
  - `VUE_APP_GOOGLE_CLIENT_ID`: Google OAuth client ID (see doc/google.md)

### Database
- Development: SQLite at `backend_app/db/store/development.db`
- Production: PostgreSQL (set in DATABASE_URL)
- Migrations: `backend_app/db/migrations/`

## Development

### DevContainer
Open in VS Code and use "Reopen in Container" for a pre-configured Ruby 3.4 + Node.js 24 environment. The container automatically runs `rake setup` on creation, installing dependencies and generating config files.

### Running Both Servers
```bash
# Terminal 1: Frontend (webpack dev server with hot reload)
rake run:frontend

# Terminal 2: Backend
rake run:api
```

**IMPORTANT**: Open http://localhost:9292 in your browser (the backend), NOT port 8080. The backend serves both the API and frontend files from `dist/`. The webpack dev server (8080) only handles compilation with hot reload and writes to `dist/`.

## Code Conventions

### Ruby
- Frozen string literals enabled at file top
- Module namespacing: `Tyto::Api`, `Tyto::Routes::*`
- RuboCop for linting
- **Testing**: Minitest with spec-style syntax (`describe`/`it`), NOT RSpec.
- **TDD Protocol** (MANDATORY for backend tasks marked "test" or "red" in planning docs): red-green-refactor, one test at a time, never batched.
  1. Write test file(s) only — reference classes/methods that do not exist yet
  2. Run `bundle exec rake spec` — confirm failures. Record count in the plan task line (e.g., `red: 5F`)
  3. Only then write the implementation to make them pass
  4. Run tests again — confirm green. Record count in the plan task line (e.g., `green: 5P, total 1096`)
  5. Never combine steps 1+3 in a single pass. The red run is non-negotiable proof of test-first.
- **Avoid `nil` as state**: Use Null Object pattern instead of returning `nil` for missing/empty states. This eliminates guard clauses and follows "Tell, Don't Ask" principle. Example: `NullTimeRange` instead of `nil` for courses without dates.

### Vue/JavaScript
- Vue Single File Components (.vue)
- Element Plus components auto-imported via unplugin-vue-components

## Project Planning

- **Future work**: See `doc/future-work.md` for planned improvements (CI/CD, testing, etc.)
- **Branch plans**: live in `.claude/plans/` (gitignored, never reaches `main`). One folder per work stream, named `NNN-PURPOSE-slug`:
  - `NNN` is a zero-padded sequence number starting at `001`. It strictly increments and is never reused. List `.claude/plans/` and take the next unused number.
  - `PURPOSE` is an uppercase tag for the kind of document that started the stream (`PLAN`, `BUGFIX`, `REFACTOR`, `HOTFIX`). It does not change when a second kind of document joins the folder.
  - `slug` is a short kebab-case name derived from the branch name (`/` becomes `-`, owner prefixes such as `ray/` are dropped).
  - Inside the folder the main document takes the name of its kind (`PLAN.md`, `BUGFIX.md`). When a folder holds two or more main documents, prefix each with a reading-order letter (`a-PLAN.md`, `b-PLAN.md`); a lone document takes no letter. Supporting files keep a kind tag and take no letter (`SKETCHES.html`, `SKETCHES-hifi.html`).
  - A reference inside one folder uses the bare filename. A reference to another folder uses the full path from the repository root.
  - `CLAUDE.local.md` (gitignored) holds an `@` include of the active plan.

### Plans

Plans and their working docs live in `.claude/plans/` (gitignored, so they never reach `main`). The active plan is `@`-included from `CLAUDE.local.md`.

- **One folder per work stream**, named `NNN-PURPOSE-slug`: `NNN` is a zero-padded sequence number that strictly increments and is never reused; `PURPOSE` is an uppercase tag for the kind of document that started the stream (`PLAN`, `BUGFIX`, `REFACTOR`, `HOTFIX`); `slug` is a short kebab-case name, normally from the branch name.
- **Inside the folder**: a lone main document takes the name of its kind (`PLAN.md`, `BUGFIX.md`). When a folder holds two or more, prefix each with a letter for reading order (`a-PLAN.md`, `b-BUGFIX.md`). Supporting files keep a kind tag and take no letter (`SKETCHES.html`).
- **References**: use the bare filename inside one folder, and the full path from the repository root across folders.
- **Closing**: when a branch merges, add `> **CLOSED** (date): merged to <branch> as <sha>` under the plan title. Do not delete closed plans.

## IMPORTANT: First Message and AI-assisted authorship

At the START of every conversation, immediately inform the user: "[Reminder: You must review, understand, and be ultimately responsible for any code you commit — even when using AI assistance]"

Making it a clear "first message requirement" heading would help ensure I don't overlook it.

Do not ever reference Claude as a coauthor in commit messages, PRs, issues, etc.