# DDD Refactoring Skill

Guidelines for refactoring code into Domain-Driven Design architecture in this Ruby codebase.

## Architecture Layers

```text
domain/                     # Pure domain (no framework dependencies)
├── types.rb               # Shared constrained types
├── <context>/
│   ├── entities/          # Aggregate roots and entities (dry-struct)
│   └── values/            # Value objects (dry-struct or plain Ruby)

infrastructure/
├── database/
│   ├── orm/               # Sequel models (thin, no business logic)
│   └── repositories/      # Maps ORM ↔ domain entities

application/
├── services/              # Use cases, orchestration
├── contracts/             # Input validation (dry-validation)
└── policies/              # Authorization rules
```

## Dependency Rules (Critical)

**Dependencies flow inward only.** The domain layer is at the center and knows nothing about outer layers.

```text
┌─────────────────────────────────────────────┐
│  Presentation (controllers)                 │
│  ┌───────────────────────────────────────┐  │
│  │  Application (services, contracts)    │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │  Infrastructure (repositories)  │  │  │
│  │  │  ┌───────────────────────────┐  │  │  │
│  │  │  │      Domain (entities)    │  │  │  │
│  │  │  │                           │  │  │  │
│  │  │  └───────────────────────────┘  │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
         arrows point INWARD only →
```

**Allowed:**

- `infrastructure/repositories/` → imports `domain/entities/`
- `application/services/` → imports `domain/entities/`, `infrastructure/repositories/`
- `application/contracts/` → imports `domain/types.rb`
- `controllers/` → imports `application/services/`

**Forbidden:**

- `domain/` → NEVER imports from `infrastructure/`, `application/`, or `controllers/`
- Domain entities must have NO knowledge of ORM, database, or framework

**Why this matters:**

- Domain stays testable without database/framework
- Domain can be reused in different contexts
- Changes to infrastructure don't ripple into domain

## Domain Types (domain/types.rb)

Define constrained types in the **domain layer**. Application contracts import these (dependency flows inward).

```ruby
module Todo
  module Types
    include Dry.Types()

    # Constrained types - shared by entities AND contracts
    CourseName = Types::String.constrained(min_size: 1, max_size: 200)
    Email = Types::String.constrained(
      format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    )
    CourseRole = Types::String.enum('owner', 'instructor', 'staff', 'student')
  end
end
```

## Domain Entities (dry-struct)

Use `Dry::Struct` for immutable, type-safe entities:

```ruby
class Course < Dry::Struct
  attribute :id, Types::Integer.optional
  attribute :name, Types::CourseName          # Uses shared constrained type
  attribute :start_at, Types::Time.optional
  attribute :end_at, Types::Time.optional

  # Delegate to value objects
  def duration = time_range.duration
  def active?(at: Time.now) = time_range.active?(at:)
end
```

**Key behaviors:**

- Type constraints enforced on construction AND `new()` updates
- Raises `Dry::Struct::Error` on constraint violations
- Use Ruby 3.1+ hash shorthand: `{ name:, logo: }` not `{ name: name }`

**Entity purity (critical):**

Domain entities must have NO knowledge of persistence or serialization. Never add these methods to entities:

- `to_hash`, `to_h` (use representers for API output)
- `to_json`, `as_json` (use representers)
- `to_persistence_hash` (mapping logic belongs in repositories)
- `attributes` (ORM concern)

Serialization/mapping responsibilities:

| Concern | Where it belongs |
|---------|-----------------|
| ORM ↔ Entity mapping | Repository (`rebuild_entity`, inline mapping) |
| Entity → JSON for API | Representer (`presentation/representers/`) |
| Params → Entity | Contract + Service layer |

## Null Object Pattern (Avoid nil)

Never return `nil` for missing/empty states. Use Null Objects instead:

```ruby
# BAD - requires guard clauses everywhere
def time_range
  return nil unless start_at && end_at
  Value::TimeRange.new(start_at:, end_at:)
end

def active?(at: Time.now)
  return false unless time_range  # Guard needed
  time_range.active?(at:)
end

# GOOD - Null Object handles it
def time_range
  return Value::NullTimeRange.new unless start_at && end_at
  Value::TimeRange.new(start_at:, end_at:)
end

def active?(at: Time.now) = time_range.active?(at:)  # No guard needed
```

**Null Object template:**

```ruby
class NullTimeRange
  def duration = 0
  def active?(**) = false
  def upcoming?(**) = false
  def null? = true
  def present? = false
end
```

## Value Objects

Immutable objects representing domain concepts:

```ruby
class TimeRange < Dry::Struct
  attribute :start_at, Types::Time
  attribute :end_at, Types::Time

  # Invariant checked on construction only (dry-struct limitation)
  def self.new(attributes)
    if attributes[:end_at] <= attributes[:start_at]
      raise ArgumentError, 'end_at must be after start_at'
    end
    super
  end

  def duration = end_at - start_at
  def active?(at: Time.now) = at >= start_at && at <= end_at

  # Interface parity with Null Object
  def null? = false
  def present? = true
end
```

**Note:** Custom `self.new` overrides only run on initial construction, NOT on `instance.new()` updates. Cross-field validation should happen at contract level.

## Repositories

Map between ORM and domain entities. **All mapping logic lives here**, not in entities:

