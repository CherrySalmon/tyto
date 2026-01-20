# Test Failures - Code Issues Report

**Initial Results**: 72 runs, 132 assertions, **13 failures**, 0 errors
**Current Results**: 72 runs, 136 assertions, **8 failures**, 0 errors ✅

## Fixed Issues (5 tests passing)
✅ Event update authorization (3 tests) - Added course_id parameter
✅ Account self-update (1 test) - Fixed JWT key mismatch + type conversion
✅ Account self-delete (1 test) - Fixed JWT key mismatch + type conversion

## Critical Issues Found

### 1. AccountPolicy - Wrong Key Access
**File**: `backend_app/policies/account_policy.rb:49`

**Issue**: Compares `@requestor['id']` but JWT payload uses `'account_id'`
```ruby
def self_request?
  @requestor['id'] == @this_account  # ❌ Wrong key
end
```

**Fix**:
```ruby
def self_request?
  @requestor['account_id'] == @this_account
end
```

**Impact**: Users cannot update/delete their own accounts (403 forbidden)
- `PUT /api/account/:id` - Own account update fails
- `DELETE /api/account/:id` - Own account deletion fails

---

### 2. Course Model - Wrong Return Type
**File**: `backend_app/models/course.rb:47`

**Issue**: Returns Hash instead of Array
```ruby
def self.listByAccountID(account_id)
  # ... processes aggregated_courses.values (Array)
  aggregated_courses  # ❌ Returns Hash
end
```

**Fix**:
```ruby
def self.listByAccountID(account_id)
  # ...
  aggregated_courses.values  # ✅ Return Array
end
```

**Impact**: `GET /api/course` returns Hash instead of Array, breaking API contract

---

### 3. EventService - Missing course_id Parameter
**File**: `backend_app/services/event_service.rb:34`

**Issue**: Expects `course_id` in request body but it's not passed
```ruby
def self.update(requestor, event_id, event_data)
  verify_policy(requestor, :update, event_data['course_id'])  # ❌ nil
end
```

**Route context**: URL has `course_id` but doesn't pass it to service
```ruby
# route.rb:161
EventService.update(requestor, event_id, request_body)  # Missing course_id
```

**Fix** (EventService):
```ruby
def self.update(requestor, event_id, course_id, event_data)
  verify_policy(requestor, :update, course_id)
  # ...
end
```

**Fix** (Route):
```ruby
# Pass course_id from URL
EventService.update(requestor, event_id, course_id, request_body)
```

**Impact**: Event updates fail with 403 forbidden for all roles (owner, instructor)

---

### 4. AccountService - Likely Missing Role Check
**Suspected Issue**: Account creation and enrollment operations return 500 errors

**Tests failing**:
- `POST /api/account` - Account creation fails (500)
- `POST /api/course/:id/enroll` - Enrollment update fails (500)
- `POST /api/attendance` - Attendance creation fails (500)

**Action Required**:
- Check server error logs for stack traces
- Likely missing role associations or validation failures
- May be related to the same `requestor['id']` vs `requestor['account_id']` issue in other policies

---

### 5. LocationService - Error Handling Issue
**File**: `backend_app/services/location_service.rb` (needs investigation)

**Test failing**: Deleting location with events returns 500 instead of 404

**Expected**: Business rule should prevent deletion with proper error
**Actual**: Server error (500)

**Action Required**: Add proper foreign key constraint handling or business logic check

---

## Summary

| Issue | Files Affected | Severity | Fix Complexity |
|-------|---------------|----------|----------------|
| Wrong JWT key access | `account_policy.rb` | High | Trivial |
| Wrong return type | `course.rb` | High | Trivial |
| Missing course_id param | `event_service.rb`, `course.rb` route | High | Easy |
| 500 errors (role/validation) | Multiple services | Medium | Needs investigation |
| Location deletion error | `location_service.rb` | Low | Easy |

## Remaining Issues (8 failures) - Analysis & Solutions

---

### Issue #4: Account Creation - Symbol vs String Keys
**File**: `backend_app/models/account.rb:22-34`
**Test**: `POST /api/account` returns 500

**Root Cause**: `add_account` expects symbol keys (`:name`, `:roles`) but JSON.parse returns string keys

```ruby
# Current (line 22-29)
def self.add_account(user_data)
  account = Account.create(
    name: user_data[:name],        # ❌ nil (expects :name but gets 'name')
    email: user_data[:email],
    access_token: user_data[:access_token],
    avatar: user_data[:avatar]
  )
  user_data[:roles].each do |role_name|  # ❌ nil
```

