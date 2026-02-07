# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Policy::AttendanceEligibility' do
  let(:now) { Time.now }

  def build_attendance(longitude:, latitude:)
    Tyto::Entity::Attendance.new(
      id: nil, account_id: 1, course_id: 1, event_id: 1, role_id: 1,
      name: 'Test', longitude: longitude, latitude: latitude,
      created_at: nil, updated_at: nil
    )
  end

  def build_location(longitude:, latitude:)
    Tyto::Entity::Location.new(
      id: 1, course_id: 1, name: 'Classroom',
      longitude: longitude, latitude: latitude,
      created_at: now, updated_at: now
    )
  end

  def build_event(start_at:, end_at:)
    Tyto::Entity::Event.new(
      id: 1, course_id: 1, location_id: 1, name: 'Test Event',
      start_at: start_at, end_at: end_at,
      created_at: now, updated_at: now
    )
  end

  def active_event
    build_event(start_at: now - 1800, end_at: now + 1800)
  end

  describe 'MAX_DISTANCE_KM' do
    it 'is approximately 55 meters' do
      _(Tyto::Policy::AttendanceEligibility::MAX_DISTANCE_KM).must_equal 0.055
    end
  end

  describe 'time window' do
    it 'returns nil when event is currently active' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: -74.0060, latitude: 40.7128)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event: active_event, location:, time: now
      )
      _(result).must_be_nil
    end

    it 'returns :time_window when event has ended' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: -74.0060, latitude: 40.7128)
      event = build_event(start_at: now - 3600, end_at: now - 1800)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event:, location:, time: now
      )
      _(result).must_equal :time_window
    end

    it 'returns :time_window when event has not started yet' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: -74.0060, latitude: 40.7128)
      event = build_event(start_at: now + 1800, end_at: now + 3600)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event:, location:, time: now
      )
      _(result).must_equal :time_window
    end

    it 'returns nil when event has no time range' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: -74.0060, latitude: 40.7128)
      event = Tyto::Entity::Event.new(
        id: 1, course_id: 1, location_id: 1, name: 'Test Event',
        start_at: nil, end_at: nil, created_at: now, updated_at: now
      )

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event:, location:, time: now
      )
      _(result).must_be_nil
    end

    it 'returns nil at the exact start time' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: -74.0060, latitude: 40.7128)
      event = build_event(start_at: now, end_at: now + 3600)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event:, location:, time: now
      )
      _(result).must_be_nil
    end

    it 'returns nil at the exact end time' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: -74.0060, latitude: 40.7128)
      event = build_event(start_at: now - 3600, end_at: now)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event:, location:, time: now
      )
      _(result).must_be_nil
    end
  end

  describe 'proximity' do
    it 'returns nil when attendance is at the event location' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: -74.0060, latitude: 40.7128)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event: active_event, location:
      )
      _(result).must_be_nil
    end

    it 'returns nil when attendance is within 55m of event location' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      # ~30m away
      location = build_location(longitude: -74.0057, latitude: 40.7128)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event: active_event, location:
      )
      _(result).must_be_nil
    end

    it 'returns :proximity when attendance is beyond 55m of event location' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      # ~32km away
      location = build_location(longitude: -74.0, latitude: 41.0)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event: active_event, location:
      )
      _(result).must_equal :proximity
    end

    it 'returns nil when event location is nil' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event: active_event, location: nil
      )
      _(result).must_be_nil
    end

    it 'returns nil when event location has no coordinates' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: nil, latitude: nil)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event: active_event, location:
      )
      _(result).must_be_nil
    end

    it 'returns :proximity when attendance has no coordinates but event location does' do
      attendance = build_attendance(longitude: nil, latitude: nil)
      location = build_location(longitude: -74.0060, latitude: 40.7128)

      result = Tyto::Policy::AttendanceEligibility.check(
        attendance:, event: active_event, location:
      )
      _(result).must_equal :proximity
    end
  end
end
