# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Attendances::GenerateReport' do
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

  def enroll_student(course, account)
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(
      course_id: course.id,
      account_id: account.id,
      role_id: student_role.id
    )
  end

  def create_event(course, name: 'Event')
    location_name = "Room-#{SecureRandom.hex(4)}"
    location = Tyto::Location.create(
      course_id: course.id, name: location_name, latitude: 0, longitude: 0
    )
    Tyto::Event.create(
      course_id: course.id, location_id: location.id, name: name,
      start_at: Time.now, end_at: Time.now + 3600
    )
  end

  def record_attendance(course, account, event)
    student_role = Tyto::Role.find(name: 'student')
    Tyto::Attendance.create(
      course_id: course.id, account_id: account.id,
      event_id: event.id, role_id: student_role.id,
      name: 'Test', latitude: 0, longitude: 0
    )
  end

  def requestor_for(account)
    Tyto::Domain::Accounts::Values::AuthCapability.new(
      account_id: account.id, roles: ['creator']
    )
  end

  describe '#call' do
    it 'returns Success with report for owner' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(name: 'Student', roles: ['member'])
      enroll_student(course, student)
      event = create_event(course, name: 'Lecture 1')
      record_attendance(course, student, event)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(owner), course_id: course.id
      )

      _(result.success?).must_equal true
      report = result.value!.message
      _(report.course_name).must_equal 'Test Course'
      _(report.events.length).must_equal 1
      _(report.events.first.name).must_equal 'Lecture 1'
      _(report.student_records.length).must_equal 1

      record = report.student_records.first
      _(record.email).must_equal student.email
      _(record.attend_sum).must_equal 1
      _(record.attend_percent).must_equal 100.0
      _(record.event_attendance[event.id]).must_equal 1
    end

    it 'returns Success for instructor' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      instructor = create_test_account(name: 'Instructor', roles: ['member'])
      instructor_role = Tyto::Role.find(name: 'instructor')
      Tyto::AccountCourse.create(
        course_id: course.id, account_id: instructor.id, role_id: instructor_role.id
      )

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(instructor), course_id: course.id
      )

      _(result.success?).must_equal true
    end

    it 'computes correct statistics for multiple students and events' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)

      student_a = create_test_account(name: 'Alice', roles: ['member'])
      student_b = create_test_account(name: 'Bob', roles: ['member'])
      enroll_student(course, student_a)
      enroll_student(course, student_b)

      event1 = create_event(course, name: 'Lecture 1')
      event2 = create_event(course, name: 'Lecture 2')

      # Alice attended both, Bob attended only event1
      record_attendance(course, student_a, event1)
      record_attendance(course, student_a, event2)
      record_attendance(course, student_b, event1)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(owner), course_id: course.id
      )

      _(result.success?).must_equal true
      report = result.value!.message

      _(report.events.length).must_equal 2
      _(report.student_records.length).must_equal 2

      alice_rec = report.student_records.find { |r| r.email == student_a.email }
      bob_rec = report.student_records.find { |r| r.email == student_b.email }

      _(alice_rec.attend_sum).must_equal 2
      _(alice_rec.attend_percent).must_equal 100.0
      _(alice_rec.event_attendance[event1.id]).must_equal 1
      _(alice_rec.event_attendance[event2.id]).must_equal 1

      _(bob_rec.attend_sum).must_equal 1
      _(bob_rec.attend_percent).must_equal 50.0
      _(bob_rec.event_attendance[event1.id]).must_equal 1
      _(bob_rec.event_attendance[event2.id]).must_equal 0
    end

    it 'handles zero events with attend_percent of 0.0' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(name: 'Student', roles: ['member'])
      enroll_student(course, student)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(owner), course_id: course.id
      )

      _(result.success?).must_equal true
      report = result.value!.message
      _(report.events).must_be_empty

      record = report.student_records.first
      _(record.attend_sum).must_equal 0
      _(record.attend_percent).must_equal 0.0
    end

    it 'includes generated_at timestamp' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(owner), course_id: course.id
      )

      _(result.success?).must_equal true
      _(result.value!.message.generated_at).must_be_kind_of Time
    end

    it 'returns Failure for student (cannot view all)' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(name: 'Student', roles: ['member'])
      enroll_student(course, student)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(student), course_id: course.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-enrolled user' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      other = create_test_account(name: 'Other', roles: ['member'])

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(other), course_id: course.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent course' do
      account = create_test_account(roles: ['creator'])

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(account), course_id: 99999
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure for invalid course ID' do
      account = create_test_account(roles: ['creator'])

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor_for(account), course_id: 'abc'
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :bad_request
    end
  end
end
