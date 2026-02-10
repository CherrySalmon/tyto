# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'

module Tyto
  # Shared constrained types for domain entities and application contracts.
  # Types live in the domain layer because they express domain vocabulary.
  # Application contracts import these types (dependency flows inward).
  module Types
    include Dry.Types()

    # Basic types with constraints
    NonEmptyString = Types::String.constrained(min_size: 1)

    # Course types
    CourseName = Types::String.constrained(min_size: 1, max_size: 200)

    # Event types
    EventName = Types::String.constrained(min_size: 1, max_size: 200)

    # Location types
    LocationName = Types::String.constrained(min_size: 1, max_size: 200)
    Longitude = Types::Float.constrained(gteq: -180.0, lteq: 180.0).optional
    Latitude = Types::Float.constrained(gteq: -90.0, lteq: 90.0).optional

    # Account types
    Email = Types::String.constrained(format: /\A.+@.+\z/)

    # System roles: assigned at account level
    SystemRole = Types::String.enum('admin', 'creator', 'member')

    # Course roles: assigned per course enrollment
    CourseRole = Types::String.enum('owner', 'instructor', 'staff', 'student')

    # All roles (system + course)
    Role = Types::String.enum(*SystemRole.values, *CourseRole.values)
  end
end
