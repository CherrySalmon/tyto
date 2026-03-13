# Application Policies — Conventions

## What policies do

Application policies answer: "Can this actor perform this action in this context?" They combine the actor (requestor), their enrollment in a course, and optionally a target resource to produce a boolean decision. They live in the application layer because they depend on actor identity and context — contrast with domain policies (`domain/*/policies/`) which encode actor-agnostic business rules.

## Structure

Every policy follows the same shape:

```ruby
module Policy
  class SomePolicy
    def initialize(requestor, ...)
      @requestor = requestor
      # remaining args provide context (e.g., enrollment, course)
    end

    def can_do_thing?
      # compose private predicates
    end

    def summary
      { can_do_thing: can_do_thing? }
    end
  end
end
```

- **Constructor**: `requestor` (AuthCapability — global roles) is always the first parameter. Additional parameters provide context needed for authorization decisions (e.g., an enrollment, a course with enrollments loaded). Enrollment may be nil (not enrolled).
- **Public `can_*?` methods**: One per action. Return boolean. Named from the actor's perspective ("can I do X?").
- **`summary` method**: Returns a hash of all permissions. Used by services to send policy decisions to the frontend as JSON.
- **Private predicates**: Compose enrollment role checks and global role checks. Always guard against nil enrollment with `&.` and `|| false`.

## Roles are additive — test presence, not exclusion

Users can hold multiple course roles simultaneously (e.g., both owner and instructor). The `CourseRoles` value object is a collection, not a single value.

This has a critical implication for how policies and their tests are written:

**Policy methods should check whether the required role is present**, not whether a specific other role is absent:

```ruby
# Good — checks for the roles that grant access
def can_manage_attendance?
  requestor_is_instructor? || requestor_is_staff?
end

# Bad — tries to exclude specific roles (breaks with multi-role users)
def can_manage_attendance?
  teaching_staff? && !requestor_is_owner?
end
```

**Tests should verify that having the required role grants access, and that lacking all required roles denies access** — not that specific other roles are denied:

```ruby
# Good — tests role presence/absence
it 'grants access when enrollment includes instructor role' do ...
it 'grants access when enrollment includes staff role' do ...
it 'denies access when enrollment lacks instructor and staff roles' do ...

# Bad — tests specific excluded roles (fragile with multi-role)
it 'denies access for owner' do ...
it 'denies access for student' do ...
```

The "denies access" test should use an enrollment that genuinely lacks the required roles (e.g., a student-only enrollment), not one that tests a specific excluded role.

## Role predicates available

From `Enrollment` (delegated to `CourseRoles`):

- `owner?`, `instructor?`, `staff?`, `student?` — single role checks
- `teaching?` — composite: owner OR instructor OR staff
- `active?` — has any role (enrolled)
- `has?(role)` — arbitrary role check

From `requestor` (AuthCapability — global roles):

- `admin?`, `creator?` — global platform roles

## Summary flows to the frontend

The `summary` hash is how the frontend learns what UI to show. Two patterns exist:

1. **Course-level policies**: `Policy::Course.summary` is embedded in the `CourseWithEnrollment` representer via `GetCourse` service. The frontend reads `course.policies.can_update` etc. to gate management tabs.

2. **Resource-level policies**: When a service returns a resource with its own policy decisions (e.g., `ListEventParticipants` returns participants + attendance policies), include the relevant policy summary in the service response. The representer serializes it alongside the data. This keeps policies with their owning domain — don't add attendance concerns to `Policy::Course`.

## Domain policies vs. application policies

- **Domain policies** (`domain/*/policies/`): Actor-agnostic business rules. "Attendance is valid when the student is at the right place at the right time." No mention of who is checking.
- **Application policies** (`application/policies/`): Actor-aware authorization. "Can this instructor manage attendance for this course?" Depends on who is asking and their role.

Don't mix these — a domain policy should never check enrollment roles, and an application policy should never check geo-fence distances.
