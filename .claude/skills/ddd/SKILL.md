---
name: ddd
description: Domain-Driven Design architecture patterns and conventions for this project
---

# DDD Skill

Domain-Driven Design architecture patterns and conventions.

## Codebase Reference

> Look at relevant portions of the current codebase's DDD if needed, or else request a reference project if unsure the current project is a good fit.

See `CLAUDE.md` → "Architecture" for layer paths, file conventions, and key examples.

## Architecture Layers

```text
domain/                     # Pure domain (no framework dependencies)
├── types                   # Shared constrained types
├── <context>/
│   ├── entities/           # Aggregate roots and entities
│   ├── values/             # Value objects
│   └── policies/           # Domain policies (business rules, actor-agnostic)

infrastructure/
├── database/
│   ├── orm/                # ORM models (thin, no business logic)
│   └── repositories/       # Maps ORM ↔ domain entities
├── <external>/             # External API adapters (Gateway + Mapper)

application/
├── services/               # Use cases, orchestration
├── policies/               # Application policies (actor-dependent authorization)
├── responses/              # Response DTOs

presentation/
└── representers/           # Serialization for API responses
```

## Dependency Rules

Dependencies flow inward only. Domain is at the center, knows nothing about outer layers.

**Allowed:**

- `repositories/` → imports `domain/entities/`
- `services/` → imports `domain/`, `repositories/`, `policies/`
- `controllers/` → imports `services/`

**Forbidden:**

- `domain/` → NEVER imports from infrastructure, application, or presentation

## Domain Logic, Domain Policies, and Application Policies

Three distinct concepts, often conflated:

**Domain logic** = intrinsic computations, always true regardless of context. "These two points are 32km apart." Pure math — belongs in value objects and entities.

**Domain policies** = business rules a domain expert would articulate, actor-agnostic. "Attendance must be within 55m of the event location." The threshold is a business decision (not a deployment decision), but the rule itself doesn't reference who is acting. Constants for thresholds belong in the domain, not in config files or infrastructure.

**Application policies** = rules that depend on *who* is acting or application-level context. "Only teaching staff can view all attendance records." These reference roles, requestors, or use-case context.

**The key constraint:** The domain layer can't know about application concepts like "who is the requestor" or "what role do they have."

**Heuristic:** If the rule is actor-agnostic (a domain expert would state it without mentioning roles) → `domain/`. If it references roles, requestors, or use-case context → `application/policies/`.

| Concern | Layer | Why |
| ------- | ----- | --- |
| Distance calculation (Haversine) | Domain (value object) | Pure math, always true |
| "Right place, right time" | Domain (policy) | Business rule, actor-agnostic |
| "Only students must comply" | Application (service orchestration) | Depends on actor role |
| "Only staff can view all records" | Application (policy) | Depends on actor role |

Group related domain rules into a single policy when they answer the same domain question (e.g., proximity + time window = "is this attendance eligible?").

**Anti-pattern: policy decisions in services.** Services must NOT contain business rule logic — even simple conditionals like threshold comparisons. If a domain expert would articulate the rule, it belongs in a policy, not as an `if` statement in a service. Services call policies; they don't replicate them.

**Evolution:** If a threshold might vary (per course, per campus), make it a value object rather than a constant. The threshold evolves from a constant to a repository-backed lookup without architectural refactoring.

## Entities vs Value Objects

Two building blocks that are often misclassified:

**Entities** have identity — they are distinct *things* the domain recognizes, references, and acts upon. Two entities with identical attributes but different identities are different things.

**Value Objects** are attributes of entities — they describe aspects of entities with no identity of their own. Two value objects with the same attributes are interchangeable.

### The Belongingness Test

Value objects belong to entities. Every value object should have a parent entity it describes:

| Value Object | Describes Entity |
| --- | --- |
| `TimeRange` | `Course`, `Event` |
| `GeoLocation` | `Location`, `Attendance` |
| `CourseRoles` | `Enrollment` |

**If a domain concept doesn't naturally belong as an attribute of any existing entity, it is likely an entity itself.** A standalone concept that someone reads, references, or acts upon — that's an entity, not a value object.

### Standalone Computed Concepts

Reports, invoices, statements, and similar derived/computed concepts are entities when:

- They stand alone — no parent entity owns them as an attribute
- The business recognizes them as things ("the attendance report," "invoice #1234")
- Someone reads, references, shares, or acts upon them
- They have conceptual identity even if regenerating them produces identical attributes

An invoice regenerated from the same order has the same attributes, yet invoices are canonical DDD entities. The same reasoning applies to reports.

