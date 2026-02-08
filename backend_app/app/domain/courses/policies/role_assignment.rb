# frozen_string_literal: true

module Tyto
  module Policy
    # Domain policy: "Which course roles can a given role assign?"
    # Actor-agnostic — a domain expert would articulate this hierarchy
    # without mentioning requestors or application context.
    class RoleAssignment
      UnknownRoleError = Class.new(StandardError)

      HIERARCHY = %w[owner instructor staff student].freeze

      ASSIGNABLE = {
        'owner' => %w[owner instructor staff student],
        'instructor' => %w[staff student],
        'staff' => %w[student],
        'student' => []
      }.freeze

      # Given a single role, return the roles it can assign.
      # @param role [String] a course role name
      # @return [Array<String>] assignable role names
      # @raise [UnknownRoleError] if role is not a valid course role
      def self.assignable_roles(role)
        ASSIGNABLE.fetch(role) { raise UnknownRoleError, "Unknown course role: '#{role}'" }
      end

      # Given a CourseRoles collection, return assignable roles
      # based on the highest role in the hierarchy.
      # @param course_roles [CourseRoles] the enrollment's roles
      # @return [Array<String>] assignable role names
      def self.for_enrollment(course_roles)
        highest = HIERARCHY.find { |role| course_roles.has?(role) }
        return [] unless highest

        assignable_roles(highest)
      end
    end
  end
end
