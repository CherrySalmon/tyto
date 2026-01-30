# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/courses'
require_relative '../application_operation'

module Tyto
  module Service
    module Courses
      # Service: Get a single course by ID
      # Returns Success(ApiResult) with course or Failure(ApiResult) with error
      class GetCourse < ApplicationOperation
        def initialize(courses_repo: Repository::Courses.new)
          @courses_repo = courses_repo
          super()
        end

        def call(requestor:, course_id:)
          course_id = step validate_course_id(course_id)
          course_orm = step find_course_orm(course_id)
          step authorize(requestor, course_orm, course_id)
          course = step build_course_response(course_orm, requestor)

          ok(course)
        end

        private

        def validate_course_id(course_id)
          id = course_id.to_i
          return Failure(bad_request('Invalid course ID')) if id.zero?

          Success(id)
        end

        def find_course_orm(course_id)
          course = Course.first(id: course_id)
          return Failure(not_found('Course not found')) unless course

          Success(course)
        end

        def authorize(requestor, course, course_id)
          course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id:).map do |ac|
            ac.role.name
          end
          policy = CoursePolicy.new(requestor, course, course_roles)

          return Failure(forbidden('You have no access to view this course')) unless policy.can_view?

          Success(course_roles)
        end

        def build_course_response(course_orm, requestor)
          enroll_identity = AccountCourse.where(
            account_id: requestor['account_id'],
            course_id: course_orm.id
          ).map { |ac| ac.role.name }

          course = OpenStruct.new(
            id: course_orm.id,
            name: course_orm.name,
            logo: course_orm.logo,
            start_at: course_orm.start_at,
            end_at: course_orm.end_at,
            created_at: course_orm.created_at,
            updated_at: course_orm.updated_at,
            enroll_identity:
          )

          Success(course)
        end
      end
    end
  end
end