### Entities Don't Require Persistence

Identity is a domain concept, not a storage decision. A computed report that is never persisted can still be a domain entity if the domain expert treats it as a distinct thing. Persistence is an infrastructure concern.

### The Evans `Delivery` Caveat

Evans' DDD Sample models `Delivery` as a value object, but `Delivery` *belongs to* `Cargo` (its parent entity). This pattern applies when a computed concept is an attribute of an aggregate. When a computed concept has no parent entity and stands alone, the entity classification is more appropriate.

### Decision Heuristic

1. Does it describe an aspect of another entity? → **Value object** (attribute of that entity)
2. Does it stand alone as something the domain recognizes? → **Entity**
3. Is it a pure formatting/serialization concern with no domain logic? → **Presentation layer** (representer/formatter, not domain at all)

## Entity & Value Object Implementation

Entities and value objects take their collaborators in the constructor and compute derived data on demand via memoized methods. Plain Ruby classes, not `Dry::Struct`.

**Principle:** Objects own their computation. The constructor receives domain objects; derived values are exposed as methods. No procedural factory that pre-computes everything and stuffs it into a passive struct.

**Entity example** — takes dependencies, computes on demand:

```ruby
class AttendanceReport
  ReportEvent = Data.define(:id, :name)  # simple immutable data: use Data.define

  attr_reader :course_name, :generated_at

  def initialize(course:, attendances:)
    @course_name = course.name
    @generated_at = Time.now
    @course = course
    @attendances = attendances
  end

  def events
    @events ||= raw_events.map { |e| ReportEvent.new(id: e.id, name: e.name) }
  end

  def student_records
    @student_records ||= students.map do |enrollment|
      StudentAttendanceRecord.new(enrollment:, events: raw_events, lookup: index)
    end
  end

  private

  def raw_events  = @course.events_loaded? ? @course.events : []
  def students    = @course.enrollments_loaded? ? @course.students : []
  def register    = @register ||= AttendanceRegister.new(attendances: @attendances)
end
```

**Value object example** — computes from collaborators, provides value equality:

```ruby
class StudentAttendanceRecord
  attr_reader :email

  def initialize(enrollment:, events:, lookup:)
    @email = enrollment.account_email
    @account_id = enrollment.account_id
    @events = events
    @lookup = lookup
  end

  def event_attendance
    @event_attendance ||= @events.each_with_object({}) do |event, hash|
      hash[event.id] = @lookup.attended?(@account_id, event.id) ? 1 : 0
    end
  end

  def attend_sum     = @attend_sum     ||= event_attendance.values.sum
  def attend_percent = @attend_percent ||= # ...compute from attend_sum and events

  def ==(other)
    other.is_a?(self.class) && email == other.email && event_attendance == other.event_attendance
  end
  alias eql? ==
  def hash = [email, event_attendance].hash
end
```

**When to use what:**

| Need | Use |
| --- | --- |
| Object with behavior / computed methods | Plain Ruby class |
| Simple immutable data holder (2–3 fields, no logic) | `Data.define` |
| Value equality | Implement `==`, `eql?`, `hash` |

**Anti-pattern:** `Dry::Struct` + `.build` factory that procedurally computes values and stores them as inert attributes. This separates computation from the object that should own it, producing a "dumb struct" filled by an external procedure.

## Service Pattern

Services are use cases. Each service is a single operation with railway-oriented flow (each step succeeds or short-circuits on failure).

**Key principles:**

- One service per use case (not a God object with many methods)
- Inject repository and mapper dependencies via constructor
- Each step returns Success or Failure
- Validation is inline in service steps, not in separate contract classes (unless multiple services share complex validation)
- Response helpers (`ok`, `created`, `bad_request`, `forbidden`, etc.) wrap results with HTTP-friendly status

**Typical step flow:**

1. Validate input
2. Authorize (application policy)
3. Check domain rules (domain policy)
4. Persist / fetch
5. Return response DTO

## Input Handling

Keep validation in services. Avoid premature abstraction.

**Why validation belongs in services:**

1. **Cohesion** — The service IS the use case. Validation is part of it. One file to understand the complete flow.
2. **YAGNI** — No proven need for reusable validation. Create and Update validation will differ.
3. **Visibility** — Validation steps are explicit in the railway flow, not hidden in separate classes.

**Controller responsibility is minimal:** parse input, call service, pattern match on result.

**When to extract validation:**

- Multiple services share complex validation logic
- You need computed derived values (cache keys, slugs)
- Validation rules become genuinely complex (nested objects, conditional fields)

