# frozen_string_literal: true

require_relative '../../types'

module Todo
  module Entity
    # Enrollment entity - represents an account's participation in a course.
    # A child entity of the Course aggregate.
    # One account can have multiple roles in a course (e.g., instructor + student).
    class Enrollment < Dry::Struct
      attribute :id, Types::Integer.optional
      attribute :account_id, Types::Integer
      attribute :course_id, Types::Integer
      attribute :account_email, Types::Email.optional
      attribute :account_name, Types::String.optional
      attribute :roles, Types::Array.of(Types::CourseRole)
      attribute :created_at, Types::Time.optional
      attribute :updated_at, Types::Time.optional

      # Check if this enrollment has a specific role
      # @param role_name [String] the role to check ('owner', 'instructor', 'staff', 'student')
      # @return [Boolean]
      def has_role?(role_name)
        roles.include?(role_name)
      end

      # Role predicate methods
      def owner? = has_role?('owner')
      def instructor? = has_role?('instructor')
      def staff? = has_role?('staff')
      def student? = has_role?('student')

      # Check if this enrollment includes any teaching role
      def teaching? = owner? || instructor? || staff?

      # Check if account has any roles
      def active? = roles.any?
    end
  end
end
