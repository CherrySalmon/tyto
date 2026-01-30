# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: Update a single enrollment for a course
      # Returns Success(ApiResult) or Failure(ApiResult) with error
      class UpdateEnrollment < ApplicationOperation
        def initialize(courses_repo: Repository::Courses.new, accounts_repo: Repository::Accounts.new)
          @courses_repo = courses_repo
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:, course_id:, account_id:, enrolled_data:)
          course_id = step validate_course_id(course_id)
          account_id = step validate_account_id(account_id)
          step verify_course_exists(course_id)
          target_enrollment = step find_target_enrollment(course_id, account_id)
          step authorize(requestor, course_id)
          step validate_enrolled_data(enrolled_data)
          step update_email_if_provided(target_enrollment, enrolled_data)
          step update_roles(course_id, account_id, enrolled_data)

          ok('Enrollment updated')
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def validate_account_id(account_id)
          id = account_id.to_i
          return Failure(bad_request('Invalid account ID')) if id.zero?

          Success(id)
        end

        def verify_course_exists(course_id)
          course = @courses_repo.find_id(course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def find_target_enrollment(course_id, account_id)
          enrollment = @courses_repo.find_enrollment(account_id:, course_id:)
          return Failure(not_found('Enrollment not found')) unless enrollment

          Success(enrollment)
        end

        def authorize(requestor, course_id)
          enrollment = @courses_repo.find_enrollment(account_id: requestor.account_id, course_id:)
          policy = Tyto::CoursePolicy.new(requestor, enrollment)

          return Failure(forbidden('You have no access to update enrollments')) unless policy.can_update?

          Success(true)
        end

        def validate_enrolled_data(enrolled_data)
          return Failure(bad_request('Enrollment data is required')) if enrolled_data.nil?

          Success(enrolled_data)
        end

        def update_email_if_provided(enrollment, enrolled_data)
          new_email = enrolled_data['email']
          return Success(true) unless new_email

          # Check if email is already taken by a different account
          existing = @accounts_repo.find_by_email(new_email)
          if existing && existing.id != enrollment.account_id
            return Failure(bad_request('Email already exists with a different account'))
          end

          # Update the account's email via ORM (accounts repo update would need full entity)
          account = Tyto::Account[enrollment.account_id]
          account.update(email: new_email)

          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def update_roles(course_id, account_id, enrolled_data)
          roles_string = enrolled_data['roles']
          return Success(true) unless roles_string

          role_names = roles_string.split(',').map(&:strip)
          @courses_repo.set_enrollment_roles(course_id:, account_id:, roles: role_names)

          Success(true)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
