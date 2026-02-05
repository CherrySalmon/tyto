# frozen_string_literal: true

require_relative '../../types'
require_relative '../values/course_roles'

module Tyto
  module Entity
    # Enrollment entity - represents an account's participation in a course.
    # A child entity of the Course aggregate.
    # One account can have multiple roles in a course (e.g., instructor + student).
    class Enrollment < Dry::Struct
      # Accepts CourseRoles only - no array coercion
      # Use CourseRoles.from(array) explicitly
      RolesType = Types.Instance(Domain::Courses::Values::CourseRoles)

      attribute :id, Types::Integer.optional
      attribute :account_id, Types::Integer
      attribute :course_id, Types::Integer
      attribute :account_email, Types::Email.optional
      attribute :account_name, Types::String.optional
      attribute :roles, RolesType
      attribute :created_at, Types::Time.optional
      attribute :updated_at, Types::Time.optional

      # Delegate role checking to the CourseRoles value object
      def has_role?(role_name) = roles.has?(role_name)

      # Role predicate methods - delegate to value object
      def owner? = roles.owner?
      def instructor? = roles.instructor?
      def staff? = roles.staff?
      def student? = roles.student?

      # Check if this enrollment includes any teaching role
      def teaching? = roles.teaching?

      # Check if account has any roles
      def active? = roles.any?
    end
  end
end
