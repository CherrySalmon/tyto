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

## Remaining Issues (8 failures)

### 500 Errors - Need Server Log Investigation
1. **Account creation** (1 test) - `POST /api/account` returns 500
2. **Enrollment update** (2 tests) - `POST /api/course/:id/enroll` returns 500
3. **Attendance creation** (2 tests) - `POST /api/course/:id/attendance` returns 500
4. **Location deletion with events** (1 test) - Returns 500 instead of 404
5. **Event not found** (1 test) - Returns 500 instead of 404

### Authorization Issues
6. **Location access control** (1 test) - Non-enrolled users get 200 instead of 403

### Next Steps

1. ✅ ~~Fix trivial issues (Issues #1, #2, #3)~~ - **DONE**
2. **Check server error logs** for 500 error stack traces
3. **Likely causes**:
   - Validation errors in Account/Enrollment/Attendance models
   - Missing required fields or associations
   - Type mismatches in service layer
4. **Add proper error handling** for event/location not found scenarios
5. **Fix LocationService authorization** for non-enrolled users
