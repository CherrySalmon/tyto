# DDD Patterns Reference

> Quick reference for the conventions used across all bounded contexts. Read this before adding new contexts or modifying existing ones.

## Domain Layer (`app/domain/`)

### types.rb — Shared Constrained Types

All domain vocabulary types live in `app/domain/types.rb`:

```ruby
module Tyto
  module Types
    include Dry.Types()

    # Constrained strings — PascalCase nouns
    CourseName = Types::String.constrained(min_size: 1, max_size: 200)
    Email      = Types::String.constrained(format: /\A.+@.+\z/)

    # Enums
    CourseRole = Types::String.enum('owner', 'instructor', 'staff', 'student')
    SystemRole = Types::String.enum('admin', 'creator', 'member')
  end
end
```

Conventions:
- All constrained types and enums defined here (domain layer, not infrastructure)
- Application contracts import these types (dependency flows inward)
- Named with `PascalCase` nouns: `CourseName`, `CourseRole`
- Enums use `Types::String.enum(...)`

### Entities (Dry::Struct)

Aggregate roots and child entities use `Dry::Struct`. Namespace: `Tyto::Domain::<Context>::Entities::<Name>`.

```ruby
# Aggregate root example (Course)
class Course < Dry::Struct
  attribute :id,         Types::Integer.optional          # nil before persistence
  attribute :name,       Types::CourseName                # constrained type from types.rb
  attribute :start_at,   Types::Time.optional
  attribute :created_at, Types::Time.optional
  attribute :updated_at, Types::Time.optional

  # Child collections — nil = not loaded, collection wrapper = loaded (even if empty)
  attribute :events,      Types.Instance(Values::Events).optional.default(nil)
  attribute :enrollments, Types.Instance(Values::Enrollments).optional.default(nil)

  def events_loaded?      = !events.nil?
  def enrollments_loaded? = !enrollments.nil?

  # Delegates to value objects (no nil guards needed in callers)
  def find_event(event_id) = events.find(event_id)
  def teaching_staff       = enrollments.teaching_staff
end
```

```ruby
# Child entity example (Event)
class Event < Dry::Struct
  attribute :id,          Types::Integer.optional
  attribute :course_id,   Types::Integer           # FK — integer only, never entity reference
  attribute :location_id, Types::Integer
  attribute :name,        Types::EventName
  attribute :start_at,    Types::Time.optional
  attribute :created_at,  Types::Time.optional
  attribute :updated_at,  Types::Time.optional
end
```

Key rules:
- `id` is always `Types::Integer.optional` (nil before persistence)
- `created_at`/`updated_at` are `Types::Time.optional`
- Cross-context references are by integer ID only (never entity objects)
- Child collections use typed value object wrappers, not bare arrays
- Business behavior delegates to value objects to avoid guard clauses

### Collection Value Objects

Wrap arrays of entities. All follow an identical template:

```ruby
class Events < Dry::Struct
  attribute :events, Types::Array.of(Entities::Event)

  include Enumerable
  def each(&block) = events.each(&block)

  # Domain query methods
  def find(event_id) = events.find { |e| e.id == event_id }

  # Collection interface
  def any?    = events.any?
  def empty?  = events.empty?
  def count   = events.size
  def length  = events.length
  def size    = events.size
  def to_a    = events.dup

  # Convenience constructor (always used by repositories)
  def self.from(event_array)
    new(events: event_array || [])
  end
end
```

Invariants:
- Inherits `Dry::Struct`
- Single attribute named after the plural noun (`:events`, `:enrollments`)
- `Types::Array.of(EntityClass)` for the attribute type
- `include Enumerable` + `def each`
- Full collection interface: `any?`, `empty?`, `count`, `length`, `size`, `to_a`
- `self.from(array)` constructor — repositories always call this with `|| []` guard
- Add domain-specific finders as needed (`find_by_account`, `with_role`, etc.)

### Null Objects

Plain Ruby classes (not `Dry::Struct`) implementing the same interface as the real value object:

```ruby
# Real object
class TimeRange < Dry::Struct
  attribute :start_at, Types::Time
  attribute :end_at,   Types::Time
  def active?(**kw) = # real logic
  def null?    = false
  def present? = true
end

# Null object — same interface, safe defaults
class NullTimeRange
  def active?(**) = false
  def null?       = true
  def present?    = false
end
```

Used by entities to eliminate nil-checking:

```ruby
def time_range
  return Value::NullTimeRange.new unless start_at && end_at
  Value::TimeRange.new(start_at:, end_at:)
end
```

### Cross-Context Data Snapshots

When one context needs data from another, capture it as a value object — never import the foreign entity:

```ruby
# Participant captures account data for use in Courses context
class Participant < Dry::Struct
  attribute  :email,  Types::Email.optional
  attribute  :name,   Types::String.optional
  attribute? :avatar, Types::String.optional
  def display_name = name || email
end
```

### Domain Policies (Pure Domain — Actor-Agnostic)

Answer pure domain questions. No concept of "requestor" or authorization.

