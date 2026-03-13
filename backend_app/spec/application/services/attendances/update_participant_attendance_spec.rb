# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Attendances::UpdateParticipantAttendance' do
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

  def create_active_event(course, location, name: 'Active Event')
    Tyto::Event.create(
      course_id: course.id,
      location_id: location.id,
      name: name,
      start_at: Time.now - 1800,
      end_at: Time.now + 1800
    )
  end

  def enroll(account, course, role_name)
    role = Tyto::Role.find(name: role_name)
    Tyto::AccountCourse.create(course_id: course.id, account_id: account.id, role_id: role.id)
  end

  describe '#call' do
    it 'creates attendance when instructor marks student as attended' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_active_event(course, location)

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      enroll(instructor, course, 'instructor')

      student = create_test_account(name: 'Student', roles: ['member'])
      enroll(student, course, 'student')

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: instructor.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::UpdateParticipantAttendance.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: event.id,
        target_account_id: student.id,
        attended: true
      )

      _(result.success?).must_equal true
      _(result.value!.status).must_equal :ok

      # Verify attendance was created
      attendance = Tyto::Attendance.first(account_id: student.id, event_id: event.id)
      _(attendance).wont_be_nil
    end
    it 'deletes attendance when instructor unmarks student' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_active_event(course, location)

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      enroll(instructor, course, 'instructor')

      student = create_test_account(name: 'Student', roles: ['member'])
      enroll(student, course, 'student')

      # First create an attendance record
      student_role = Tyto::Role.find(name: 'student')
      Tyto::Attendance.create(
        account_id: student.id, course_id: course.id, event_id: event.id,
        role_id: student_role.id, name: 'Test'
      )

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: instructor.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::UpdateParticipantAttendance.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: event.id,
        target_account_id: student.id,
        attended: false
      )

      _(result.success?).must_equal true

      # Verify attendance was deleted
      attendance = Tyto::Attendance.first(account_id: student.id, event_id: event.id)
      _(attendance).must_be_nil
    end
    it 'rejects requestor without instructor or staff role' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_active_event(course, location)

      student = create_test_account(name: 'Student', roles: ['member'])
      enroll(student, course, 'student')

      other_student = create_test_account(name: 'Other Student', roles: ['member'])
      enroll(other_student, course, 'student')

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: student.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::UpdateParticipantAttendance.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: event.id,
        target_account_id: other_student.id,
        attended: true
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end
    it 'rejects non-enrolled target student' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_active_event(course, location)

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      enroll(instructor, course, 'instructor')

      non_enrolled = create_test_account(name: 'Not Enrolled', roles: ['member'])

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: instructor.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::UpdateParticipantAttendance.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: event.id,
        target_account_id: non_enrolled.id,
        attended: true
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end
    it 'rejects future event' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      future_event = Tyto::Event.create(
        course_id: course.id,
        location_id: location.id,
        name: 'Future Event',
        start_at: Time.now + 3600,
        end_at: Time.now + 7200
      )

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      enroll(instructor, course, 'instructor')

      student = create_test_account(name: 'Student', roles: ['member'])
      enroll(student, course, 'student')

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: instructor.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::UpdateParticipantAttendance.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: future_event.id,
        target_account_id: student.id,
        attended: true
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end
    it 'rejects event not belonging to course' do
      owner = create_test_account(roles: ['creator'])
      course1 = create_test_course(owner, name: 'Course 1')
      course2 = create_test_course(owner, name: 'Course 2')
      location = create_test_location(course1)
      event = create_active_event(course1, location)

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      enroll(instructor, course2, 'instructor')

      student = create_test_account(name: 'Student', roles: ['member'])
      enroll(student, course2, 'student')

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: instructor.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::UpdateParticipantAttendance.new.call(
        requestor: requestor,
        course_id: course2.id,
        event_id: event.id,
        target_account_id: student.id,
        attended: true
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end

    it 'allows marking attendance for a past event' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      past_event = Tyto::Event.create(
        course_id: course.id,
        location_id: location.id,
        name: 'Past Event',
        start_at: Time.now - 7200,
        end_at: Time.now - 1800
      )

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      enroll(instructor, course, 'instructor')

      student = create_test_account(name: 'Student', roles: ['member'])
      enroll(student, course, 'student')

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: instructor.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::UpdateParticipantAttendance.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: past_event.id,
        target_account_id: student.id,
        attended: true
      )

      _(result.success?).must_equal true
    end
  end
end
