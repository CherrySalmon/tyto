# DDD Refactoring Skill

Guidelines for refactoring code into Domain-Driven Design architecture in this Ruby codebase.

## Migration Strategy: Vertical Slices

**Implement each use case as a complete vertical slice**, not layer-by-layer.

```text
❌ Horizontal (avoid):          ✅ Vertical (preferred):
   All services first             ListEvents (complete)
   Then all representers          CreateEvent (complete)
   Then all contracts             UpdateEvent (complete)
   Then wire controllers          ...
```

**Each vertical slice includes:**

1. Service class inheriting from `Service::ApplicationOperation`
2. Representer for JSON output (create if new entity type)
3. Controller updated with pattern matching on result
4. Unit tests for service
5. Integration tests pass

**Workflow:**

1. Pick next use case from legacy God object service
2. Create focused service class inheriting from `ApplicationOperation`
3. Create/update representer if needed
4. Update controller route with pattern matching
5. Write/update tests
6. Verify all tests pass
7. Repeat until legacy service is empty, then delete it

## Architecture Layers

```text
domain/                     # Pure domain (no framework dependencies)
├── types.rb               # Shared constrained types
├── <context>/
│   ├── entities/          # Aggregate roots and entities (dry-struct)
│   └── values/            # Value objects

infrastructure/
├── database/
│   ├── orm/               # Sequel models (thin, no business logic)
│   └── repositories/      # Maps ORM ↔ domain entities

application/
├── services/              # Use cases (dry-operation)
│   └── application_operation.rb  # Base class with response helpers
├── responses/             # Response DTOs (ApiResult)
└── policies/              # Authorization rules

presentation/
└── representers/          # JSON serialization (roar)
```

## Input Handling Philosophy

**Keep validation in services. Avoid premature abstraction.**

We deliberately avoid:
- **dry-validation contracts** - Add indirection without clear benefit for simple inputs
- **Request objects** - Solve a problem we don't have (computed derived values)

**Why validation belongs in services:**

1. **Cohesion** - Service IS the use case. Validation is part of that use case. One file to understand complete flow.
2. **YAGNI** - No proven need for reusable validation. CreateEvent and UpdateEvent validation will differ.
3. **Visibility** - Validation steps are explicit in the railway flow, not hidden in separate classes.

**Controller responsibility is minimal:**
- Parse JSON (or return 400 on parse error)
- Call service with parsed data
- Pattern match on result

```ruby
r.post do
  request_body = JSON.parse(r.body.read)

  case Service::Events::CreateEvent.new.call(requestor:, course_id:, event_data: request_body)
  in Success(api_result) then ...
  in Failure(api_result) then ...
  end
rescue JSON::ParserError => e
  response.status = 400
  { error: 'Invalid JSON', details: e.message }.to_json
end
```

**When to revisit this decision:**
- Multiple services share complex validation logic
- You need computed derived values (cache keys, slugs)
- Validation rules become genuinely complex (nested objects, conditional fields)

## Dependency Rules

**Dependencies flow inward only.** Domain is at center, knows nothing about outer layers.

**Allowed:**
- `repositories/` → imports `domain/entities/`
- `services/` → imports `domain/`, `repositories/`, `policies/`
- `controllers/` → imports `services/`

**Forbidden:**
- `domain/` → NEVER imports from infrastructure, application, or controllers

## ApplicationOperation Base Class

All services inherit from `Service::ApplicationOperation` which provides response helpers:

```ruby
# application/services/application_operation.rb
module Tyto
  module Service
    class ApplicationOperation < Dry::Operation
      private

      def ok(message) = Response::ApiResult.new(status: :ok, message:)
      def created(message) = Response::ApiResult.new(status: :created, message:)
      def bad_request(message) = Response::ApiResult.new(status: :bad_request, message:)
      def not_found(message) = Response::ApiResult.new(status: :not_found, message:)
      def forbidden(message) = Response::ApiResult.new(status: :forbidden, message:)
      def internal_error(message) = Response::ApiResult.new(status: :internal_error, message:)
    end
  end
end
```

## Service Pattern

Services inherit from `ApplicationOperation` and use `step` for railway-oriented flow:

```ruby
module Tyto
  module Service
    module Events
      class CreateEvent < ApplicationOperation
        def initialize(events_repo: Repository::Events.new)
          @events_repo = events_repo
          super()  # Required after setting instance variables
        end

        def call(requestor:, course_id:, event_data:)
          course_id = step validate_course_id(course_id)
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          validated = step validate_input(event_data, course_id)
          event = step persist_event(validated)

          created(event)  # Uses helper from base class
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?
          Success(id)
        end

        def validate_input(event_data, course_id)
          # Validation lives HERE in the service, not in separate contracts
          name = event_data['name']
          return Failure(bad_request('Name is required')) if name.nil? || name.strip.empty?

          location_id = event_data['location_id']
          return Failure(bad_request('Location ID is required')) if location_id.nil?

          Success(name: name.strip, location_id: location_id.to_i, course_id:)
        end

        def authorize(requestor, course_id)
          # ... policy check ...
          policy.can_create? ? Success(true) : Failure(forbidden('Access denied'))
        end
      end
    end
  end
end
```

