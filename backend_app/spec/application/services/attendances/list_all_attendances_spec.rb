# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Attendances::ListAllAttendances' do
  include TestHelpers

  def create_test_course(owner_account, name: 'Test Course')
    course = Todo::Course.create(name: name)
    owner_role = Todo::Role.find(name: 'owner')
    Todo::AccountCourse.create(
      course_id: course.id,
      account_id: owner_account.id,
      role_id: owner_role.id
    )
    course
  end

  def create_test_attendance(course, account, event: nil)
    student_role = Todo::Role.find(name: 'student')
    Todo::Attendance.create(
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
    it 'returns Success with attendances for owner' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(name: 'Student', roles: ['member'])
      create_test_attendance(course, student)

      requestor = { 'account_id' => owner.id }
      result = Todo::Service::Attendances::ListAllAttendances.new.call(
        requestor:,
        course_id: course.id
      )

      _(result.success?).must_equal true
      _(result.value!.status).must_equal :ok
      _(result.value!.message.length).must_equal 1
    end

    it 'returns Success for instructor' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      instructor_role = Todo::Role.find(name: 'instructor')
      Todo::AccountCourse.create(course_id: course.id, account_id: instructor.id, role_id: instructor_role.id)

      requestor = { 'account_id' => instructor.id }
      result = Todo::Service::Attendances::ListAllAttendances.new.call(requestor:, course_id: course.id)

      _(result.success?).must_equal true
    end

    it 'returns Failure for student (cannot view all)' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Todo::Role.find(name: 'student')
      Todo::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = { 'account_id' => student.id }
      result = Todo::Service::Attendances::ListAllAttendances.new.call(requestor:, course_id: course.id)

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-enrolled user' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      other = create_test_account(name: 'Other', roles: ['member'])

      requestor = { 'account_id' => other.id }
      result = Todo::Service::Attendances::ListAllAttendances.new.call(requestor:, course_id: course.id)

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent course' do
      account = create_test_account(roles: ['creator'])
      requestor = { 'account_id' => account.id }
      result = Todo::Service::Attendances::ListAllAttendances.new.call(requestor:, course_id: 99999)

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :not_found
    end
  end
end
