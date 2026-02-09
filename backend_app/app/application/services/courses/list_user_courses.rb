# frozen_string_literal: true

require_relative '../application_operation'
require_relative '../../responses/course_details'

module Tyto
  module Service
    module Courses
      # Service: List courses the user is enrolled in
      # Returns Success(ApiResult) with list of courses with enrollment info
      class ListUserCourses < ApplicationOperation
        def call(requestor:)
          requestor = step validate_requestor(requestor)
          courses = step fetch_user_courses(requestor)

          ok(courses)
        end

        private

        def validate_requestor(requestor)
          return Failure(bad_request('Invalid requestor')) if requestor.account_id.nil?

          Success(requestor)
        end

        def fetch_user_courses(requestor)
          account_courses = AccountCourse.where(account_id: requestor.account_id).all

          # Aggregate courses with their roles
          aggregated = {}
          account_courses.each do |ac|
            course = ac.course
            role = ac.role&.name

            unless aggregated[course.id]
              aggregated[course.id] = { course:, roles: [] }
            end

            aggregated[course.id][:roles] << role if role
          end

          courses = aggregated.values.map do |entry|
            roles = entry[:roles].uniq
            build_course_with_enrollment(entry[:course], roles, requestor)
          end

          Success(courses)
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def build_course_with_enrollment(course, roles, requestor)
          course_roles = Domain::Courses::Values::CourseRoles.from(roles)
          enrollment = Entity::Enrollment.new(
            id: nil, account_id: requestor.account_id, course_id: course.id,
            account_email: nil, account_name: nil,
            roles: course_roles, created_at: nil, updated_at: nil
          )
          policy = CoursePolicy.new(requestor, enrollment)

          Response::CourseDetails.new(
            id: course.id,
            name: course.name,
            logo: course.logo,
            start_at: course.start_at,
            end_at: course.end_at,
            created_at: course.created_at,
            updated_at: course.updated_at,
            enroll_identity: roles,
            policies: policy.summary
          )
        end
      end
    end
  end
end