```ruby
class Courses
  def find_id(id)
    orm_record = Todo::Course[id]
    return nil unless orm_record
    rebuild_entity(orm_record)
  end

  def create(entity)
    # Mapping from entity → ORM happens HERE (not in entity)
    orm_record = Todo::Course.create(
      name: entity.name,
      logo: entity.logo,
      start_at: entity.start_at,
      end_at: entity.end_at
    )
    rebuild_entity(orm_record)
  end

  private

  # Mapping from ORM → entity
  def rebuild_entity(orm_record)
    Entity::Course.new(
      id: orm_record.id,
      name: orm_record.name,
      logo: orm_record.logo,
      start_at: orm_record.start_at,
      end_at: orm_record.end_at
    )
  end
end
```

## Application Contracts (dry-validation)

Import domain types for validation. Contracts handle:

- Input coercion (strings → proper types)
- Business rules (cross-field validation)
- Error messages

```ruby
class CreateCourseContract < Dry::Validation::Contract
  params do
    required(:name).filled(Todo::Types::CourseName)  # Reuse domain type
    required(:start_at).filled(:time)
    required(:end_at).filled(:time)
  end

  # Cross-field rules stay in contracts
  rule(:start_at, :end_at) do
    key(:end_at).failure('must be after start_at') if values[:end_at] <= values[:start_at]
  end
end
```

## Service Layer Pattern

Services use repositories and return domain entities:

```ruby
class CourseService
  def self.repository
    @repository ||= Repository::Courses.new
  end

  def self.list_all(requestor)
    verify_policy(requestor, :view_all)
    repository.find_all
  end

  def self.create(requestor, params)
    verify_policy(requestor, :create)

    result = CreateCourseContract.new.call(params)
    return Failure(result.errors) if result.failure?

    entity = Entity::Course.new(result.to_h.merge(id: nil))
    repository.create(entity)
  end
end
```

## Migration Strategy

1. **Move first, transform later** - Reorganize files before adding abstractions
2. **Incremental migration** - Keep ORM for complex queries during transition
3. **Test after each step** - All tests must pass before proceeding
4. **Bridge methods** - `entity_to_hash` for API compatibility during migration

## Checklist for New Entities

- [ ] Define constrained types in `domain/types.rb`
- [ ] Create entity class extending `Dry::Struct`
- [ ] Create Null Object if entity has optional associations
- [ ] Create representer in `presentation/representers/` for API output
- [ ] Create repository with `find_id`, `find_all`, `create`, `update`, `delete`
- [ ] Write unit tests for entity (including constraint enforcement on `new()`)
- [ ] Write unit tests for Null Object
- [ ] Write integration tests for repository
- [ ] Update service to use repository
- [ ] Run full test suite

**Important:** Create representers immediately when creating entities. This prevents the temptation to add `to_hash`/`to_json` methods to entities.

## Representers (Presentation Layer)

Representers handle entity → JSON serialization. Create these in `presentation/representers/` alongside entities to avoid polluting domain objects:

```ruby
# presentation/representers/course_representer.rb
require 'roar/decorator'
require 'roar/json'

module Representer
  class Course < Roar::Decorator
    include Roar::JSON

    property :id
    property :name
    property :logo
    property :start_at
    property :end_at

    # Computed properties
    property :active, exec_context: :decorator

    def active
      represented.active?
    end
  end
end
```

**Usage in controllers:**

```ruby
# Return single entity
course = CourseService.find(id)
Representer::Course.new(course).to_json

# Return collection
courses = CourseService.list_all(requestor)
courses.map { |c| Representer::Course.new(c).to_hash }
```

**Alternative:** Simple hash-based representers without Roar gem:

```ruby
module Representer
  class Course
    def initialize(entity)
      @entity = entity
    end

    def to_hash
      {
        id: @entity.id,
        name: @entity.name,
        logo: @entity.logo,
        start_at: @entity.start_at&.iso8601,
        end_at: @entity.end_at&.iso8601,
        active: @entity.active?
      }
    end

    def to_json(*) = to_hash.to_json
  end
end
```

## Common Patterns

### Predicate methods with delegation

```ruby
def active?(at: Time.now) = time_range.active?(at:)
```

### Optional attributes

```ruby
attribute :logo, Types::String.optional
```

### New record check

```ruby
def new_record? = id.nil?
```

## Future: Railway-Oriented Programming (dry-monads)

When refactoring services, consider replacing exception-based error handling with railway-oriented programming:

```ruby
# CURRENT: Exception-based (verbose rescue blocks)
class CourseService
  class ForbiddenError < StandardError; end

  def self.find(id)
    course = Course[id] || raise(NotFoundError)
    course
  end
end

# FUTURE: Railway-oriented (Success/Failure returns)
class CourseService
  include Dry::Monads::Result::Mixin

  def self.find(id)
    course = repository.find_id(id)
    return Failure(:not_found) unless course
    Success(course)
  end
end
```

**Benefits:**

- Explicit error handling as return values
- Controllers pattern-match instead of rescue blocks
- Easier to compose multi-step operations
- Type-safe error propagation

**Infrastructure layer:** Repositories and external adapters can also use monads to protect against outside errors (database failures, API timeouts, network errors). This keeps external failure handling explicit at the boundary:

```ruby
class Courses
  include Dry::Monads::Result::Mixin

  def find_id(id)
    orm_record = Todo::Course[id]
    return Failure(:not_found) unless orm_record
    Success(rebuild_entity(orm_record))
  rescue Sequel::DatabaseError => e
    Failure(:database_error, e.message)
  end
end
```

**When to adopt:** Phase 6 (Application Layer Refactoring), after domain extraction is complete.
