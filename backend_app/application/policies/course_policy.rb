# frozen_string_literal: true

class CoursePolicy
  def initialize(requestor, course = nil, course_roles = nil)
    @requestor = requestor
    @this_course = course
    @course_roles = course_roles
  end

  def can_view_all?
    requestor_is_admin?
  end

  def can_create?
    requestor_is_creator?
  end

  def can_view?
    self_enrolled?
  end

  def can_update?
    requestor_is_instructor? || requestor_is_owner? || requestor_is_staff?
  end

  def can_delete?
    requestor_is_admin? || requestor_is_owner?
  end

  def summary
    {
      can_view_all: can_view_all?,
      can_view: can_view?,
      can_create: can_create?,
      can_update: can_update?,
      can_delete: can_delete?
    }
  end

  private

  # Check if the requestor is enrolled in the course
  def self_enrolled?
    enroll = @this_course&.accounts&.any? { |account| account.id == @requestor['account_id'] }
    enroll
  end

  # Check if the requestor has an admin role
  def requestor_is_admin?
    @requestor['roles'].include?('admin')
  end

  # Check if the requestor has an creator role
  def requestor_is_creator?
    @requestor['roles'].include?('creator')
  end

  def requestor_is_instructor?
    @course_roles.include?('instructor')
  end

  def requestor_is_staff?
    @course_roles.include?('staff')
  end

  def requestor_is_owner?
    @course_roles.include?('owner')
  end
end