```ruby
module Tyto
  module Policy
    class AttendanceEligibility
      def self.check(attendance:, event:, location:, time: Time.now)
        return :time_window unless active_event?(event, time)
        return :proximity  unless within_range?(attendance, location)
        nil   # nil = eligible, no problem
      end
    end
  end
end
```

Conventions:
- Namespace: `Tyto::Policy::<ClassName>` under `domain/<context>/policies/`
- Pure class methods, stateless
- Return symbols for problems (`:time_window`, `:proximity`) or `nil` for "all clear"

---

## Infrastructure Layer (`app/infrastructure/`)

### ORM Models (`database/orm/`)

Thin Sequel models — associations and validations only, no business logic:

```ruby
class Course < Sequel::Model
  plugin :validation_helpers
  plugin :timestamps, update_on_create: true

  one_to_many :locations
  many_to_many :events

  def validate
    super
    validates_presence %i[name]
  end
end
```

Conventions:
- Namespace: `Tyto::<ModelName>` (flat, not nested under `Orm::`)
- `plugin :timestamps, update_on_create: true` for `created_at`/`updated_at`
- Join table models specify table name explicitly: `Sequel::Model(:account_course_roles)`
- No domain imports, no business logic

### Repositories (`database/repositories/`)

Map ORM records to domain entities. Namespace: `Tyto::Repository::<PluralName>`.

```ruby
module Tyto
  module Repository
    class Courses
      # Public interface — named by what is loaded
      def find_id(id)                  # entity only (children = nil)
      def find_with_events(id)         # entity + events collection
      def find_full(id)                # entity + all children
      def find_all                     # all entities, no children
      def create(entity)               # → persisted entity with ID
      def update(entity)               # → updated entity
      def delete(id)                   # → true/false

      private

      # All paths converge here — single rebuild with keyword flags
      def rebuild_entity(orm_record, load_events: false, load_locations: false)
        Domain::Courses::Entities::Course.new(
          id:        orm_record.id,
          name:      orm_record.name,
          # ...
          events:    load_events ? Domain::Courses::Values::Events.from(
                       rebuild_events(orm_record)
                     ) : nil,
          locations: load_locations ? Domain::Courses::Values::Locations.from(
                       rebuild_locations(orm_record)
                     ) : nil
        )
      end

      def rebuild_events(orm_course)
        Tyto::Event.where(course_id: orm_course.id).order(:start_at).all
                   .map { |e| rebuild_event(e) }
      end

      def rebuild_event(orm_record)
        Domain::Courses::Entities::Event.new(
          id: orm_record.id, course_id: orm_record.course_id, # ...
        )
      end
    end
  end
end
```

Key patterns:
- One `rebuild_entity` private method with keyword boolean flags for children
- All public finders call `rebuild_entity` with appropriate flags
- Collections: `Values::Events.from(rebuild_events(orm))` — always `.from()`, never `new(collection: [...])`
- `nil` passed for children when not loaded (not empty collection)
- `orm_record.refresh` called after `update` to get fresh data
- Simpler child repositories (Events, Locations) skip the keyword flags — just `rebuild_entity` with no options

### Gateway/Mapper Pattern (`auth/`, `file_storage/`)

For external I/O boundaries (encryption, HTTP, S3, etc.):

```ruby
# Gateway — raw I/O only. Knows nothing about domain objects.
class Gateway
  def encrypt(payload)   # → encrypted string
  def decrypt(token)     # → decrypted string (raises EncryptionError)
end

# Mapper — translates between domain vocabulary and external system vocabulary.
class Mapper
  def initialize(gateway: Gateway.new)   # injectable for testing
  def to_token(capability)              # domain object → wire format
  def from_auth_header(auth_header)     # wire format → domain object
end
```

Conventions:
- Gateway: raw I/O, returns raw data or `Success`/`Failure`
- Mapper: uses the gateway, returns domain objects
- Both have injectable dependencies for testing
- Services inject the Mapper, never the Gateway

---

## Application Layer (`app/application/`)

### Services (`services/`)

All inherit from `ApplicationOperation < Dry::Operation`:

```ruby
class CreateCourse < ApplicationOperation
  def initialize(courses_repo: Repository::Courses.new)
    @courses_repo = courses_repo
    super()
  end

  def call(requestor:, course_data:)
    step authorize(requestor)
    validated = step validate_input(course_data)
    course    = step persist_course(validated, requestor)
    created(course)   # bare helper — Dry::Operation wraps in Success automatically
  end

  private

  def authorize(requestor)
    policy = Tyto::CoursePolicy.new(requestor)
    return Failure(forbidden('Not authorized')) unless policy.can_create?
    Success(true)
  end

  def validate_input(data)
    # Returns Success(validated_hash) or Failure(bad_request(...))
  end

  def persist_course(validated, requestor)
    # Returns Success(result) or Failure(internal_error(...))
  rescue StandardError => e
    Failure(internal_error(e.message))
  end
end
```

Conventions:
- Namespace: `Tyto::Service::<Context>::<ActionName>`
- Constructor injects repositories with defaults, calls `super()` after ivars
- `call` uses `step` for each fallible step (auto short-circuits on `Failure`)
- Each private step returns `Success(value)` or `Failure(api_result)`
- Final line is a bare `ok(...)` or `created(...)` (not wrapped in `Success`)
- Response helpers: `ok`, `created`, `bad_request`, `not_found`, `forbidden`, `internal_error`

