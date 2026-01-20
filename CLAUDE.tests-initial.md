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

- [ ] **1. Create directory structure**: `mkdir -p backend_app/spec/support backend_app/spec/lib backend_app/spec/routes`
- [ ] **2. Create spec_helper.rb**: DB setup, transaction wrapping, load helpers
- [ ] **3. Create test_helpers.rb**: Account creation, JWT helpers
- [ ] **4. Verify setup**: Run `bundle exec rake spec` (should pass with 0 tests)
- [ ] **5. First test**: `account_route_spec.rb` with one simple test
- [ ] **6. Run and verify**: `bundle exec rake spec` passes
- [ ] **7. JWTCredential unit tests**: `jwt_credential_spec.rb`
- [ ] **8. Expand account tests**: Full CRUD coverage
- [ ] **9. Course route tests**: Core business logic
- [ ] **10. Event/Location/Attendance tests**: Remaining features

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
