# Testing Implementation Plan for TYTO

**Branch**: `ray/tests-initial`
**Status**: Planning complete, ready to implement
**Next action**: Create spec_helper.rb (Step 1 in Implementation Plan)

---

## Current State

### What Exists
- **Backend**: Minitest + Rack::Test gems installed, Rakefile configured for `backend_app/spec/**/*_spec.rb`
- **Test database**: SQLite at `backend_app/db/store/test.db` (can be setup with `RACK_ENV=test bundle exec rake db:setup`)
- **Frontend**: No testing framework installed

### What's Missing
- **No test files** - Zero tests exist in the entire project
- **No spec_helper.rb** - No test configuration or setup
- **No CI/CD** - No automated testing on PRs
- **Frontend** - No Jest/Vitest, no Vue Test Utils

---

## Existing Functions Reference

### API Routes (HTTP Endpoints)

#### Account Routes (`/api/account`)
- `GET /api/account` - List all accounts (admin only)
- `POST /api/account` - Create new account
- `PUT /api/account/:id` - Update account
- `DELETE /api/account/:id` - Delete account

#### Authentication Routes (`/api/auth`)
- `GET /api/auth/verify_google_token` - Auth API endpoint
- `POST /api/auth/verify_google_token` - Verify Google OAuth token and login

#### Course Routes (`/api/course`)
- `GET /api/course` - List courses for authenticated user
- `GET /api/course/list_all` - List all courses (admin only)
- `GET /api/course/:id` - Get course details
- `POST /api/course` - Create new course
- `PUT /api/course/:id` - Update course
- `DELETE /api/course/:id` - Delete course
- `GET /api/course/:id/enroll` - Get enrollments for course
- `POST /api/course/:id/enroll` - Update or add enrollments (bulk)
- `POST /api/course/:id/enroll/:account_id` - Update single enrollment
- `DELETE /api/course/:id/enroll/:account_id` - Remove enrollment

#### Event Routes (`/api/course/:id/event`)
- `GET /api/course/:id/event` - List events for course
- `POST /api/course/:id/event` - Create new event
- `PUT /api/course/:id/event/:event_id` - Update event
- `DELETE /api/course/:id/event/:event_id` - Delete event

#### Location Routes (`/api/course/:id/location`)
- `GET /api/course/:id/location` - List locations for course
- `GET /api/course/:id/location/:location_id` - Get location details
- `POST /api/course/:id/location` - Create new location
- `PUT /api/course/:id/location/:location_id` - Update location
- `DELETE /api/course/:id/location/:location_id` - Delete location

#### Attendance Routes (`/api/course/:id/attendance`)
- `GET /api/course/:id/attendance` - List own attendance (student)
- `GET /api/course/:id/attendance/list_all` - List all attendance (instructor/staff)
- `GET /api/course/:id/attendance/:event_id` - List attendance by event
- `POST /api/course/:id/attendance` - Create attendance record

#### Current Event Routes (`/api/current_event`)
- `GET /api/current_event` - Get ongoing events for authenticated user

---

### Service Layer Methods

#### AccountService (`backend_app/services/account_service.rb`)
- `list_all(requestor)` - List all accounts (admin only)
- `create(requestor, user_data)` - Create new account
- `update(requestor, target_id, user_data)` - Update account
- `remove(requestor, target_id)` - Delete account
- `verify_policy(requestor, action, target_id)` - Private: Check authorization

#### CourseService (`backend_app/services/course_service.rb`)
- `list_all(requestor)` - List all courses (admin only)
- `list(requestor)` - List courses for authenticated user
- `create(requestor, course_data)` - Create new course
- `get(requestor, course_id)` - Get course details
- `update(requestor, course_id, course_data)` - Update course
- `remove(requestor, course_id)` - Delete course
- `remove_enroll(requestor, course_id, account_id)` - Remove enrollment
- `get_enrollments(requestor, course_id)` - Get enrollments for course
- `update_enrollments(requestor, course_id, enrolled_data)` - Bulk update enrollments
- `update_enrollment(requestor, course_id, account_id, enrolled_data)` - Update single enrollment
- `find_course(course_id)` - Private: Find course or raise error
- `verify_policy(requestor, action, course, course_id)` - Private: Check authorization