### Application Policies (`policies/`)

Authorization — actor-aware. Distinct from domain policies.

```ruby
class CoursePolicy
  def initialize(requestor, enrollment = nil)
    @requestor  = requestor     # AuthCapability
    @enrollment = enrollment    # domain entity or nil
  end

  def can_create?   = requestor_is_creator?
  def can_view?     = self_enrolled?
  def can_update?   = teaching_staff?
  def can_delete?   = requestor_is_admin? || requestor_is_owner?

  def summary = { can_view:, can_create:, can_update:, can_delete: }

  private
  def self_enrolled?      = @enrollment&.active? || false
  def teaching_staff?     = @enrollment&.teaching? || false
  def requestor_is_admin? = @requestor.admin?
end
```

Conventions:
- Namespace: `Tyto::<ContextName>Policy` (flat)
- Constructor: `(requestor, enrollment_or_context = nil)`
- All predicates return boolean (use `&.` + `|| false`)
- `summary` method returns hash of all permissions (serialized for frontend)

### Response DTOs

```ruby
# ApiResult — carries status + message through monads
ApiResult = Struct.new(:status, :message) do
  def http_status_code = HTTP_CODE[status]
  def success? = SUCCESS_STATUSES.include?(status)
end

# Enriched response DTOs when combining multiple sources
CourseDetails = Data.define(:id, :name, :enroll_identity, :policies)
```

---

## Presentation Layer (`app/presentation/`)

### Single-Entity Representers

```ruby
class Course < Roar::Decorator
  include Roar::JSON

  property :id
  property :name
  property :start_at, exec_context: :decorator

  def start_at = represented.start_at&.utc&.iso8601
end
```

Conventions:
- Inherits `Roar::Decorator`, includes `Roar::JSON`
- Namespace: `Tyto::Representer::<Name>`
- Time attributes: `exec_context: :decorator` + `&.utc&.iso8601`
- `represented` = the domain entity/DTO passed to the decorator

### Collection Representers

Plain Ruby class (most common pattern):

```ruby
class CoursesList
  def self.from_entities(entities) = new(entities)

  def initialize(entities)
    @entities = entities
  end

  def to_array
    @entities.map { |entity| Course.new(entity).to_hash }
  end
end
```

Public API: `self.from_entities(array)` → `to_array` returning array of hashes.

Nested collections (e.g., requirements within an assignment) are rendered by hand in `exec_context: :decorator` methods returning arrays of plain hashes.

---

## Routes (`app/application/controllers/routes/`)

### Route Class Structure

```ruby
class Courses < Roda
  include Dry::Monads[:result]
  plugin :all_verbs
  plugin :request_headers

  route do |r|
    r.on do
      auth_header = r.headers['Authorization']
      requestor   = AuthToken::Mapper.new.from_auth_header(auth_header)

      r.on String do |course_id|
        r.get do
          case Service::Courses::GetCourse.new.call(requestor:, course_id:)
          in Success(api_result)
            response.status = api_result.http_status_code
            { success: true, data: Representer::Course.new(api_result.message).to_hash }.to_json
          in Failure(api_result)
            response.status = api_result.http_status_code
            api_result.to_json
          end
        end
      end

    rescue AuthToken::Mapper::MappingError => e
      response.status = 400
      response.write({ error: 'Token error', details: e.message }.to_json)
      r.halt
    rescue StandardError => e
      response.status = 500
      response.write({ error: 'Internal server error', details: e.message }.to_json)
      r.halt
    end
  end
end
```

Conventions:
- Each resource: own `Routes::<Name> < Roda` class, registered via `r.run` in `app.rb`
- Auth extracted at top of outer `r.on` block
- Service calls: `case ... in Success(api_result) / in Failure(api_result)`
- Success: `{ success: true, data: ... }.to_json`
- Error: `api_result.to_json` → `{ error:, details: }`
- `response.status = api_result.http_status_code` always set
- Outer rescue for `MappingError` (400) and `StandardError` (500)
- JSON body parsed inline: `JSON.parse(r.body.read)`

### Registration in app.rb

```ruby
route do |r|
  r.on 'api' do
    r.on 'course' do r.run Routes::Courses end
    # new routes use plural: r.on 'courses' do ... end
  end
end
```

---

## Database Migrations (`db/migrations/`)

```ruby
Sequel.migration do
  change do
    create_table(:events) do
      primary_key :id
      foreign_key :course_id,  :courses,   on_delete: :cascade
      foreign_key :location_id, :locations, on_delete: :cascade

      String   :name, null: false
      DateTime :start_at
      DateTime :end_at
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
```

Conventions:
- `Sequel.migration do / change do` (not `up`/`down`)
- `primary_key :id` (auto-increment)
- `foreign_key :col, :table, on_delete: :cascade`
- Timestamps: `DateTime :created_at` / `DateTime :updated_at` (nullable — set by plugin)
- `null: false` on required columns
- `unique %i[col1 col2]` for composite uniqueness