## Response DTOs

Services often compose data from multiple repositories — an event with its location coordinates and course name, or a course with enrollment roles. These composites aren't domain entities (nobody says "enriched event"). They're application-layer concerns: the shape of what the use case returns.

Response DTOs live in `application/responses/` and use `Data.define`.

**Implementation:**

```ruby
# app/application/responses/event_details.rb
module Tyto
  module Response
    EventDetails = Data.define(
      :id, :course_id, :location_id, :name, :start_at, :end_at,
      :longitude, :latitude, :course_name, :location_name
    )
  end
end
```

The service builds the DTO from its repository results:

```ruby
def enrich(event, location, course)
  Response::EventDetails.new(
    id: event.id, course_id: event.course_id, location_id: event.location_id,
    name: event.name, start_at: event.start_at, end_at: event.end_at,
    longitude: location&.longitude, latitude: location&.latitude,
    course_name: course.name, location_name: location&.name
  )
end
```

The representer serializes it — with a guaranteed shape, no `respond_to?` guards needed.

**When to use response DTOs vs. passing entities directly:**

| Situation | Use |
| --- | --- |
| Response matches a single entity's shape | Pass the entity directly to the representer |
| Response combines data from multiple entities | Response DTO (`Data.define`) |
| Response adds computed/derived fields not on the entity | Response DTO |

**Anti-pattern:** `OpenStruct` for composing multi-entity responses. OpenStruct has no guaranteed shape — the representer must use `respond_to?` guards, and typos in field names silently produce `nil` instead of raising errors.

**Variant DTOs for different endpoints:** When two endpoints return nearly the same shape but one has extra fields (e.g., `user_attendance_status` on a requestor-aware endpoint), use separate DTOs rather than one DTO with nil fields. This makes each endpoint's contract explicit and avoids conditional serialization logic.

## Gateway/Mapper Pattern

External API integrations use Gateway + Mapper:

- **Gateway**: Handles raw I/O (HTTP, encryption). Returns Success/Failure with raw data.
- **Mapper**: Transforms external data to domain vocabulary. Isolates external field names.

Services inject the Mapper, not the Gateway. This means:

- External API field changes are isolated to the Mapper
- Services use domain vocabulary throughout
- Gateway is testable with HTTP stubs, Mapper with a mock Gateway

## Complete Flow

```text
Request → Controller parses input
              ↓
          Service.call()
              ↓
          step validate_input
              ↓
          step authorize (application policy)
              ↓
          step check_domain_rules (domain policy)
              ↓
          step persist/fetch
              ↓
          Success(response) or Failure(response)
              ↓
          Controller pattern matches result
              ↓
          Representer serializes success data
              ↓
Response ← JSON/etc. with status from response DTO
```

## References

Seminal DDD resources for deeper exploration.

### Books

- **Eric Evans** — *Domain-Driven Design: Tackling Complexity in the Heart of Software* (2003). The foundational text. Chapter 5 covers entities, value objects, and services. Chapter 6 covers aggregate design.
- **Vaughn Vernon** — *Implementing Domain-Driven Design* (2013). Practical application of Evans' patterns with concrete examples. Strong coverage of aggregate boundaries, repositories, and domain events.
- **Eric Evans** — *DDD Reference* (free PDF). Condensed definitions of all DDD patterns: [domainlanguage.com/ddd/reference](https://www.domainlanguage.com/ddd/reference/)

### Online Resources

- **Martin Fowler** — [EvansClassification](https://martinfowler.com/bliki/EvansClassification.html) — concise summary of entity, value object, and service distinctions.
- **Martin Fowler** — [ValueObject](https://martinfowler.com/bliki/ValueObject.html) — definitive writeup on value object semantics and identity.
- **Vladimir Khorikov** — [Entity vs Value Object: The Ultimate List of Differences](https://enterprisecraftsmanship.com/posts/entity-vs-value-object-the-ultimate-list-of-differences/) — comprehensive decision criteria with examples.
- **Vladimir Khorikov** — [Value Objects Explained](https://enterprisecraftsmanship.com/posts/value-objects-explained/) — deep dive into when and how to use value objects.

### Reference Implementations

- **DDD Sample Application** (Citerus / Evans collaborators) — canonical reference implementation. The `Cargo` aggregate with `Delivery` value object and `Itinerary` demonstrates computed domain concepts: [dddsample-core](https://github.com/citerus/dddsample-core) — [characterization](https://dddsample.sourceforge.net/characterization.html)
