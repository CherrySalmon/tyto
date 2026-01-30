# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Attendances::RecordAttendance' do
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

  def create_test_location(course, name: 'Test Location')
    Tyto::Location.create(
      course_id: course.id,
      name: name,
      latitude: 40.7128,
      longitude: -74.0060
    )
  end

  def create_test_event(course, location, name: 'Test Event')
    Tyto::Event.create(
      course_id: course.id,
      location_id: location.id,
      name: name,
      start_at: Time.now - 1800,
      end_at: Time.now + 1800
    )
  end

  describe '#call' do
    it 'returns Success when student records attendance' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course.id,
        attendance_data: {
          'event_id' => event.id,
          'latitude' => 40.7128,
          'longitude' => -74.0060
        }
      )

      _(result.success?).must_equal true
      _(result.value!.status).must_equal :created
      _(result.value!.message.event_id).must_equal event.id
    end

    it 'creates attendance with auto-generated name' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location, name: 'Morning Class')

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course.id,
        attendance_data: { 'event_id' => event.id }
      )

      _(result.success?).must_equal true
      _(result.value!.message.name).must_equal 'Morning Class Attendance'
    end

    it 'persists attendance to database' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      initial_count = Tyto::Attendance.count
      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course.id,
        attendance_data: { 'event_id' => event.id }
      )

      _(Tyto::Attendance.count).must_equal(initial_count + 1)
    end

    it 'returns Failure for non-enrolled user' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)
      other = create_test_account(name: 'Other', roles: ['member'])

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: other.id, roles: ['creator'])
      result = Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course.id,
        attendance_data: { 'event_id' => event.id }
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure when event_id is missing' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course.id,
        attendance_data: {}
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when event does not exist' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course.id,
        attendance_data: { 'event_id' => 99999 }
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure when event does not belong to course' do
      owner = create_test_account(roles: ['creator'])
      course1 = create_test_course(owner, name: 'Course 1')
      course2 = create_test_course(owner, name: 'Course 2')
      location = create_test_location(course1)
      event = create_test_event(course1, location)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course2.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course2.id,
        attendance_data: { 'event_id' => event.id }
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure for invalid coordinates' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course.id,
        attendance_data: { 'event_id' => event.id, 'latitude' => 91, 'longitude' => 0 }
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end
  end

  describe 'Representer integration' do
    it 'serializes attendance via Attendance representer' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)

      student = create_test_account(name: 'Student', roles: ['member'])
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

      requestor = Tyto::Domain::Accounts::Values::Requestor.new(account_id: student.id, roles: ['creator'])
      result = Tyto::Service::Attendances::RecordAttendance.new.call(
        requestor:,
        course_id: course.id,
        attendance_data: { 'event_id' => event.id }
      )

      attendance = result.value!.message
      json_hash = Tyto::Representer::Attendance.new(attendance).to_hash

      _(json_hash).must_be_kind_of Hash
      _(json_hash['event_id']).must_equal event.id
      _(json_hash['created_at']).must_be_kind_of String
    end
  end
end
