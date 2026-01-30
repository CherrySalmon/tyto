# ![Tyto](frontend_app/static/favicon.png) Tyto

A full-stack course management and attendance tracking application.

- **Backend**: Ruby (Roda + Sequel ORM) with Domain-Driven Design architecture
- **Frontend**: Vue 3 + Vue Router + Element Plus UI
- **Build**: Webpack
- **Auth**: Google OAuth with JWT tokens

The backend follows a **Domain-Driven Design (DDD)** architecture. For architectural details and patterns, see the `/ddd-refactoring` skill in Claude Code.

## Setup

**Requirements:** Ruby 3.4+, Node.js 20+

1. Install dependencies and copy config templates:

   ```shell
   rake setup
   ```

2. Generate JWT key:

   ```shell
   bundle exec rake generate:jwt_key
   ```

3. Configure `backend_app/config/secrets.yml`:
   - `JWT_KEY`: Paste the generated key from step 2
   - `ADMIN_EMAIL`: Your Google account email (for admin access)

4. Configure `frontend_app/.env.local`:
   - `VUE_APP_GOOGLE_CLIENT_ID`: Google OAuth client ID (see [doc/google.md](doc/google.md))
   - `VUE_APP_GOOGLE_MAP_KEY`: Google Maps API key (for location features)

5. Setup databases:

   ```shell
   bundle exec rake db:setup                 # Development database
   RACK_ENV=test bundle exec rake db:setup   # Test database
   ```

### DevContainer (Optional)

A DevContainer configuration is available for VS Code + Docker users. Open the project in VS Code and select "Reopen in Container" when prompted. The container runs `rake setup` automatically, then follow steps 2-5 above.

## Running Locally

Start both servers in separate terminals:

```shell
# Terminal 1: Frontend (webpack dev server with hot reload)
rake run:frontend

# Terminal 2: Backend API server
rake run:api
```

**Important:** Open <http://localhost:9292> in your browser (the backend port), not 8080. The backend serves both the API and the frontend files from `dist/`. The webpack dev server on port 8080 only handles compilation.

## Testing

```shell
bundle exec rake spec    # Run all backend tests
bundle exec rake         # Same (default task)
```

Ensure the test database is set up first:

```shell
RACK_ENV=test bundle exec rake db:setup
```

## Database Commands

```shell
bundle exec rake db:migrate     # Run pending migrations
bundle exec rake db:seed        # Seed database with sample data
bundle exec rake db:setup       # Migrate + seed
bundle exec rake db:reset       # Drop + migrate + seed (destructive)
bundle exec rake db:drop        # Delete database (destructive)
```

## Documentation

- [Google OAuth Setup](doc/google.md) — Configure Google Cloud credentials
- [Heroku Deployment](doc/heroku.md) — Deploy to production
- [Future Work](doc/future-work.md) — Planned improvements and known issues

## Key Dependencies

**Backend:**

- [Roda](https://roda.jeremyevans.net/) — Routing
- [Sequel](https://sequel.jeremyevans.net/) — Database ORM
- [dry-struct](https://dry-rb.org/gems/dry-struct/) — Domain entities
- [dry-operation](https://dry-rb.org/gems/dry-operation/) — Railway-oriented services
- [Roar](https://github.com/trailblazer/roar) — JSON representers

**Frontend:**

- [Vue 3](https://vuejs.org/)
- [Element Plus](https://element-plus.org/) — UI components
- [vue3-google-login](https://github.com/syuilo/vue3-google-login) — OAuth
