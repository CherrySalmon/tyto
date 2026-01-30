# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: Add or update multiple enrollments for a course
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class UpdateEnrollments < ApplicationOperation
        def initialize(courses_repo: Repository::Courses.new, accounts_repo: Repository::Accounts.new)
          @courses_repo = courses_repo
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:, course_id:, enrolled_data:)
          course_id = step validate_course_id(course_id)
          step verify_course_exists(course_id)
          step authorize(requestor, course_id)
          step validate_enrolled_data(enrolled_data)
          step process_enrollments(course_id, enrolled_data)

          ok('Enrollments updated')
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def verify_course_exists(course_id)
          course = @courses_repo.find_id(course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course_id)
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = Tyto::CoursePolicy.new(requestor, enrollment)

          return Failure(forbidden('You have no access to update enrollments')) unless policy.can_update?

          Success(true)
        end

        def validate_enrolled_data(enrolled_data)
          return Failure(bad_request('Enrollment data is required')) if enrolled_data.nil? || enrolled_data.empty?

          Success(enrolled_data)
        end

        def process_enrollments(course_id, enrolled_data)
          enrolled_data.each do |enrollment|
            # Find or create account by email (domain rule: new accounts get 'member' role)
            account = @accounts_repo.find_or_create_by_email(enrollment['email'])

            # Parse and set roles for this enrollment
            role_names = enrollment['roles'].split(',').map(&:strip)
            @courses_repo.set_enrollment_roles(course_id:, account_id: account.id, roles: role_names)
          end

          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
