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
- **Auto-generates JWT_KEY** in `secrets.yml` (no manual step needed)
- Copies `frontend_app/.env.local` from example file
- Shows remaining manual steps

### 3. New Rake Tasks
- `rake setup` - First-time project setup
- `rake spec` / `rake test` - Run tests (Minitest)
- `rake db:setup` - Migrate + seed
- `rake db:reset` - Drop + migrate + seed
- `rake` (default) - Runs tests

### 4. Configuration Files Created/Updated

**New files:**
- `frontend_app/.env.local.example` - Documents `VUE_APP_GOOGLE_CLIENT_ID`
- `.nvmrc` - Node.js version (22)
- `.claude/settings.local.json` - Claude Code permissions

**Updated files:**
- `backend_app/config/secrets_example.yml` - Added `ADMIN_EMAIL`, clearer docs
- `.ruby-version` - Updated to `3.4.4`
- `package.json` - Added `engines.node: ">=20.0.0"`

### 5. DevContainer Improvements
Updated `.devcontainer/devcontainer.json`:
- Ruby 3.4 image (`mcr.microsoft.com/devcontainers/ruby:1-3.4-bookworm`)
- Node.js 22 pinned
- **Claude Code feature** (`ghcr.io/anthropics/devcontainer-features/claude-code:1`)
- Ports 8080/9292 forwarded
- `postCreateCommand: "rake setup"` - Auto-runs setup on container creation

### 6. Documentation Updates
- `README.md` - Streamlined setup instructions for DevContainer and manual setup
- `doc/heroku.md` - Consolidated db:migrate/seed into db:setup
- `CLAUDE.md` - Full project reference for Claude Code

## Setup Flow (After This Branch)

### With DevContainer (Recommended)
1. Open in VS Code → "Reopen in Container"
2. Wait for build (`rake setup` runs automatically)
3. Edit `backend_app/config/secrets.yml` - set `ADMIN_EMAIL`
4. Edit `frontend_app/.env.local` - set `VUE_APP_GOOGLE_CLIENT_ID` (see `doc/google.md`)
5. Run `bundle exec rake db:setup`

### Manual Setup
```bash
rake setup
# Edit secrets.yml and .env.local
bundle exec rake db:setup
```

## Remaining Manual Steps

These require user-specific values and can't be automated:
1. **ADMIN_EMAIL** - User's Google email for admin access
2. **VUE_APP_GOOGLE_CLIENT_ID** - Requires Google API Console setup (see `doc/google.md`)

## Technical Decisions

- **Ruby 3.4.4**: Latest stable; devcontainer uses 3.4 image (patch may vary)
- **Node.js 22**: Current LTS, pinned in devcontainer and `.nvmrc`
- **JWT_KEY auto-generation**: Uses `Todo::JWTCredential.generate_key` during setup
- **Claude Code in devcontainer**: Official Anthropic feature for consistent AI assistance
