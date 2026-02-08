# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Courses::GetAssignableRoles' do
  include TestHelpers

  def create_test_course(owner_account, name: 'Test Course')
    course = Tyto::Course.create(name: name)
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(
      course_id: course.id,
      account_id: owner_account.id,
      role_id: owner_role.id
    )
    course
  end

  def enroll_as(account, course, role_name)
    role = Tyto::Role.find(name: role_name)
    Tyto::AccountCourse.create(
      course_id: course.id,
      account_id: account.id,
      role_id: role.id
    )
  end

  def requestor_for(account)
    roles = account.roles.map(&:name)
    Tyto::Domain::Accounts::Values::AuthCapability.new(
      account_id: account.id, roles: roles
    )
  end

  # 3.1a: Owner permission tests
  describe 'owner permissions' do
    it 'returns all four course roles for owner' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)

      result = Tyto::Service::Courses::GetAssignableRoles.new.call(
        requestor: requestor_for(owner), course_id: course.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      assignable = result.value!.message
      _(assignable).must_include 'owner'
      _(assignable).must_include 'instructor'
      _(assignable).must_include 'staff'
      _(assignable).must_include 'student'
      _(assignable.length).must_equal 4
    end
  end

  # 3.1b: Instructor permission tests
  describe 'instructor permissions' do
    it 'returns staff and student for instructor' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      instructor = create_test_account(roles: ['member'])
      enroll_as(instructor, course, 'instructor')

      result = Tyto::Service::Courses::GetAssignableRoles.new.call(
        requestor: requestor_for(instructor), course_id: course.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      assignable = result.value!.message
      _(assignable).must_include 'staff'
      _(assignable).must_include 'student'
      _(assignable).wont_include 'owner'
      _(assignable).wont_include 'instructor'
      _(assignable.length).must_equal 2
    end
  end

  # 3.1c: Student and non-enrolled permission tests
  describe 'student permissions' do
    it 'returns empty array for student' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(roles: ['member'])
      enroll_as(student, course, 'student')

      result = Tyto::Service::Courses::GetAssignableRoles.new.call(
        requestor: requestor_for(student), course_id: course.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      assignable = result.value!.message
      _(assignable).must_be_kind_of Array
      _(assignable).must_be_empty
    end
  end

  describe 'staff permissions' do
    it 'returns student for staff' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      staff_member = create_test_account(roles: ['member'])
      enroll_as(staff_member, course, 'staff')

      result = Tyto::Service::Courses::GetAssignableRoles.new.call(
        requestor: requestor_for(staff_member), course_id: course.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      assignable = result.value!.message
      _(assignable).must_equal ['student']
    end
  end

  describe 'non-enrolled user' do
    it 'returns forbidden for non-enrolled user' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      outsider = create_test_account(roles: ['member'])

      result = Tyto::Service::Courses::GetAssignableRoles.new.call(
        requestor: requestor_for(outsider), course_id: course.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end

  describe 'invalid course' do
    it 'returns not_found for nonexistent course' do
      account = create_test_account(roles: ['creator'])

      result = Tyto::Service::Courses::GetAssignableRoles.new.call(
        requestor: requestor_for(account), course_id: 99999
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end
  end
end