#### EventService (`backend_app/services/event_service.rb`)
- `list(requestor, course_id)` - List events for course
- `create(requestor, event_data, course_id)` - Create new event
- `find(requestor, time)` - Find ongoing events at given time
- `update(requestor, event_id, course_id, event_data)` - Update event
- `remove_event(requestor, event_id, course_id)` - Delete event
- `find_course(course_id)` - Private: Find course or raise error
- `verify_policy(requestor, action, course_id)` - Private: Check authorization

#### LocationService (`backend_app/services/location_service.rb`)
- `list_all(requestor, course_id)` - List all locations for course
- `get(requestor, location_id)` - Get location details
- `create(requestor, location_data, course_id)` - Create new location
- `update(requestor, course_id, location_id, location_data)` - Update location
- `remove(requestor, target_id, course_id)` - Delete location (prevents if has events)
- `verify_policy(requestor, action, course_id)` - Private: Check authorization

#### AttendanceService (`backend_app/services/attendance_service.rb`)
- `list_all(requestor, course_id)` - List all attendance (instructor/staff)
- `list_by_event(requestor, course_id, event_id)` - List attendance by event
- `list(requestor, course_id)` - List own attendance (student)
- `create(requestor, attendance_data, course_id)` - Create attendance record
- `find_course(course_id)` - Private: Find course or raise error
- `verify_policy(requestor, action, course, course_id)` - Private: Check authorization

#### SSOAuth (`backend_app/services/sso_auth.rb`)
- `fetch_user_info(access_token)` - Fetch user info from Google OAuth API

---

### Model Methods

#### Account (`backend_app/models/account.rb`)
- `add_account(user_data)` - Class: Create account with roles
- `update_account(user_data)` - Instance: Update account and roles
- `attributes` - Instance: Return account attributes with roles

#### Course (`backend_app/models/course.rb`)
- `listByAccountID(account_id)` - Class: List courses for account
- `create_course(account_id, course_data)` - Class: Create course and assign owner
- `attributes(account_id)` - Instance: Return course attributes with enrollment info
- `add_or_update_enrollments(enrolled_data)` - Instance: Bulk update enrollments
- `update_single_enrollment(account_id, enrolled_data)` - Instance: Update single enrollment
- `get_enrollments` - Instance: Get all enrollments for course
- `get_enroll_identity(account_id)` - Private: Get enrollment roles for account
- `add_or_find_account(email)` - Private: Find or create account by email
- `update_course_account_roles(account, roles_string)` - Private: Update roles for account in course

#### Event (`backend_app/models/event.rb`)
- `list_event(course_id)` - Class: List events for course
- `add_event(course_id, event_details)` - Class: Create event
- `find_event(requestor, time)` - Class: Find ongoing events for user
- `attributes` - Instance: Return event attributes with location coordinates

#### Location (`backend_app/models/location.rb`)
- `attributes` - Instance: Return location attributes

#### Attendance (`backend_app/models/attendance.rb`)
- `list_attendance(account_id, course_id)` - Class: List attendance for account/course
- `add_attendance(account_id, course_id, attendance_details)` - Class: Create attendance record
- `find_account_course_role_id(account_id, course_id)` - Class: Find account course role ID
- `attributes` - Instance: Return attendance attributes

#### Role (`backend_app/models/role.rb`)
- Standard Sequel model (no custom methods documented)

---

### Policy Methods

#### AccountPolicy (`backend_app/policies/account_policy.rb`)
- `can_view_all?` - Admin can view all accounts
- `can_create?` - Any authenticated user can create
- `can_view_single?` - Admin or self can view
- `can_update?` - Admin or self can update
- `can_delete?` - Admin or self can delete
- `summary` - Return permission summary
- `self_request?` - Private: Check if requestor is account owner
- `requestor_is_admin?` - Private: Check if requestor is admin

