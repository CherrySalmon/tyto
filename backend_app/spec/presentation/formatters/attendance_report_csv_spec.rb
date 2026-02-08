# frozen_string_literal: true

require_relative '../../spec_helper'

describe 'Presentation::Formatters::AttendanceReportCsv' do
  def build_course(name:, events: [], enrollments: [])
    Tyto::Entity::Course.new(
      id: 1, name: name, logo: nil, start_at: nil, end_at: nil,
      created_at: Time.now, updated_at: Time.now,
      events: events, locations: [], enrollments: enrollments
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
      account_email: email, account_name: 'Test',
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

  def build_report(course:, attendances: [])
    Tyto::Entity::AttendanceReport.new(course: course, attendances: attendances)
  end

  describe '.to_csv' do
    it 'generates CSV with correct headers' do
      events = [build_event(id: 1, name: 'Lecture 1'), build_event(id: 2, name: 'Lecture 2')]
      report = build_report(course: build_course(name: 'C', events: events))

      csv = Tyto::Presentation::Formatters::AttendanceReportCsv.to_csv(report)
      lines = csv.split("\n")

      _(lines.first).must_equal 'Student Email,attend_sum,attend_percent,Lecture 1,Lecture 2'
    end

    it 'generates CSV with student rows' do
      events = [build_event(id: 1, name: 'Lecture 1'), build_event(id: 2, name: 'Lecture 2')]
      alice = build_enrollment(account_id: 1, email: 'alice@example.com')
      bob = build_enrollment(account_id: 2, email: 'bob@example.com')
      course = build_course(name: 'C', events: events, enrollments: [alice, bob])

      attendances = [
        build_attendance(account_id: 1, event_id: 1),
        build_attendance(account_id: 1, event_id: 2),
        build_attendance(account_id: 2, event_id: 1)
      ]

      report = build_report(course: course, attendances: attendances)
      csv = Tyto::Presentation::Formatters::AttendanceReportCsv.to_csv(report)
      lines = csv.split("\n")

      _(lines.length).must_equal 3
      _(lines[1]).must_equal 'alice@example.com,2,100.0,1,1'
      _(lines[2]).must_equal 'bob@example.com,1,50.0,1,0'
    end

    it 'handles empty report (no events, no students)' do
      report = build_report(course: build_course(name: 'C'))

      csv = Tyto::Presentation::Formatters::AttendanceReportCsv.to_csv(report)
      lines = csv.split("\n")

      _(lines.length).must_equal 1
      _(lines.first).must_equal 'Student Email,attend_sum,attend_percent'
    end

    it 'handles students with no events' do
      alice = build_enrollment(account_id: 1, email: 'alice@example.com')
      report = build_report(course: build_course(name: 'C', enrollments: [alice]))

      csv = Tyto::Presentation::Formatters::AttendanceReportCsv.to_csv(report)
      lines = csv.split("\n")

      _(lines.length).must_equal 2
      _(lines[1]).must_equal 'alice@example.com,0,0.0'
    end
  end
end
