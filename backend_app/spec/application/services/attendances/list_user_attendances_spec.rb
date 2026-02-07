# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Attendances::ListUserAttendances' do
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

  def create_test_attendance(course, account, event: nil)
    student_role = Tyto::Role.find(name: 'student')
    Tyto::Attendance.create(
      course_id: course.id,
      account_id: account.id,
      event_id: event&.id,
      role_id: student_role.id,
      name: 'Test Attendance',
      latitude: 40.7128,
      longitude: -74.0060
    )
  end

  describe '#call' do
    it 'returns Success with own attendances for enrolled student' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)
      create_test_attendance(course, student)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['member'])
      result = Tyto::Service::Attendances::ListUserAttendances.new.call(
        requestor:,
        course_id: course.id
      )

      _(result.success?).must_equal true
      _(result.value!.status).must_equal :ok
      _(result.value!.message.length).must_equal 1
    end

    it 'returns only the requesting users attendances' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)

      student1 = create_test_account(name: 'Student1', roles: ['member'])
      student2 = create_test_account(name: 'Student2', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student1.id, role_id: student_role.id)
      Tyto::AccountCourse.create(course_id: course.id, account_id: student2.id, role_id: student_role.id)
      create_test_attendance(course, student1)
      create_test_attendance(course, student2)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student1.id, roles: ['member'])
      result = Tyto::Service::Attendances::ListUserAttendances.new.call(
        requestor:,
        course_id: course.id
      )

      _(result.success?).must_equal true
      attendances = result.value!.message
      _(attendances.length).must_equal 1
      _(attendances.first.account_id).must_equal student1.id
    end

    it 'returns Failure for non-enrolled user' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      other = create_test_account(name: 'Other', roles: ['member'])

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: other.id, roles: ['member'])
      result = Tyto::Service::Attendances::ListUserAttendances.new.call(
        requestor:,
        course_id: course.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent course' do
      account = create_test_account(roles: ['member'])
      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member'])
      result = Tyto::Service::Attendances::ListUserAttendances.new.call(
        requestor:,
        course_id: 99999
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure for invalid course ID' do
      account = create_test_account(roles: ['member'])
      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member'])
      result = Tyto::Service::Attendances::ListUserAttendances.new.call(
        requestor:,
        course_id: 'abc'
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end
  end
end
