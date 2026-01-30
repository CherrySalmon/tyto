# Domain Logic Leaks - Triage Document

This document tracks domain logic that has leaked outside of `backend_app/app/domain/`. These issues should be addressed to complete the DDD refactoring.

**Related**: See `CLAUDE.refactor-ddd.md` for the main refactoring plan.

---

## Summary

| Leak Type | Location | Severity | Status |
|-----------|----------|----------|--------|
| Role checking duplication | 4 policy files | CRITICAL | Pending |
| Course role retrieval | 10+ services | CRITICAL | Pending |
| Enrollment business logic | `orm/course.rb` | CRITICAL | Pending |
| Coordinate validation duplication | `record_attendance.rb` | HIGH | Pending |
| Time range logic in ORM | `orm/event.rb` | HIGH | Pending |
| Enrollment check in policy | `course_policy.rb` | HIGH | Pending |
| Course/owner auto-creation | `orm/course.rb` | HIGH | Pending |
| Account auto-creation rule | `orm/course.rb` | HIGH | Pending |
| Role string parsing | `orm/course.rb` | MEDIUM | Pending |

---

## Critical Leaks

### 1. Role Checking Duplicated in Policies

**Problem**: The domain layer has `Enrollment` entity with role-checking predicates, but 4 policy files duplicate this logic using raw `.include?()` checks.

**Domain Layer (Correct)** - `domain/courses/entities/enrollment.rb`:
```ruby
def has_role?(role_name)
  roles.include?(role_name)
end

def owner? = has_role?('owner')
def instructor? = has_role?('instructor')
def staff? = has_role?('staff')
def student? = has_role?('student')
def teaching? = owner? || instructor? || staff?
```

**Leaked Logic** - Duplicated in policies:

1. `application/policies/course_policy.rb` (lines 58-68):
```ruby
def requestor_is_instructor?
  @course_roles.include?('instructor')  # Duplicates Enrollment#instructor?
end

def requestor_is_staff?
  @course_roles.include?('staff')  # Duplicates Enrollment#staff?
end

def requestor_is_owner?
  @course_roles.include?('owner')  # Duplicates Enrollment#owner?
end
```

2. `application/policies/event_policy.rb` (lines 56-66) - Same pattern
3. `application/policies/location_policy.rb` (lines 47-57) - Same pattern
4. `application/policies/attendance_policy.rb` (lines 49-59) - Same pattern

**Fix**: Refactor policies to accept an `Enrollment` entity and use its predicates:
```ruby
# Instead of:
def requestor_is_owner?
  @course_roles.include?('owner')
end

# Use:
def requestor_is_owner?
  @enrollment&.owner?
end
```

---

### 2. Course Role Retrieval Logic in Services

**Problem**: Every service manually queries the ORM and extracts role names, instead of using a repository method.

**Pattern** - Repeated in ~10+ services:
```ruby
def authorize(requestor, course, course_id)
  course_roles = AccountCourse.where(account_id: requestor.account_id, course_id:).map do |ac|
    ac.role.name
  end
  policy = AttendancePolicy.new(requestor, course, course_roles)
  # ...
end
```

**Affected Files**:
- `services/attendances/record_attendance.rb` (lines 45-48)
- `services/attendances/list_user_attendances.rb` (lines 42-46)
- `services/attendances/list_attendances_by_event.rb` (lines 50-54)
- `services/attendances/list_all_attendances.rb` (lines 42-46)
- `services/courses/delete_course.rb` (lines 36-40)
- `services/courses/update_enrollments.rb` (lines 37-41)
- `services/courses/update_enrollment.rb`
- `services/courses/remove_enrollment.rb`
- `services/events/*.rb` (multiple)
- `services/locations/*.rb` (multiple)

**Fix**: Add repository method and use `Enrollment` entity:
```ruby
# Repository method:
def find_enrollment(account_id:, course_id:)
  # Returns Enrollment entity or nil
end

# Service usage:
enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
policy = AttendancePolicy.new(requestor, course, enrollment)
```

---

### 3. Enrollment Business Logic in ORM

**Problem**: Complex enrollment management logic lives in `infrastructure/database/orm/course.rb` instead of domain layer.

**Location**: `infrastructure/database/orm/course.rb`

**Leaked Logic**:

1. **Lines 76-81** - `add_or_update_enrollments()`: Orchestrates account lookup + role updates
2. **Lines 143-151** - `add_or_find_account()`: Creates accounts with 'member' role (domain business rule)
3. **Lines 153-174** - `update_course_account_roles()`: Complex role synchronization:

```ruby
def update_course_account_roles(account, roles_string)
  role_names = roles_string.split(',')  # Input validation in ORM

  # Domain logic: find existing roles
  existing_roles = AccountCourse.where(account_id: account.id, course_id: self.id).map(&:role)

  # Domain logic: delete roles not in new list
  existing_roles.each do |existing_role|
    unless role_names.include?(existing_role.name)
      AccountCourse.where(account_id: account.id, course_id: self.id, role_id: existing_role.id).delete
    end
  end

  # Domain logic: add new roles
  role_names.each do |role_name|
    role_id = Role.first(name: role_name).id
    # ...
  end
end
```

4. **Lines 24-48** - `listByAccountID()`: Aggregates enrollments (should be in repository)
5. **Lines 50-61** - `create_course()`: Creates owner enrollment (domain logic in ORM)
6. **Lines 104-131** - `get_enrollments()`: Reconstructs enrollment data (should be in repository)

