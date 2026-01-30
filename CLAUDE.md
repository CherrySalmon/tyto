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

### Frontend
```bash
npm run dev                    # Start webpack dev server (http://localhost:8080)
npm run prod                   # Production build to dist/
```

### Backend
```bash
puma config.ru -t 1:5 -p 9292  # Start server (http://localhost:9292)
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
bundle exec rake spec          # Run all tests (default task)
bundle exec rake test          # Alias for spec
RACK_ENV=test bundle exec rake db:migrate  # Setup test database first
```

## Architecture

### Backend Structure (`backend_app/`)

The backend follows **Domain-Driven Design (DDD)** architecture. See `/ddd-refactoring` skill for patterns and guidelines.

Top-level folders: `app/`, `config/`, `db/`, `spec/`

All runtime code lives in `app/`:

**Domain Layer** (`app/domain/`) - Pure domain, no framework dependencies:
- **types.rb**: Shared constrained types (dry-types)
- **\<context\>/entities/**: Aggregate roots and entities (dry-struct)
- **\<context\>/values/**: Value objects

**Infrastructure Layer** (`app/infrastructure/`):
- **database/orm/**: Sequel ORM models (thin, no business logic)
- **database/repositories/**: Maps ORM ↔ domain entities
- **auth/**: SSO/OAuth gateway

**Application Layer** (`app/application/`):
- **controllers/routes/**: API route handlers (Roda). Routes are under `/api/` namespace
- **services/**: Use cases, orchestration
- **policies/**: Authorization rules (role-based access control)
- **contracts/**: Input validation (dry-validation, imports domain types)

**Presentation Layer** (`app/presentation/`):
- **representers/**: JSON serialization (Roar)

**Cross-cutting Utilities** (`app/lib/`):
- **jwt_credential.rb**: JWT generation/validation using RbNaCl SecretBox

**Refactoring status**: See `CLAUDE.refactor-ddd.md` for current progress.

### Frontend Structure (`frontend_app/`)
- **pages/**: Full-page Vue components (Login, ManageCourse, course/, etc.)
- **components/**: Reusable UI components
- **router/index.js**: Vue Router configuration
- **lib/cookieManager.js**: Cookie utilities for JWT storage

### Service → Policy Pattern
Services use policies for authorization:
```ruby
verify_policy(requestor, :create)
verify_policy(requestor, :view, course, course_id)
```
Policies check roles (admin, creator, instructor, staff, owner) and course enrollment.

### Authentication Flow
1. Frontend uses vue3-google-login for OAuth
2. Token sent to `/api/auth/verify_google_token`
3. Backend returns encrypted JWT (account_id + roles)
4. JWT stored in cookie, sent in Authorization header

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
Open in VS Code and use "Reopen in Container" for a pre-configured Ruby 3.4 + Node.js 22 environment. The container automatically runs `rake setup` on creation, installing dependencies and generating config files.

### Running Both Servers
```bash
# Terminal 1: Frontend (webpack dev server with hot reload)
npm run dev

# Terminal 2: Backend
puma config.ru -t 1:5 -p 9292
```

**IMPORTANT**: Open http://localhost:9292 in your browser (the backend), NOT port 8080. The backend serves both the API and frontend files from `dist/`. The webpack dev server (8080) only handles compilation with hot reload and writes to `dist/`.

## Code Conventions

### Ruby
- Frozen string literals enabled at file top
- Module namespacing: `Tyto::Api`, `Tyto::Routes::*`
- RuboCop for linting
- **Avoid `nil` as state**: Use Null Object pattern instead of returning `nil` for missing/empty states. This eliminates guard clauses and follows "Tell, Don't Ask" principle. Example: `NullTimeRange` instead of `nil` for courses without dates.

### Vue/JavaScript
- Vue Single File Components (.vue)
- Element Plus components auto-imported via unplugin-vue-components

### Git Commits
- **Always ask for manual review before making commits** - do not commit automatically
- Never use "Generated with Claude" line in commit messages
- User is primary committer; use `Co-Authored-By: Claude <noreply@anthropic.com>`

## Project Planning

- **Future work**: See `doc/future-work.md` for planned improvements (CI/CD, testing, etc.)