**Solution**: Use string keys or convert to symbols
```ruby
def self.add_account(user_data)
  data = user_data.transform_keys(&:to_sym)  # Convert string keys to symbols
  account = Account.create(
    name: data[:name],
    email: data[:email],
    access_token: data[:access_token],
    avatar: data[:avatar]
  )
  data[:roles].each do |role_name|
    role = Role.find(name: role_name)
    account.add_role(role) if role
  end
  account
end
```

---

### Issue #5: Attendance Creation - Missing Required Field
**File**: `backend_app/models/attendance.rb:18-21`
**Test**: `POST /api/course/:id/attendance` returns 500

**Root Cause**: Model requires `name` field but test doesn't send it

```ruby
# Validation (line 20)
validates_presence %i[name created_at course_id account_id]
```

**Solution Option 1** (Recommended): Make `name` optional or auto-generate
```ruby
def validate
  super
  validates_presence %i[created_at course_id account_id]  # Remove name requirement
end
```

**Solution Option 2**: Use event name as attendance name
```ruby
def self.add_attendance(account_id, course_id, attendance_details)
  event = Event.first(id: attendance_details['event_id'])
  attendance = Attendance.find_or_create(
    account_id: account_id,
    role_id: student_role,
    course_id: course_id,
    event_id: attendance_details['event_id'],
    name: event&.name || 'Attendance',  # Auto-generate from event
    latitude: attendance_details['latitude'],
    longitude: attendance_details['longitude']
  )
end
```

Use solution option 2

---

### Issue #6: Enrollment Update - String/Symbol Mismatch
**File**: `backend_app/models/course.rb:83-98`
**Test**: `POST /api/course/:id/enroll/:account_id` returns 500

**Root Cause**: Similar to #4, `update_single_enrollment` expects string keys but may have mismatches

**Solution**: Check and fix key access in `update_single_enrollment` method
```ruby
# Review lines 83-98 for string vs symbol key usage
# Ensure consistent use of string keys throughout: enrolled_data['email']
```

---

### Issue #7: LocationService - Missing course_id in Authorization
**File**: `backend_app/services/location_service.rb:21-25`
**Test**: Non-enrolled users get 200 instead of 403

**Root Cause**: `get` method doesn't pass `course_id` to verify_policy, so enrollment check is skipped

```ruby
# Current (line 21-24)
def self.get(requestor, location_id)
  verify_policy(requestor, :view)  # ❌ No course_id, can't check enrollment
  location = Location.first(id: location_id)
  location.attributes
end
```

**Solution**: Get course_id from location and verify enrollment
```ruby
def self.get(requestor, location_id)
  location = Location.first(id: location_id) || raise(LocationNotFoundError, "Location not found")
  verify_policy(requestor, :view, location.course_id)  # ✅ Check enrollment
  location.attributes
end
```

---

### Issue #8: Location Deletion - Wrong Exception Type
**File**: `backend_app/services/location_service.rb:48-49`
**Test**: Returns 500 instead of 404

**Root Cause**: Raises generic Exception instead of LocationNotFoundError

```ruby
# Current (line 48-49)
if location.events.any?
  raise("Location...cannot be deleted")  # ❌ StandardError (500)
```

**Solution**: Raise proper exception type
```ruby
if location.events.any?
  raise(LocationNotFoundError, "Location with ID #{target_id} cannot be deleted because it has associated events")
end
```

---

### Issue #9: EventService - Missing Nil Check
**File**: `backend_app/services/event_service.rb:32-36`
**Test**: Returns 500 instead of 404 for invalid event_id

**Root Cause**: Doesn't check if event exists before calling methods

```ruby
# Current (line 32-35)
def self.update(requestor, event_id, course_id, event_data)
  event = Event.first(id: event_id)  # May be nil
  verify_policy(requestor, :update, course_id)
  event.update(event_data)  # ❌ NoMethodError if event is nil
end
```

**Solution**: Raise EventNotFoundError if event doesn't exist
```ruby
def self.update(requestor, event_id, course_id, event_data)
  event = Event.first(id: event_id) || raise(EventNotFoundError, "Event with ID #{event_id} not found")
  verify_policy(requestor, :update, course_id)
  event.update(event_data) || raise("Failed to update event with ID #{event_id}.")
end
```

---

## Implementation Priority

**Quick Fixes (5 min each)**:
1. Issue #8 - Location deletion exception type
2. Issue #9 - Event nil check
3. Issue #7 - LocationService authorization

**Medium Fixes (10-15 min)**:
4. Issue #4 - Account symbol/string keys
5. Issue #5 - Attendance name field
6. Issue #6 - Enrollment investigation

**Expected Result**: All 72 tests passing ✅
