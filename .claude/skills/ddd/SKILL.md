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
