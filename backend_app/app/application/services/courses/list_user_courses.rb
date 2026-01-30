# frozen_string_literal: true

require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: List courses the user is enrolled in
      # Returns Success(ApiResult) with list of courses with enrollment info
      class ListUserCourses < ApplicationOperation
        def call(requestor:)
          account_id = step validate_requestor(requestor)
          courses = step fetch_user_courses(account_id)

          ok(courses)
        end

        private

        def validate_requestor(requestor)
          account_id = requestor.account_id
          return Failure(bad_request('Invalid requestor')) if account_id.nil?

          Success(account_id)
        end

        def fetch_user_courses(account_id)
          # Get all enrollments for this account
          account_courses = AccountCourse.where(account_id:).all

          # Aggregate courses with their roles
          aggregated = {}
          account_courses.each do |ac|
            course = ac.course
            role = ac.role&.name

            unless aggregated[course.id]
              aggregated[course.id] = build_course_with_enrollment(course)
            end

            aggregated[course.id].enroll_identity << role if role
          end

          # Remove duplicate roles
          aggregated.values.each { |c| c.enroll_identity.uniq! }

          Success(aggregated.values)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def build_course_with_enrollment(course)
          OpenStruct.new(
            id: course.id,
            name: course.name,
            logo: course.logo,
            start_at: course.start_at,
            end_at: course.end_at,
            created_at: course.created_at,
            updated_at: course.updated_at,
            enroll_identity: []
          )
        end
      end
    end
  end
end
