# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'
require_relative '../../courses/values/course_roles'

module Tyto
  module Domain
    module Accounts
      module Values
        # Read-side value: one course an account is enrolled in, with the
        # course roles it holds there. Built for the admin account detail;
        # editing enrollments stays in the Courses context.
        class CourseMembership < Dry::Struct
          attribute :course_id, Types::Integer
          attribute :course_name, Types::String
          attribute :roles, Types.Instance(Courses::Values::CourseRoles)
        end
      end
    end
  end
end