#### CoursePolicy (`backend_app/policies/course_policy.rb`)
- `can_view_all?` - Admin can view all courses
- `can_create?` - Creator role can create courses
- `can_view?` - Enrolled users can view course
- `can_update?` - Instructor/owner/staff can update
- `can_delete?` - Admin or owner can delete
- `summary` - Return permission summary
- `self_enrolled?` - Private: Check if requestor is enrolled
- `requestor_is_admin?` - Private: Check if requestor is admin
- `requestor_is_creator?` - Private: Check if requestor is creator
- `requestor_is_instructor?` - Private: Check if requestor is instructor
- `requestor_is_staff?` - Private: Check if requestor is staff
- `requestor_is_owner?` - Private: Check if requestor is owner

#### EventPolicy (`backend_app/policies/event_policy.rb`)
- `can_create?` - Owner/instructor/staff can create
- `can_view?` - Owner/instructor/staff can view
- `can_update?` - Owner/instructor/staff can update
- `can_delete?` - Owner/instructor/staff can delete
- `summary` - Return permission summary
- `self_enrolled?` - Private: Check if requestor is enrolled
- `requestor_is_admin?` - Private: Check if requestor is admin
- `requestor_is_instructor?` - Private: Check if requestor is instructor
- `requestor_is_staff?` - Private: Check if requestor is staff
- `requestor_is_owner?` - Private: Check if requestor is owner

#### LocationPolicy (`backend_app/policies/location_policy.rb`)
- `can_create?` - Owner/instructor/staff can create
- `can_view?` - Any enrolled user can view
- `can_update?` - Owner/instructor/staff can update
- `can_delete?` - Owner/instructor/staff can delete
- `summary` - Return permission summary
- `requestor_is_admin?` - Private: Check if requestor is admin
- `requestor_is_instructor?` - Private: Check if requestor is instructor
- `requestor_is_staff?` - Private: Check if requestor is staff
- `requestor_is_owner?` - Private: Check if requestor is owner

#### AttendancePolicy (`backend_app/policies/attendance_policy.rb`)
- `can_create?` - Enrolled users can create
- `can_view?` - Enrolled users can view own
- `can_view_all?` - Instructor/owner/staff can view all
- `can_update?` - Enrolled users can update own
- `summary` - Return permission summary
- `self_enrolled?` - Private: Check if requestor is enrolled
- `requestor_is_instructor?` - Private: Check if requestor is instructor
- `requestor_is_staff?` - Private: Check if requestor is staff
- `requestor_is_owner?` - Private: Check if requestor is owner

#### RolePolicy (`backend_app/policies/role_policy.rb`)
- ⚠️ **Note**: This policy exists but is not currently used in the codebase

---

### Utility/Library Methods

#### JWTCredential (`backend_app/lib/jwt_credential.rb`)
- `generate_key` - Class: Generate new encryption key (Base64)
- `generate_jwt(account_id, roles)` - Class: Generate JWT token
- `decode_jwt(auth_header)` - Class: Decode JWT token from Authorization header
- `validate_input(account_id, roles)` - Private: Validate JWT generation inputs
- `fetch_decoded_key` - Private: Get and decode JWT key from ENV

---

## Recommended Testing Strategy

### Phase 1: Backend Foundation (Lowest Friction)
Start with backend because:
- All dependencies already installed (Minitest, Rack::Test)
- Rakefile already configured
- Clear service/policy/model architecture is easy to test
- No external dependencies to mock initially

### Phase 2: Frontend Foundation
Add frontend testing after backend is stable:
- Install Vitest + Vue Test Utils
- Start with pure utility functions (cookieManager.js)
- Progress to component testing

---

## Decisions Made

1. **Integration tests first** - Test routes via Rack::Test (full HTTP → Route → Service → Model → DB). Add unit tests only for objects/functions with critical custom logic.

2. **Database strategy** - Start test suite with empty database (truncate all tables once at startup). Use transaction rollbacks between individual tests for speed and isolation.

3. **Authentication in tests** - Use existing `JWTCredential.generate_jwt(account_id, roles)` to create valid tokens, bypassing Google OAuth. Note: `JWTCredential` is hand-rolled crypto (RbNaCl SecretBox, not standard JWT) - add unit tests for this critical custom code.