**Key patterns:**

- Inherit from `ApplicationOperation` (not directly from `Dry::Operation`)
- Call `super()` in initialize after setting instance variables
- Use `step` to chain operations (auto short-circuits on Failure)
- Each step returns `Success(value)` or `Failure(ApiResult)`
- Use response helpers: `ok()`, `created()`, `bad_request()`, `not_found()`, `forbidden()`, `internal_error()`
- Validation is inline in service steps, not in separate contract classes

## Controller Pattern Matching

Controllers use Ruby pattern matching on service results:

```ruby
require 'dry/monads'

class Courses < Roda
  include Dry::Monads[:result]  # Required for Success/Failure constants

  route do |r|
    r.on 'event' do
      # GET api/course/:course_id/event
      r.get do
        case Service::Events::ListEvents.new.call(requestor:, course_id:)
        in Success(api_result)
          response.status = api_result.http_status_code
          { success: true, data: Representer::EventsList.from_entities(api_result.message).to_array }.to_json
        in Failure(api_result)
          response.status = api_result.http_status_code
          api_result.to_json
        end
      end

      # POST api/course/:course_id/event
      r.post do
        request_body = JSON.parse(r.body.read)

        case Service::Events::CreateEvent.new.call(requestor:, course_id:, event_data: request_body)
        in Success(api_result)
          response.status = api_result.http_status_code
          { success: true, message: 'Event created', event_info: Representer::Event.new(api_result.message).to_hash }.to_json
        in Failure(api_result)
          response.status = api_result.http_status_code
          api_result.to_json
        end
      rescue JSON::ParserError => e
        response.status = 400
        { error: 'Invalid JSON', details: e.message }.to_json
      end
    end
  end
end
```

**Key points:**

- Include `Dry::Monads[:result]` in controller class for `Success`/`Failure` constants
- Use `case/in` pattern matching (Ruby 3.0+)
- `in Success(api_result)` destructures the wrapped value
- HTTP status flows from `ApiResult`
- JSON parsing errors handled with rescue, not in service

## Representers (Presentation Layer)

Use Roar decorators for JSON serialization:

```ruby
module Tyto
  module Representer
    class Event < Roar::Decorator
      include Roar::JSON

      property :id
      property :name
      property :start_at, exec_context: :decorator
      property :longitude
      property :latitude

      def start_at
        represented.start_at&.utc&.iso8601
      end
    end
  end
end
```

## Data Enrichment Pattern

When combining data from multiple sources, use OpenStruct:

```ruby
def enrich_with_location(event)
  location = @locations_repo.find_id(event.location_id)
  OpenStruct.new(
    id: event.id,
    name: event.name,
    start_at: event.start_at,
    longitude: location&.longitude,
    latitude: location&.latitude
  )
end
```

## Complete Flow

```text
Request → Controller parses JSON
              ↓
          Service.call()
              ↓
          step validate_input (validation HERE, not in contracts)
              ↓
          step authorize
              ↓
          step persist/fetch
              ↓
          ok(data) or created(data)
              ↓
          Success(ApiResult) or Failure(ApiResult)
              ↓
          Controller pattern matches: case/in
              ↓
          Representer.to_json for success data
              ↓
Response ← JSON with HTTP status from ApiResult
```

## Gems Required

```ruby
gem 'dry-monads', '~>1.6'
gem 'dry-operation', '~>1.0'
gem 'dry-struct', '~>1.6'
gem 'roar', '~>1.2'
gem 'multi_json'
```

## Checklist for New Vertical Slices

- [ ] Create service in `application/services/<context>/<use_case>.rb`
- [ ] Inherit from `Service::ApplicationOperation`
- [ ] Call `super()` in initialize after setting instance variables
- [ ] Inject repository dependencies via constructor
- [ ] Validation in service steps (NOT in separate contracts)
- [ ] Each step returns `Success(value)` or `Failure(response_helper(msg))`
- [ ] Use response helpers: `ok`, `created`, `bad_request`, `not_found`, `forbidden`
- [ ] Create/update representer for entity serialization
- [ ] Controller includes `Dry::Monads[:result]`
- [ ] Controller uses `case/in` pattern matching
- [ ] Write unit tests for service (success and failure paths)
- [ ] Run integration tests to verify controller behavior
