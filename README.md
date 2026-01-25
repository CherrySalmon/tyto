# Demonstration Todo Web App Combining Roda + Vue.js w/ Webpack

This is a small project to demonstrate how to combine Roda and Vue.js with webpack.
Running the application allows you to add/delete a todos the todo list.

## Quick Start with DevContainer (Recommended)

The DevContainer provides a pre-configured Ruby 3.4 + Node.js 22 environment with all required tools.

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/)
- [Docker](https://www.docker.com/products/docker-desktop)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Getting Started

1. Clone the repository and open in VS Code
2. Click "Reopen in Container" when prompted (or use Command Palette: `Dev Containers: Reopen in Container`)
3. Wait for container to build - `rake setup` runs automatically, installing dependencies and copying config files
4. Generate and configure credentials:
   ```shell
   bundle exec rake generate:jwt_key  # Copy this output
   ```
   - Set `JWT_KEY` in `backend_app/config/secrets.yml` (paste the generated key)
   - Set `ADMIN_EMAIL` in `backend_app/config/secrets.yml` (your Google account email)
   - Set `VUE_APP_GOOGLE_CLIENT_ID` in `frontend_app/.env.local` (see [doc/google.md](doc/google.md))
5. Setup databases:

   ```shell
   bundle exec rake db:setup                 # Development
   RACK_ENV=test bundle exec rake db:setup   # Test
   ```

### Exiting the DevContainer

- Close VS Code to stop the container
- Use Command Palette: `Dev Containers: Reopen Folder Locally` to switch back

## Manual Setup (Without DevContainer)

If not using DevContainer, ensure you have Ruby 3.4+ and Node.js 20+ installed, then:

```shell
rake setup                         # Install dependencies, copy config files
bundle exec rake generate:jwt_key  # Generate JWT_KEY, copy output to secrets.yml
# Edit backend_app/config/secrets.yml - set JWT_KEY and ADMIN_EMAIL
# Edit frontend_app/.env.local - set VUE_APP_GOOGLE_CLIENT_ID (see doc/google.md)
bundle exec rake db:setup                 # Development database
RACK_ENV=test bundle exec rake db:setup   # Test database
```

## Running the Application

Start both frontend and backend servers:

```shell
# Terminal 1: Frontend dev server (http://localhost:8080)
npm run dev

# Terminal 2: Backend server (http://localhost:9292)
puma config.ru
#or puma -e development config.ru
```

In production, access `http://0.0.0.0:9292` for the combined frontend and backend.

## Testing

```shell
bundle exec rake spec
```

## Deployment
- Deploy your project to heroku. [Check out](doc/heroku.md)

## System Architecture

The application is split into files/folders for back-end and front-end. See the relevant files for each part of the application below.

### Frontend

```text
[dist]
    ├── favicon.ico
    ├── index.html
    ├── main.bundle.js
    └── main.bundle.js.LICENSE.txt

[frontend_app]
    ├── App.vue
    ├── main.js
    ├── [pages]
        ├── AboutPage.Vue
        ├── HomePage copy.vue
        └── HomePage.vue
    ├── [router]
        └── index.js
    ├── [static]
        ├── favicon.ico
        ├── global.css
        └── images.png
    └── [templates]
        └── index.html

[node_modules]

package-lock.json
package.json

[webpack]
    ├── webpack.common.js
    ├── webpack.dev.js
    └── webpack.prod.js
```

### Backend

```text
.ruby-version
Gemfile
Gemfile.lock
Procfile
Procfile.dev
Rakefile

[backend_app]
    ├── [config]
        ├── envirnoment.rb
        └── secrets_example.yml
    ├── [controllers]
        └── App.rb
    ├── [db]
        ├── [migration]
            └── 001_todos_create.rb
        └── [store]
            └── development.db
    └── [models]
        └── todo.rb
    
config.ru
require_app.rb
```

## To-dos
- [ ] Add more test coverage
- [ ] Review and merge `taylor/migrate-to-rspack` branch
- [ ] Review and merge `jerry/service-security` branch
- [ ] Review and merge `tiffany/fix-mark-attendance` branch
- [ ] Review and merge `jerry/feature-assingment-manage` branch
- [ ] Complete integration testing for merged branches

## Active Development Branches

This section tracks the status, goals, and key changes for active development branches.

### taylor/migrate-to-rspack

**Status:** Not merged  
**Goal:** Migrate the build system from Webpack to Rspack for improved build performance and faster development experience.

**Key Changes:**
- Replaced webpack configuration files with rspack equivalents
- Updated `package.json` dependencies
- Created new rspack configuration files:
  - `rspack/rspack.common.js`
  - `rspack/rspack.dev.js`
  - `rspack/rspack.prod.js`
- Updated package-lock.json with rspack dependencies

**Actions:**
- Review build performance improvements
- Test development and production builds
- Verify all webpack features are properly migrated
- Update documentation if needed

---

### jerry/service-security

**Status:** Not merged  
**Goal:** Enhance application security by moving SSO (Single Sign-On) authentication logic to the backend and implementing secure cookie handling.

**Key Changes:**
- Moved Google OAuth login flow from frontend to backend
- Implemented secure cookie handling for authentication tokens
- Updated `backend_app/controllers/routes/authentication.rb` with backend OAuth flow
- Modified `frontend_app/pages/Login.vue` to work with backend authentication
- Added cookie security tests
- Created `cookie_secure_text.html` documentation

**Actions:**
- Review security implementation
- Test authentication flow end-to-end
- Verify cookie security settings
- Ensure refresh token handling works correctly
- Test cross-browser compatibility

---

### tiffany/fix-mark-attendance

**Status:** Not merged  
**Goal:** Enable owners, TAs, and instructors to mark attendance for students, improving the attendance management workflow.

**Key Changes:**
- Added attendance marking functionality for authorized roles (owner/TA/instructor)
- Updated `backend_app/policies/assignment_policy.rb` with role-based permissions
- Modified `backend_app/services/attendance_service.rb` to support marking attendance
- Updated `backend_app/models/attendance.rb` and `backend_app/models/event.rb`
- Refactored event fetching logic
- Added account ID to request body for attendance marking

**Actions:**
- Review role-based permission logic
- Test attendance marking for different user roles
- Verify that students cannot mark their own attendance inappropriately
- Test edge cases (multiple TAs, concurrent marking, etc.)

---

### jerry/feature-assingment-manage

**Status:** Not merged  
**Goal:** Implement comprehensive assignment management features including creation, submission handling, and role-based access control.

**Key Changes:**
- Created assignment entity and CRUD operations
- Implemented submission management system
- Added `backend_app/models/assignemnt.rb` and `backend_app/models/submission.rb`
- Created `backend_app/policies/assignment_policy.rb` and `backend_app/policies/submission_policy.rb`
- Implemented `backend_app/services/assignment_service.rb` and `backend_app/services/submission_service.rb`
- Added database migrations for assignments and submissions
- Implemented file upload restrictions (students can only upload one latest file)
- Added QMD file format support
- UI improvements for submission blocks

**Actions:**
- Review assignment and submission CRUD operations
- Test file upload functionality and restrictions
- Verify role-based access control (students, TAs, instructors, owners)
- Test assignment creation, editing, and deletion workflows
- Verify submission upload and management features

---

### jerry/feature-show-attendance

**Status:** Merged ✓  
**Goal:** Display attendance records with download capabilities and attendance distribution visualization.

**Key Changes:**
- Implemented GET `/attendance/:event_id` API endpoint
- Added attendance record download functionality
- Created attendance distribution visualization
- Added list all attendance API endpoint
- Extended login token expiration time
- Improved responsive web design (RWD) for forms and dialogs
- Fixed location deletion restrictions (locations with attendance cannot be deleted)

**Actions:**
- ✓ Completed - Branch has been merged to develop
- Monitor for any issues in production
- Consider additional enhancements based on user feedback