# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Attendances::ListEventParticipants' do
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
    it 'returns enrolled students with attendance status for an event' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_active_event(course, location)

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      enroll(instructor, course, 'instructor')

      student1 = create_test_account(name: 'Student One', roles: ['member'])
      enroll(student1, course, 'student')

      student2 = create_test_account(name: 'Student Two', roles: ['member'])
      enroll(student2, course, 'student')

      # Mark student1 as attended
      student_role = Tyto::Role.find(name: 'student')
      Tyto::Attendance.create(
        account_id: student1.id, course_id: course.id, event_id: event.id,
        role_id: student_role.id, name: 'Test'
      )

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: instructor.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::ListEventParticipants.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: event.id
      )

      _(result.success?).must_equal true
      summary = result.value!.message

      _(summary).must_be_kind_of Tyto::Domain::Attendance::Entities::EventAttendanceReport
      _(summary.participants.length).must_equal 2
      _(summary.participants.first).must_be_kind_of Tyto::Domain::Attendance::Values::ParticipantAttendance

      attended_ids = summary.participants.select(&:attended).map(&:account_id)
      _(attended_ids).must_include student1.id
      _(attended_ids).wont_include student2.id
    end
    it 'includes can_manage policy in response for instructor' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_active_event(course, location)

      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      enroll(instructor, course, 'instructor')

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: instructor.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::ListEventParticipants.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: event.id
      )

      _(result.success?).must_equal true
      policies = result.value!.message.policies
      _(policies[:can_manage]).must_equal true
    end

    it 'includes can_manage as false for owner' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_active_event(course, location)

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: owner.id, roles: ['creator']
      )

      result = Tyto::Service::Attendances::ListEventParticipants.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: event.id
      )

      _(result.success?).must_equal true
      policies = result.value!.message.policies
      _(policies[:can_manage]).must_equal false
    end
    it 'rejects non-teaching-staff requestor' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_active_event(course, location)

      student = create_test_account(name: 'Student', roles: ['member'])
      enroll(student, course, 'student')

      requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: student.id, roles: ['member']
      )

      result = Tyto::Service::Attendances::ListEventParticipants.new.call(
        requestor: requestor,
        course_id: course.id,
        event_id: event.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end
  end
end
