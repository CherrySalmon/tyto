# Quick Setup Initiative - Conversation Summary

This document summarizes the work done in the `ray/chore-quicksetup` branch to streamline project setup.

## Goals

Make first-time project setup as automated and documented as possible.

## Changes Made

### 1. Created `CLAUDE.md`
Project instructions for Claude Code instances, including:
- Project overview (Roda + Vue 3 + Google OAuth)
- Common commands for frontend, backend, database, testing
- Architecture overview (service → policy pattern, authentication flow)
- Configuration requirements

### 2. Automated `rake setup` Task
Single command to bootstrap the project:
- Installs backend dependencies (`bundle install` without production gems)
- Installs frontend dependencies (`npm install`)
- Copies config files (`secrets.yml`, `.env.local`) from examples
- Shows remaining manual steps (JWT_KEY generation, credential setup)

### 3. Rake Tasks
- `rake setup` - First-time project setup
- `rake generate:jwt_key` - Generate JWT_KEY for secrets.yml (renamed from `msg_key`)
- `rake spec` / `rake test` - Run tests (Minitest)
- `rake db:setup` - Migrate + seed
- `rake db:reset` - Drop + migrate + seed
- `rake` (default) - Runs tests

### 4. Configuration Files Created/Updated

**New files:**
- `frontend_app/.env.local.example` - Documents `VUE_APP_GOOGLE_CLIENT_ID` with setup instructions
- `.nvmrc` - Node.js version (22)
- `.claude/settings.json` - Claude Code permissions (allows editing CLAUDE.md)

**Updated files:**
- `backend_app/config/secrets_example.yml` - Clear instructions for `JWT_KEY` and `ADMIN_EMAIL`
- `.ruby-version` - Updated to `3.4.4` (matches devcontainer image)
- `package.json` - Added `engines.node: ">=20.0.0"`
- `.gitignore` - Added patterns for Claude tooling (`CLAUDE.local.md`, `.claude/*`)

### 5. DevContainer Improvements
Updated `.devcontainer/devcontainer.json`:
- Ruby 3.4 image (`mcr.microsoft.com/devcontainers/ruby:1-3.4-bookworm`)
- Node.js 22 pinned
- **Timezone sync** - Container uses host system timezone via `TZ` env var
- **Claude Code feature** (`ghcr.io/anthropics/devcontainer-features/claude-code:1`)
- **VS Code extensions** - Vue/Volar, Git Graph, Draw.io
- **Ruby LSP settings** - Configured to use system Ruby (no version manager)
- Ports 8080/9292 forwarded
- `postCreateCommand` - Installs libsodium, bundle deps, then runs `rake setup`

### 6. Documentation Updates
- `README.md` - Streamlined setup instructions for DevContainer and manual setup
- `CLAUDE.md` - Full project reference for Claude Code, including git commit conventions
- `doc/google.md` - Added specific localhost URLs for OAuth (8080, 9292)
- `doc/heroku.md` - Consolidated db:migrate/seed into db:setup

### 7. Git Commit Conventions
Added to `CLAUDE.md`:
- User is primary committer (not Claude)
- Use `Co-Authored-By: Claude <noreply@anthropic.com>` instead of "Generated with Claude"

### 8. Naming Consistency
- Renamed `rake generate:msg_key` → `rake generate:jwt_key` (matches `JWT_KEY` env var)
- Old `msg_key` task kept as alias for backwards compatibility
- All documentation now consistently uses `JWT_KEY`

## Setup Flow (After This Branch)

### With DevContainer (Recommended)
1. Open in VS Code → "Reopen in Container"
2. Wait for build (`rake setup` runs automatically)
3. Generate JWT_KEY: `bundle exec rake generate:jwt_key`
4. Edit `backend_app/config/secrets.yml` - set `JWT_KEY` and `ADMIN_EMAIL`
5. Edit `frontend_app/.env.local` - set `VUE_APP_GOOGLE_CLIENT_ID` (see `doc/google.md`)
6. Run `bundle exec rake db:setup`

### Manual Setup
```bash
rake setup
bundle exec rake generate:jwt_key  # Copy output to secrets.yml
# Edit secrets.yml - set JWT_KEY and ADMIN_EMAIL
# Edit .env.local - set VUE_APP_GOOGLE_CLIENT_ID
bundle exec rake db:setup
```

## Remaining Manual Steps

These require user-specific values and can't be automated:
1. **JWT_KEY** - Generate with `bundle exec rake generate:jwt_key`, copy to secrets.yml
2. **ADMIN_EMAIL** - User's Google email for admin access
3. **VUE_APP_GOOGLE_CLIENT_ID** - Requires Google API Console setup (see `doc/google.md`)

## Technical Decisions

- **Ruby 3.4.4**: Matches devcontainer image `ruby:1-3.4-bookworm`
- **Node.js 22**: Current LTS, pinned in devcontainer and `.nvmrc`
- **JWT_KEY manual generation**: User runs `rake generate:jwt_key` after setup (avoids gem loading issues during initial bundle install)
- **Timezone sync**: DevContainer inherits host TZ via `containerEnv`
- **Claude Code in devcontainer**: Official Anthropic feature for consistent AI assistance
