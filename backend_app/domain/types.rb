# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'

module Todo
  # Shared constrained types for domain entities and application contracts.
  # Types live in the domain layer because they express domain vocabulary.
  # Application contracts import these types (dependency flows inward).
  module Types
    include Dry.Types()

    # Basic types with constraints
    NonEmptyString = Types::String.constrained(min_size: 1)

    # Course types
    CourseName = Types::String.constrained(min_size: 1, max_size: 200)

    # Account types
    Email = Types::String.constrained(
      format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    )

    # System roles: assigned at account level
    SystemRole = Types::String.enum('admin', 'creator', 'member')

    # Course roles: assigned per course enrollment
    CourseRole = Types::String.enum('owner', 'instructor', 'staff', 'student')

    # All roles (system + course)
    Role = Types::String.enum(
      'admin', 'creator', 'member',
      'owner', 'instructor', 'staff', 'student'
    )
  end
end
