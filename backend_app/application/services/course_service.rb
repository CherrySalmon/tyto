# frozen_string_literal: true

require_relative '../policies/course_policy'

module Todo
  # Manages course requests
  class CourseService
    # Custom error classes
    class ForbiddenError < StandardError; end
    class CourseNotFoundError < StandardError; end

    # Lists all courses, if authorized
    def self.list_all(requestor)
      verify_policy(requestor, :view_all)
      courses = Course.all.map(&:attributes)
      courses || raise(ForbiddenError, 'You have no access to list courses.')
    end

    # Lists all joined courses, if authorized
    def self.list(requestor)
      Course.listByAccountID(requestor['account_id'])
    end
    # Creates a new course, if authorized
    def self.create(requestor, course_data)
      verify_policy(requestor, :create)
      course = Course.create_course(requestor['account_id'], course_data) || raise("Failed to create course.")
      course.attributes(requestor['account_id'])
    end

    def self.get(requestor, course_id)
      course = Course.first(id: course_id)
      verify_policy(requestor, :view, course, course_id)
      course.attributes(requestor['account_id'])
    end

    # Updates an existing course, if authorized
    def self.update(requestor, course_id, course_data)
      course = find_course(course_id)
      verify_policy(requestor, :update, course, course_id)
      course.update(course_data) || raise("Failed to update course with ID #{course_id}.")
    end

    # Removes a course, if authorized
    def self.remove(requestor, course_id)
      course = find_course(course_id)
      verify_policy(requestor, :delete, course, course_id)
      course.destroy
    end

    def self.remove_enroll(requestor, course_id, account_id)
      course = find_course(course_id)
      verify_policy(requestor, :update, course, course_id)
      account = AccountCourse.first(account_id: account_id)
      account.destroy
    end

    def self.get_enrollments(requestor, course_id)
      course = find_course(course_id)
      verify_policy(requestor, :view, course, course_id)
      course.get_enrollments()
    end

    def self.update_enrollments(requestor, course_id, enrolled_data)
      course = find_course(course_id)
      verify_policy(requestor, :update, course, course_id)
      course.add_or_update_enrollments(enrolled_data)
    end

    def self.update_enrollment(requestor, course_id, account_id, enrolled_data)
      course = find_course(course_id)
      verify_policy(requestor, :update, course, course_id)
      course.update_single_enrollment(account_id, enrolled_data)
    end

    private

    def self.find_course(course_id)
      Course.first(id: course_id) || raise(CourseNotFoundError, "Course with ID #{course_id} not found.")
    end

    # Checks authorization for the requested action
    def self.verify_policy(requestor, action = nil, course = nil, course_id = nil)
      course_roles = AccountCourse.where(account_id: requestor['account_id'], course_id: course_id).map do |role|
        role.role.name
      end
      policy = CoursePolicy.new(requestor, course, course_roles)
      action_check = action ? policy.send("can_#{action}?") : true
      raise(ForbiddenError, 'You have no access to perform this action.') unless action_check

      requestor
    end
  end
end
