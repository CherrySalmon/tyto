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
bundle exec rake db:setup      # Migrate and seed database
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
- **controllers/routes/**: API route handlers (Roda). Routes are under `/api/` namespace
- **services/**: Business logic + authorization checks (CourseService, AccountService, etc.)
- **policies/**: Authorization rules (role-based access control)
- **models/**: Sequel ORM models with associations
- **lib/jwt_credential.rb**: JWT generation/validation using RbNaCl SecretBox

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

## Development

### DevContainer
Open in VS Code and use "Reopen in Container" for a pre-configured Ruby 3.4 + Node.js 22 environment. The container automatically runs `rake setup` on creation, installing dependencies and generating config files.

### Running Both Servers
```bash
# Terminal 1: Frontend
npm run dev

# Terminal 2: Backend
puma config.ru -t 1:5 -p 9292
```

Production serves frontend from `dist/` via Roda's `r.public` plugin.

## Code Conventions

### Ruby
- Frozen string literals enabled at file top
- Module namespacing: `Todo::Api`, `Todo::Routes::*`
- RuboCop for linting

### Vue/JavaScript
- Vue Single File Components (.vue)
- Element Plus components auto-imported via unplugin-vue-components

### Git Commits
- Never use "Generated with Claude" line in commit messages
- User is primary committer; use `Co-Authored-By: Claude <noreply@anthropic.com>`
