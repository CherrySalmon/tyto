# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Domain::Attendance::Values::AttendanceRegister' do
  def build_attendance(account_id:, event_id:)
    Tyto::Entity::Attendance.new(
      id: nil, account_id: account_id, course_id: 1, event_id: event_id,
      role_id: nil, name: nil, longitude: nil, latitude: nil,
      created_at: nil, updated_at: nil
    )
  end

  it 'records attendance for fast lookup' do
    attendances = [
      build_attendance(account_id: 1, event_id: 10),
      build_attendance(account_id: 1, event_id: 20),
      build_attendance(account_id: 2, event_id: 10)
    ]

    register = Tyto::Domain::Attendance::Values::AttendanceRegister.new(attendances: attendances)

    _(register.attended?(1, 10)).must_equal true
    _(register.attended?(1, 20)).must_equal true
    _(register.attended?(2, 10)).must_equal true
    _(register.attended?(2, 20)).must_equal false
  end

  it 'handles empty attendances' do
    register = Tyto::Domain::Attendance::Values::AttendanceRegister.new(attendances: [])

    _(register.attended?(1, 10)).must_equal false
  end
end