4. **Fixed typo** - Renamed `loaction_service.rb` → `location_service.rb`

5. **RolePolicy unused** - Note as dead code for now. Related security concern: PUT routes may allow updating sensitive DB fields (like roles). Add to future work: implement input whitelisting (Sequel's `set_allowed_columns` or manual filtering) and security tests.

6. **Test data strategy** - Before test suite: truncate all tables, then seed roles (same as production). Each test creates its own accounts/courses within a transaction. Roles persist across tests (seeded once at startup).

7. **Minitest spec style** - Use `describe`/`it` blocks (not `class`/`def test_*`). Use `_()` wrapper with expectation matchers (`must_equal`, `must_be_nil`, `wont_be_empty`, etc.).

---

## Questions Discussed & Resolved

### Priority & Scope

1. **Backend vs Frontend first?** ✅ RESOLVED
   - Backend is ready to go (deps installed, rake configured)
   - Frontend requires installing Vitest/Jest first
   - **Decision**: Start with backend

2. **Unit tests vs Integration tests?** ✅ RESOLVED
   - **Unit**: Test services/policies/models in isolation (faster, more granular)
   - **Integration**: Test full HTTP request/response cycle via Rack::Test (slower, more realistic)
   - **Decision**: Integration tests first. Unit tests only for critical custom logic (e.g., JWTCredential).

3. **What should we NOT test initially?** ✅ RESOLVED
   - Google OAuth (requires mocking external API)
   - Frontend components with Google Maps (complex external dependency)
   - **Decision**: Skip these initially, focus on backend routes

### Technical Decisions

4. **Test database strategy?** ✅ RESOLVED
   - Option A: Run migrations, use transactions, rollback after each test (faster)
   - Option B: Fresh database setup before each test file (slower, more isolated)
   - Option C: Truncate tables between tests (middle ground)
   - **Decision**: Empty DB at suite start (truncate all), then transaction rollbacks between tests

5. **Authentication in tests?** ✅ RESOLVED
   - Need to create test accounts and generate valid JWTs
   - Option A: Test helper that generates JWTs directly (bypass OAuth)
   - Option B: Seed test accounts with known credentials
   - **Decision**: Use `JWTCredential.generate_jwt` directly via test helper. Note: this is hand-rolled crypto (RbNaCl SecretBox), so add unit tests for it.

6. **Fixtures vs Factories?** ✅ RESOLVED
   - Fixtures: Static test data in YAML files
   - Factories: Generate test data programmatically (like factory_bot)
   - Plain Sequel: Create records directly in tests
   - **Decision**: Each test creates its own data via Sequel. Seed roles at startup (same as production).

7. **Fix `loaction_service.rb` typo?** ✅ RESOLVED
   - **Decision**: Fixed. Renamed to `location_service.rb`.

8. **RolePolicy unused - test it, remove it, or ignore?** ✅ RESOLVED
   - Investigated: RolePolicy exists but isn't wired into AccountService
   - Related security concern: PUT routes may allow updating sensitive DB fields
   - **Decision**: Note as dead code. Added security items to `doc/future-work.md` (input whitelisting, security tests).

9. **Test data seeding strategy?** ✅ RESOLVED
   - Current seeds create admin account with `ENV['ADMIN_EMAIL']`
   - Roles come from seeds in production
   - **Decision**: Seed roles at test suite startup (same as production). Each test creates its own accounts/courses. Roles persist; other data rolls back.

---

## Proposed Test Implementation Order

### Tier 1: Most Impactful, Least Painful

| Test Target | Why | Complexity |
|-------------|-----|------------|
| `AccountService` | Simple CRUD, validates service pattern | Low |
| `Account` model | Tests associations, validates ORM setup | Low |
| `POST /api/account` route | Full stack integration, proves test setup works | Medium |

### Tier 2: Core Business Logic

| Test Target | Why | Complexity |
|-------------|-----|------------|
| `CourseService` | Central to app, has complex enrollment logic | Medium |
| `CoursePolicy` | Authorization is critical, many permission checks | Medium |
| `Course` model | Complex associations (events, locations, enrollments) | Medium |
| Course routes | Validates course CRUD + enrollment endpoints | Medium |

### Tier 3: Remaining Features

| Test Target | Why | Complexity |
|-------------|-----|------------|
| `EventService` + `Event` model | Time-based queries (`find_event`) | Medium |
| `AttendanceService` + policy | GPS validation, role-based filtering | Medium |
| `LocationService` | Prevents deletion with associated events | Low |
| Remaining routes | Full API coverage | Varies |

### Tier 4: Edge Cases & Frontend

| Test Target | Why | Complexity |
|-------------|-----|------------|
| `JWTCredential` | Critical auth component | High (crypto) |
| `SSOAuth` | External API calls | High (mocking) |
| `cookieManager.js` (frontend) | Pure utility, testable | Low |
| Vue components | UI behavior | High |

---

## Implementation Plan

### Directory Structure to Create

```
backend_app/
  spec/
    spec_helper.rb              # Test configuration, DB setup, transaction wrapping
    support/
      test_helpers.rb           # JWT generation, account creation helpers
    lib/
      jwt_credential_spec.rb    # Unit tests for critical crypto code
    routes/
      account_route_spec.rb     # Integration tests for /api/account
      course_route_spec.rb      # Integration tests for /api/course
      authentication_route_spec.rb  # Integration tests for /api/auth
      current_event_route_spec.rb   # Integration tests for /api/current_event
```

---

### Step 1: Create spec_helper.rb

**File**: `backend_app/spec/spec_helper.rb`

**Purpose**: Configure test environment, database handling, and load helpers.

**Must include**:

```ruby
# frozen_string_literal: true

# 1. Environment setup
ENV['RACK_ENV'] = 'test'

# 2. Load application
require_relative '../../require_app'
require_app

# 3. Load test dependencies
require 'minitest/autorun'
require 'minitest/spec'  # Enable spec-style describe/it blocks
require 'rack/test'

# 4. Load test helpers
require_relative 'support/test_helpers'

# 5. Database setup (run ONCE before all tests)
DB = Todo::Api.db
DB.tables.each { |table| DB[table].delete }

# Seed roles (same as production)
['admin', 'creator', 'member', 'owner', 'instructor', 'staff', 'student'].each do |role_name|
  Todo::Role.find_or_create(name: role_name)
end

# 6. Transaction wrapping (each test runs in rolled-back transaction)
class Minitest::Spec
  around do |tests|
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) do
      tests.call
    end
  end
end
```

---

### Step 2: Create test_helpers.rb

**File**: `backend_app/spec/support/test_helpers.rb`

**Purpose**: Common helper methods for all tests.

**Must include**:

```ruby
module TestHelpers
  # Create a test account and return it
  def create_test_account(name: 'Test User', email: nil, roles: ['creator'])
    email ||= "test-#{SecureRandom.hex(4)}@example.com"
    Todo::Account.add_account(
      name: name,
      email: email,
      roles: roles,
      access_token: 'test_token',
      avatar: nil
    )
  end

  # Generate auth header for a given account
  def auth_header_for(account)
    token = Todo::JWTCredential.generate_jwt(
      account.id,
      account.roles.map(&:name)
    )
    { 'HTTP_AUTHORIZATION' => "Bearer #{token}" }
  end

  # Shortcut: create account and return its auth header
  def authenticated_header(roles: ['creator'])
    account = create_test_account(roles: roles)
    [account, auth_header_for(account)]
  end

  # Parse JSON response body
  def json_response
    JSON.parse(last_response.body)
  end

  # Content-Type header for JSON requests
  def json_headers(auth_header = {})
    { 'CONTENT_TYPE' => 'application/json' }.merge(auth_header)
  end
end
```

---

### Step 3: Create First Integration Test (Account Routes)

**File**: `backend_app/spec/routes/account_route_spec.rb`

**Purpose**: Verify test infrastructure works end-to-end.

**Example spec-style structure**:

```ruby
# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Account Routes' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Todo::Api
  end

  describe 'GET /api/account' do
    it 'returns all accounts for admin' do
      account, auth = authenticated_header(roles: ['admin'])
      get '/api/account', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
    end

    it 'returns forbidden for non-admin' do
      account, auth = authenticated_header(roles: ['creator'])
      get '/api/account', nil, auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'POST /api/account' do
    it 'creates account with valid data' do
      account, auth = authenticated_header
      post '/api/account', { name: 'New User', email: 'new@test.com', roles: ['creator'] }.to_json, json_headers(auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
    end
  end

  # ... more tests
end
```

**Tests to write**:
- GET /api/account: admin succeeds, non-admin forbidden
- POST /api/account: valid data succeeds, no auth fails
- PUT /api/account/:id: own account succeeds, other account forbidden (unless admin)
- DELETE /api/account/:id: own account succeeds, other account forbidden (unless admin)

---

### Step 4: Create JWTCredential Unit Tests

**File**: `backend_app/spec/lib/jwt_credential_spec.rb`

**Purpose**: Unit test critical custom crypto code.

**Example spec-style structure**:

```ruby
# frozen_string_literal: true

require_relative '../spec_helper'

describe Todo::JWTCredential do
  describe '.generate_jwt' do
    it 'returns a string token' do
      token = Todo::JWTCredential.generate_jwt(1, ['creator'])
      _(token).must_be_kind_of String
      _(token).wont_be_empty
    end

    it 'raises error with nil account_id' do
      _(-> { Todo::JWTCredential.generate_jwt(nil, ['creator']) }).must_raise Todo::JWTCredential::ArgumentError
    end

    it 'raises error with empty roles' do
      _(-> { Todo::JWTCredential.generate_jwt(1, []) }).must_raise Todo::JWTCredential::ArgumentError
    end
  end

  describe '.decode_jwt' do
    it 'returns account_id and roles from valid token' do
      token = Todo::JWTCredential.generate_jwt(42, ['admin', 'creator'])
      result = Todo::JWTCredential.decode_jwt("Bearer #{token}")

      _(result['account_id']).must_equal 42
      _(result['roles']).must_equal ['admin', 'creator']
    end

    it 'returns error for invalid token' do
      result = Todo::JWTCredential.decode_jwt('Bearer invalid_token')
      _(result).must_include :error
    end

    it 'raises error without Bearer prefix' do
      token = Todo::JWTCredential.generate_jwt(1, ['creator'])
      _(-> { Todo::JWTCredential.decode_jwt(token) }).must_raise Todo::JWTCredential::ArgumentError
    end
  end
end
```

---

### Step 5: Create Course Route Integration Tests

**File**: `backend_app/spec/routes/course_route_spec.rb`

**Purpose**: Test core business logic (courses, enrollments).

**Tests to write** (spec-style):

```ruby
describe 'Course Routes' do
  describe 'GET /api/course' do
    it 'returns all courses for admin'
    it 'returns forbidden for non-admin'
  end

  describe 'GET /api/course/:id' do
    it 'returns course for enrolled user'
    it 'returns forbidden for non-enrolled user'
  end

  describe 'POST /api/course' do
    it 'creates course with creator role'
    it 'returns forbidden without creator role'
    it 'makes creator the owner of new course'
  end

  describe 'PUT /api/course/:id' do
    it 'updates course as owner'
    it 'updates course as instructor'
    it 'returns forbidden as student'
  end

  describe 'DELETE /api/course/:id' do
    it 'deletes course as owner'
    it 'deletes course as admin'
    it 'returns forbidden when requester is not the course owner (e.g., instructor or student)'
    
  end

  describe 'POST /api/course/:id/enroll' do
    it 'enrolls user as owner'
    it 'returns forbidden as student'
    it 'allows enrolled user to view course'
  end
end
```

---

### Step 6: Create Event Route Integration Tests

**File**: `backend_app/spec/routes/event_route_spec.rb` (or within course_route_spec.rb)

**Tests to write** (spec-style):

```ruby
describe 'Event Routes' do
  describe 'POST /api/course/:id/event' do
    it 'creates event as instructor'
    it 'returns forbidden as student'
  end

  describe 'GET /api/course/:id/event' do
    it 'lists events for enrolled course'
  end

  describe 'PUT /api/course/:id/event/:event_id' do
    it 'updates event as owner'
  end

  describe 'DELETE /api/course/:id/event/:event_id' do
    it 'deletes event as owner'
  end
end

describe 'Current Event Routes' do
  describe 'GET /api/current_event' do
    it 'returns ongoing events'
    it 'excludes past events'
  end
end
```

---

### Step 7: Create Location & Attendance Tests

**Files**: Continue in course_route_spec.rb or create separate files.

**Location tests** (spec-style):
```ruby
describe 'Location Routes' do
  describe 'POST /api/course/:id/location' do
    it 'creates location as instructor'
  end

  describe 'GET /api/course/:id/location' do
    it 'lists locations for enrolled users'
    it 'returns forbidden for non-enrolled users'
  end

  describe 'PUT /api/course/:id/location/:location_id' do
    it 'updates location as instructor'
    it 'returns forbidden as student'
  end

  describe 'DELETE /api/course/:id/location/:location_id' do
    it 'fails when location has associated events'  # Important business rule
    it 'succeeds when location has no events'
  end
end
```

**Attendance tests** (spec-style):
```ruby
describe 'Attendance Routes' do
  describe 'POST /api/course/:id/attendance' do
    it 'records attendance as student'
    it 'includes GPS coordinates'
  end

  describe 'GET /api/course/:id/attendance' do
    it 'returns own attendance for student'
  end

  describe 'GET /api/course/:id/attendance/list_all' do
    it 'returns all attendance for instructor'
    it 'returns forbidden for student'
  end

  describe 'PUT /api/course/:id/attendance/:attendance_id' do
    it 'allows instructor to update attendance record'
    it 'returns forbidden for student'
  end

  describe 'DELETE /api/course/:id/attendance/:attendance_id' do
    it 'allows instructor to delete an attendance record'
    it 'returns forbidden for student'
  end
end
```

---

### Implementation Order (Checklist)

- [x] **1. Create directory structure**: `mkdir -p backend_app/spec/support backend_app/spec/lib backend_app/spec/routes`
- [x] **2. Create spec_helper.rb**: DB setup, transaction wrapping, load helpers
- [x] **3. Create test_helpers.rb**: Account creation, JWT helpers
- [x] **4. Verify setup**: Run `bundle exec rake spec` (should pass with 0 tests)
- [x] **5. First test**: `account_route_spec.rb` with one simple test
- [x] **6. Run and verify**: `bundle exec rake spec` passes
- [x] **7. JWTCredential unit tests**: `jwt_credential_spec.rb`
- [x] **8. Expand account tests**: Full CRUD coverage
- [x] **9. Course route tests**: Core business logic
- [x] **10. Event/Location/Attendance tests**: Remaining features

---

### Commands Reference

```bash
# Setup test database (run once)
RACK_ENV=test bundle exec rake db:migrate

# Run all tests
bundle exec rake spec
# or simply:
rake

# Run specific test file
bundle exec ruby backend_app/spec/routes/account_route_spec.rb

# Run with verbose output
bundle exec rake spec TESTOPTS="--verbose"
```

---

## Open Issues

1. **Commented code**: `AttendanceTrack.vue` route is commented out in frontend router. Low priority - frontend testing is Phase 2.

---

## Notes

- Rakefile expects tests at `backend_app/spec/**/*_spec.rb`
- Test database: SQLite at `backend_app/db/store/test.db`
- Roles are seeded once at test suite startup, persist across all tests
- Each test runs in a transaction that rolls back (fast isolation)
- Use `auth_header_for(account)` helper to authenticate requests
- Use `json_response` helper to parse response body

### Minitest Spec Style Reference

```ruby
# Structure
describe 'Subject' do
  it 'does something' do
    # test code
  end
end

# Expectations (use _() wrapper)
_(value).must_equal expected
_(value).wont_equal unexpected
_(value).must_be_nil
_(value).wont_be_nil
_(value).must_be_empty
_(value).wont_be_empty
_(value).must_include item
_(value).must_be_kind_of Class
_(value).must_match /regex/
_(-> { code }).must_raise ErrorClass
```
