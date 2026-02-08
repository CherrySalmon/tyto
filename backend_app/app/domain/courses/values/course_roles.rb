# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'

module Tyto
  module Domain
    module Courses
      module Values
        # Value object representing a specific person's collection of course-level roles.
        # Answers "what roles does this person have?" — not about roles in general.
        # For role hierarchy rules (e.g., which roles can assign which), see Policy::RoleAssignment.
        class CourseRoles < Dry::Struct
          attribute :roles, Types::Array.of(Types::CourseRole)

          # Check if collection contains a specific role
          # @param role [String, Symbol] the role to check
          # @return [Boolean]
          def has?(role)
            roles.include?(role.to_s)
          end

          # Alias for backward compatibility with tests
          alias include? has?

          # Role predicates
          def owner? = has?('owner')
          def instructor? = has?('instructor')
          def staff? = has?('staff')
          def student? = has?('student')

          # Composite predicates
          def teaching? = owner? || instructor? || staff?

          # Collection queries
          def any? = roles.any?
          def empty? = roles.empty?
          def count = roles.size
          def to_a = roles.dup

          # Convenience constructor from array
          def self.from(role_array)
            new(roles: role_array || [])
          end
        end
      end
    end
  end
end
