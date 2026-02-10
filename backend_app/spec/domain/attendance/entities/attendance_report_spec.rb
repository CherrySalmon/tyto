# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Entity::AttendanceReport' do
  def build_course(name:, events: [], enrollments: [])
    Tyto::Entity::Course.new(
      id: 1, name: name, logo: nil, start_at: nil, end_at: nil,
      created_at: Time.now, updated_at: Time.now,
      events: Tyto::Domain::Courses::Values::Events.from(events),
      locations: Tyto::Domain::Courses::Values::Locations.from([]),
      enrollments: Tyto::Domain::Courses::Values::Enrollments.from(enrollments)
    )
  end

  def build_event(id:, name:)
    Tyto::Entity::Event.new(
      id: id, course_id: 1, location_id: 1, name: name,
      start_at: Time.now, end_at: Time.now + 3600,
      created_at: Time.now, updated_at: Time.now
    )
  end

  def build_enrollment(account_id:, email:)
    Tyto::Entity::Enrollment.new(
      id: account_id, account_id: account_id, course_id: 1,
      participant: Tyto::Domain::Courses::Values::Participant.new(email: email, name: 'Test'),
      roles: Tyto::Domain::Courses::Values::CourseRoles.from(['student']),
      created_at: Time.now, updated_at: Time.now
    )
  end

  def build_attendance(account_id:, event_id:)
    Tyto::Entity::Attendance.new(
      id: nil, account_id: account_id, course_id: 1, event_id: event_id,
      role_id: nil, name: nil, longitude: nil, latitude: nil,
      created_at: nil, updated_at: nil
    )
  end

  describe '.build' do
    it 'builds report with course name and generated_at' do
      course = build_course(name: 'Test Course')
      report = Tyto::Entity::AttendanceReport.new(course: course, attendances: [])

      _(report.course_name).must_equal 'Test Course'
      _(report.generated_at).must_be_kind_of Time
    end

    it 'builds report with events as ReportEvent structs' do
      event1 = build_event(id: 10, name: 'Lecture 1')
      event2 = build_event(id: 20, name: 'Lecture 2')
      course = build_course(name: 'C', events: [event1, event2])

      report = Tyto::Entity::AttendanceReport.new(course: course, attendances: [])

      _(report.events.length).must_equal 2
      _(report.events[0].id).must_equal 10
      _(report.events[0].name).must_equal 'Lecture 1'
      _(report.events[1].id).must_equal 20
      _(report.events[1].name).must_equal 'Lecture 2'
    end

    it 'computes 100% attendance for student who attended all events' do
      event1 = build_event(id: 10, name: 'Lecture 1')
      enrollment = build_enrollment(account_id: 100, email: 'alice@example.com')
      course = build_course(name: 'C', events: [event1], enrollments: [enrollment])
      attendances = [build_attendance(account_id: 100, event_id: 10)]

      report = Tyto::Entity::AttendanceReport.new(course: course, attendances: attendances)

      _(report.student_records.length).must_equal 1
      record = report.student_records.first
      _(record.email).must_equal 'alice@example.com'
      _(record.attend_sum).must_equal 1
      _(record.attend_percent).must_equal 100.0
      _(record.event_attendance[10]).must_equal 1
    end

    it 'computes correct statistics for multiple students and events' do
      event1 = build_event(id: 10, name: 'Lecture 1')
      event2 = build_event(id: 20, name: 'Lecture 2')
      alice = build_enrollment(account_id: 100, email: 'alice@example.com')
      bob = build_enrollment(account_id: 200, email: 'bob@example.com')
      course = build_course(name: 'C', events: [event1, event2], enrollments: [alice, bob])

      attendances = [
        build_attendance(account_id: 100, event_id: 10),
        build_attendance(account_id: 100, event_id: 20),
        build_attendance(account_id: 200, event_id: 10)
      ]

      report = Tyto::Entity::AttendanceReport.new(course: course, attendances: attendances)

      _(report.student_records.length).must_equal 2

      alice_rec = report.student_records.find { |r| r.email == 'alice@example.com' }
      bob_rec = report.student_records.find { |r| r.email == 'bob@example.com' }

      _(alice_rec.attend_sum).must_equal 2
      _(alice_rec.attend_percent).must_equal 100.0
      _(alice_rec.event_attendance[10]).must_equal 1
      _(alice_rec.event_attendance[20]).must_equal 1

      _(bob_rec.attend_sum).must_equal 1
      _(bob_rec.attend_percent).must_equal 50.0
      _(bob_rec.event_attendance[10]).must_equal 1
      _(bob_rec.event_attendance[20]).must_equal 0
    end

    it 'handles zero events with attend_percent of 0.0' do
      enrollment = build_enrollment(account_id: 100, email: 'alice@example.com')
      course = build_course(name: 'C', events: [], enrollments: [enrollment])

      report = Tyto::Entity::AttendanceReport.new(course: course, attendances: [])

      _(report.events).must_be_empty
      record = report.student_records.first
      _(record.attend_sum).must_equal 0
      _(record.attend_percent).must_equal 0.0
    end

    it 'handles course with no students' do
      event = build_event(id: 10, name: 'Lecture 1')
      course = build_course(name: 'C', events: [event], enrollments: [])

      report = Tyto::Entity::AttendanceReport.new(course: course, attendances: [])

      _(report.student_records).must_be_empty
      _(report.events.length).must_equal 1
    end

    it 'returns StudentAttendanceRecord value objects' do
      enrollment = build_enrollment(account_id: 100, email: 'alice@example.com')
      course = build_course(name: 'C', events: [], enrollments: [enrollment])

      report = Tyto::Entity::AttendanceReport.new(course: course, attendances: [])

      _(report.student_records.first).must_be_kind_of(
        Tyto::Domain::Attendance::Values::StudentAttendanceRecord
      )
    end
  end
end
