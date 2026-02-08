# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Domain::Attendance::Values::StudentAttendanceRecord' do
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

  def build_register(attendances)
    Tyto::Domain::Attendance::Values::AttendanceRegister.new(attendances: attendances)
  end

  def build_attendance(account_id:, event_id:)
    Tyto::Entity::Attendance.new(
      id: nil, account_id: account_id, course_id: 1, event_id: event_id,
      role_id: nil, name: nil, longitude: nil, latitude: nil,
      created_at: nil, updated_at: nil
    )
  end

  def build_record(account_id:, email:, events:, attendances:)
    enrollment = build_enrollment(account_id: account_id, email: email)
    register = build_register(attendances)
    Tyto::Domain::Attendance::Values::StudentAttendanceRecord.new(
      enrollment: enrollment, events: events, register: register
    )
  end

  it 'computes full attendance' do
    events = [build_event(id: 10, name: 'L1'), build_event(id: 20, name: 'L2')]
    record = build_record(
      account_id: 1, email: 'alice@example.com', events: events,
      attendances: [
        build_attendance(account_id: 1, event_id: 10),
        build_attendance(account_id: 1, event_id: 20)
      ]
    )

    _(record.email).must_equal 'alice@example.com'
    _(record.attend_sum).must_equal 2
    _(record.attend_percent).must_equal 100.0
    _(record.event_attendance).must_equal({ 10 => 1, 20 => 1 })
  end

  it 'computes partial attendance' do
    events = [build_event(id: 10, name: 'L1'), build_event(id: 20, name: 'L2')]
    record = build_record(
      account_id: 1, email: 'bob@example.com', events: events,
      attendances: [build_attendance(account_id: 1, event_id: 10)]
    )

    _(record.attend_sum).must_equal 1
    _(record.attend_percent).must_equal 50.0
    _(record.event_attendance[10]).must_equal 1
    _(record.event_attendance[20]).must_equal 0
  end

  it 'handles zero events' do
    record = build_record(
      account_id: 1, email: 'charlie@example.com',
      events: [], attendances: []
    )

    _(record.attend_sum).must_equal 0
    _(record.attend_percent).must_equal 0.0
    _(record.event_attendance).must_be_empty
  end

  it 'is a value object (equal when attributes match)' do
    events = [build_event(id: 10, name: 'L1')]
    attendances = [build_attendance(account_id: 1, event_id: 10)]

    record_a = build_record(account_id: 1, email: 'alice@example.com',
                            events: events, attendances: attendances)
    record_b = build_record(account_id: 1, email: 'alice@example.com',
                            events: events, attendances: attendances)

    _(record_a).must_equal record_b
  end
end
