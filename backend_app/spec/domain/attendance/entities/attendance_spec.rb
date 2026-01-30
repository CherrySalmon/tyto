# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Todo::Entity::Attendance' do
  let(:now) { Time.now }

  let(:valid_attributes) do
    {
      id: 1,
      account_id: 10,
      course_id: 20,
      event_id: 30,
      role_id: 5,
      name: 'Lecture 1 Attendance',
      longitude: 121.5654,
      latitude: 25.0330,
      created_at: now,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid attendance' do
      attendance = Todo::Entity::Attendance.new(valid_attributes)

      _(attendance.id).must_equal 1
      _(attendance.account_id).must_equal 10
      _(attendance.course_id).must_equal 20
      _(attendance.event_id).must_equal 30
      _(attendance.name).must_equal 'Lecture 1 Attendance'
    end

    it 'creates attendance without coordinates' do
      attendance = Todo::Entity::Attendance.new(
        valid_attributes.merge(longitude: nil, latitude: nil)
      )

      _(attendance.longitude).must_be_nil
      _(attendance.latitude).must_be_nil
    end

    it 'creates attendance with minimal attributes' do
      attendance = Todo::Entity::Attendance.new(
        id: nil,
        account_id: 10,
        course_id: 20,
        event_id: nil,
        role_id: nil,
        name: nil,
        longitude: nil,
        latitude: nil,
        created_at: nil,
        updated_at: nil
      )

      _(attendance.account_id).must_equal 10
      _(attendance.course_id).must_equal 20
    end

    it 'requires account_id' do
      _ { Todo::Entity::Attendance.new(valid_attributes.merge(account_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires course_id' do
      _ { Todo::Entity::Attendance.new(valid_attributes.merge(course_id: nil)) }
        .must_raise Dry::Struct::Error
    end
  end

  describe '#check_in_location' do
    it 'returns GeoLocation when coordinates exist' do
      attendance = Todo::Entity::Attendance.new(valid_attributes)

      _(attendance.check_in_location).must_be_instance_of Todo::Value::GeoLocation
      _(attendance.check_in_location.longitude).must_equal 121.5654
      _(attendance.check_in_location.latitude).must_equal 25.0330
    end

    it 'returns NullGeoLocation when coordinates missing' do
      attendance = Todo::Entity::Attendance.new(
        valid_attributes.merge(longitude: nil, latitude: nil)
      )

      _(attendance.check_in_location).must_be_instance_of Todo::Value::NullGeoLocation
      _(attendance.check_in_location.null?).must_equal true
    end
  end

  describe '#has_coordinates?' do
    it 'returns true when coordinates exist' do
      attendance = Todo::Entity::Attendance.new(valid_attributes)

      _(attendance.has_coordinates?).must_equal true
    end

    it 'returns false when coordinates missing' do
      attendance = Todo::Entity::Attendance.new(
        valid_attributes.merge(longitude: nil)
      )

      _(attendance.has_coordinates?).must_equal false
    end
  end

  describe '#distance_to_event' do
    let(:taipei_attendance) do
      Todo::Entity::Attendance.new(
        valid_attributes.merge(longitude: 121.5654, latitude: 25.0330)
      )
    end

    let(:tokyo_location) do
      Todo::Entity::Location.new(
        id: 1, course_id: 20, name: 'Tokyo Venue',
        longitude: 139.6917, latitude: 35.6895,
        created_at: now, updated_at: now
      )
    end

    let(:nearby_location) do
      Todo::Entity::Location.new(
        id: 2, course_id: 20, name: 'Taipei Venue',
        longitude: 121.5660, latitude: 25.0335, # ~100m away
        created_at: now, updated_at: now
      )
    end

    it 'calculates distance to event location' do
      distance = taipei_attendance.distance_to_event(tokyo_location)

      # Taipei to Tokyo is approximately 2100 km
      _(distance).must_be :>, 2000
      _(distance).must_be :<, 2200
    end

    it 'returns small distance for nearby location' do
      distance = taipei_attendance.distance_to_event(nearby_location)

      # Should be less than 1 km
      _(distance).must_be :<, 1.0
    end

    it 'returns infinity when attendance has no coordinates' do
      no_coords = Todo::Entity::Attendance.new(
        valid_attributes.merge(longitude: nil, latitude: nil)
      )

      _(no_coords.distance_to_event(tokyo_location)).must_equal Float::INFINITY
    end
  end

  describe '#within_range?' do
    let(:attendance) do
      Todo::Entity::Attendance.new(
        valid_attributes.merge(longitude: 121.5654, latitude: 25.0330)
      )
    end

    let(:nearby_location) do
      Todo::Entity::Location.new(
        id: 1, course_id: 20, name: 'Nearby',
        longitude: 121.5660, latitude: 25.0335, # ~100m away
        created_at: now, updated_at: now
      )
    end

    let(:far_location) do
      Todo::Entity::Location.new(
        id: 2, course_id: 20, name: 'Far Away',
        longitude: 139.6917, latitude: 35.6895, # Tokyo
        created_at: now, updated_at: now
      )
    end

    it 'returns true when within default range (0.5 km)' do
      _(attendance.within_range?(nearby_location)).must_equal true
    end

    it 'returns false when outside default range' do
      _(attendance.within_range?(far_location)).must_equal false
    end

    it 'respects custom max_distance_km' do
      # ~100m away, so 0.05 km should fail, 0.2 km should pass
      _(attendance.within_range?(nearby_location, max_distance_km: 0.05)).must_equal false
      _(attendance.within_range?(nearby_location, max_distance_km: 0.2)).must_equal true
    end

    it 'returns false when attendance has no coordinates' do
      no_coords = Todo::Entity::Attendance.new(
        valid_attributes.merge(longitude: nil, latitude: nil)
      )

      _(no_coords.within_range?(nearby_location)).must_equal false
    end
  end
end
