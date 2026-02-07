# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Policy::AttendanceProximity' do
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

  describe 'MAX_DISTANCE_KM' do
    it 'is approximately 55 meters' do
      _(Tyto::Policy::AttendanceProximity::MAX_DISTANCE_KM).must_equal 0.055
    end
  end

  describe '.satisfied?' do
    it 'returns true when attendance is at the event location' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: -74.0060, latitude: 40.7128)

      _(Tyto::Policy::AttendanceProximity.satisfied?(attendance, location)).must_equal true
    end

    it 'returns true when attendance is within 55m of event location' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      # ~30m away
      location = build_location(longitude: -74.0057, latitude: 40.7128)

      _(Tyto::Policy::AttendanceProximity.satisfied?(attendance, location)).must_equal true
    end

    it 'returns false when attendance is beyond 55m of event location' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      # ~32km away
      location = build_location(longitude: -74.0, latitude: 41.0)

      _(Tyto::Policy::AttendanceProximity.satisfied?(attendance, location)).must_equal false
    end

    it 'returns true when event location is nil' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)

      _(Tyto::Policy::AttendanceProximity.satisfied?(attendance, nil)).must_equal true
    end

    it 'returns true when event location has no coordinates' do
      attendance = build_attendance(longitude: -74.0060, latitude: 40.7128)
      location = build_location(longitude: nil, latitude: nil)

      _(Tyto::Policy::AttendanceProximity.satisfied?(attendance, location)).must_equal true
    end

    it 'returns false when attendance has no coordinates but event location does' do
      attendance = build_attendance(longitude: nil, latitude: nil)
      location = build_location(longitude: -74.0060, latitude: 40.7128)

      _(Tyto::Policy::AttendanceProximity.satisfied?(attendance, location)).must_equal false
    end
  end
end