**Fix**:
- Move enrollment management to a domain service or `Enrollment` aggregate
- ORM should only handle persistence, not business rules
- Repository handles mapping between ORM and domain entities

---

## High Severity Leaks

### 4. Coordinate Validation Duplicated

**Problem**: Coordinate validation rules exist both in the service AND the domain type.

**Domain Layer** - `domain/courses/values/geo_location.rb`:
```ruby
attribute :longitude, Types::Float.constrained(gteq: -180.0, lteq: 180.0)
attribute :latitude, Types::Float.constrained(gteq: -90.0, lteq: 90.0)
```

**Service Layer** - `services/attendances/record_attendance.rb` (lines 94-110):
```ruby
def validate_coordinates(longitude, latitude)
  # ...
  # Duplicates domain constraints:
  return Failure(bad_request('Longitude must be between -180 and 180')) unless lng.between?(-180, 180)
  return Failure(bad_request('Latitude must be between -90 and 90')) unless lat.between?(-90, 90)
  # ...
end
```

**Fix**: Service should attempt to create `GeoLocation` and catch constraint errors:
```ruby
def validate_coordinates(longitude, latitude)
  return Success(nil) if longitude.nil? && latitude.nil?

  geo = GeoLocation.new(longitude: longitude.to_f, latitude: latitude.to_f)
  Success(geo)
rescue Dry::Struct::Error => e
  Failure(bad_request(e.message))
end
```

---

### 5. Time Range Logic in ORM

**Problem**: The logic "event is active if start_at <= time and end_at >= time" is in ORM query syntax, not expressed as domain predicate.

**Location**: `infrastructure/database/orm/event.rb` (lines 49-53):
```ruby
def self.find_event(requestor, time)
  course_ids = AccountCourse.where(account_id: requestor.account_id).select_map(:course_id)
  events = Event.where{start_at <= time}.where{end_at >= time}.where(course_id: course_ids).all
  events.map(&:attributes)
end
```

**Fix**:
- Domain `Event` entity should have `active_at?(time)` predicate
- Domain `TimeRange` value object already exists - use `TimeRange#contains?(time)`
- Repository can still use SQL for efficiency, but domain expresses the concept

---

### 6. Enrollment Check in Policy

**Problem**: Policy mixes ORM traversal with authorization logic.

**Location**: `application/policies/course_policy.rb` (lines 42-46):
```ruby
def self_enrolled?
  enroll = @this_course&.accounts&.any? { |account| account.id == @requestor.account_id }
  enroll
end
```

**Fix**: Policy should receive enrollment status as input, not query for it:
```ruby
# Policy receives enrollment entity:
def initialize(requestor, course, enrollment)
  @enrollment = enrollment
end

def self_enrolled?
  @enrollment.present?
end
```

---

### 7. Course/Owner Auto-Creation Rule

**Problem**: The business rule "when creating a course, auto-assign owner role to creator" lives in ORM.

**Location**: `infrastructure/database/orm/course.rb` (lines 50-61):
```ruby
def self.create_course(account_id, course_data)
  course = Course.create(course_data)
  owner_role = Role.first(name: 'owner')
  account = Account.first(id: account_id)

  if course && owner_role
    account_course = AccountCourse.create(role: owner_role, account: account, course: course)
  else
    raise Sequel::Rollback, "Course or owner role not found"
  end
  course
end
```

**Fix**: Move to `CreateCourse` service - the service should explicitly create the owner enrollment after creating the course entity.

---

### 8. Account Auto-Creation with 'member' Role

**Problem**: The business rule "new accounts get member role" is hidden in an ORM method.

**Location**: `infrastructure/database/orm/course.rb` (lines 143-151):
```ruby
def add_or_find_account(email)
  account = Account.first(email: email)
  unless account
    account = Account.create(email: email)
    role = Role.first(name: 'member')  # Domain rule hidden in ORM
    account.add_role(role)
  end
  account
end
```

**Fix**:
- Extract to `CreateAccount` service or domain factory
- Make the business rule explicit in application layer

---

## Medium Severity Leaks

### 9. Role String Parsing in ORM

**Problem**: Parsing comma-separated role strings is application-layer concern.

**Location**: `infrastructure/database/orm/course.rb` (line 154):
```ruby
def update_course_account_roles(account, roles_string)
  role_names = roles_string.split(',')  # Input transformation in ORM
  # ...
end
```

**Fix**: Service should parse input and pass structured data to repository:
```ruby
# Service:
role_names = roles_string.split(',').map(&:strip)
@enrollments_repo.update_roles(account_id:, course_id:, roles: role_names)
```

---

## Recommended Fix Order

1. **Create enrollment lookup in repository** - Foundation for other fixes
2. **Refactor policies to use Enrollment entity** - Eliminates role checking duplication
3. **Extract enrollment management from ORM** - Largest leak, enables clean services
4. **Use domain types for validation** - Coordinate validation consolidation
5. **Add time predicates to domain** - Express business concepts in domain layer

---

## Notes

- These leaks accumulated during initial development before DDD structure was established
- Some leaks exist because policies predate the `Enrollment` entity
- ORM methods like `create_course` are still used by some services - need migration path
- Consider creating a `CourseEnrollmentService` to encapsulate enrollment management
