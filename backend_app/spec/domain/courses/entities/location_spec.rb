# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Domain::Courses::Entities::Location' do
  let(:now) { Time.now }

  let(:valid_attributes) do
    {
      id: 1,
      course_id: 10,
      name: 'Main Lecture Hall',
      longitude: 121.5654,
      latitude: 25.0330,
      created_at: now,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid location' do
      location = Tyto::Domain::Courses::Entities::Location.new(valid_attributes)

      _(location.id).must_equal 1
      _(location.course_id).must_equal 10
      _(location.name).must_equal 'Main Lecture Hall'
      _(location.longitude).must_equal 121.5654
      _(location.latitude).must_equal 25.0330
    end

    it 'creates a location without coordinates' do
      location = Tyto::Domain::Courses::Entities::Location.new(
        valid_attributes.merge(longitude: nil, latitude: nil)
      )

      _(location.name).must_equal 'Main Lecture Hall'
      _(location.longitude).must_be_nil
      _(location.latitude).must_be_nil
    end

    it 'creates a location with minimal attributes' do
      location = Tyto::Domain::Courses::Entities::Location.new(
        id: nil,
        course_id: 10,
        name: 'Minimal Location',
        longitude: nil,
        latitude: nil,
        created_at: nil,
        updated_at: nil
      )

      _(location.name).must_equal 'Minimal Location'
      _(location.id).must_be_nil
    end

    it 'rejects empty location name' do
      _ { Tyto::Domain::Courses::Entities::Location.new(valid_attributes.merge(name: '')) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects location name over 200 characters' do
      _ { Tyto::Domain::Courses::Entities::Location.new(valid_attributes.merge(name: 'A' * 201)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires course_id' do
      _ { Tyto::Domain::Courses::Entities::Location.new(valid_attributes.merge(course_id: nil)) }
        .must_raise Dry::Struct::Error
    end
  end

  describe 'immutability and constraint enforcement' do
    it 'enforces name constraint on updates via new()' do
      location = Tyto::Domain::Courses::Entities::Location.new(valid_attributes)

      # Valid update
      updated = location.new(name: 'Secondary Lab')
      _(updated.name).must_equal 'Secondary Lab'
      _(updated.id).must_equal location.id # Other attributes preserved

      # Invalid update - empty name
      _ { location.new(name: '') }.must_raise Dry::Struct::Error
    end

    it 'preserves other attributes on partial update' do
      location = Tyto::Domain::Courses::Entities::Location.new(valid_attributes)
      updated = location.new(longitude: 139.6917)

      _(updated.longitude).must_equal 139.6917
      _(updated.name).must_equal location.name
      _(updated.id).must_equal location.id
      _(updated.course_id).must_equal location.course_id
    end
  end

  describe '#geo_location' do
    it 'returns GeoLocation when coordinates exist' do
      location = Tyto::Domain::Courses::Entities::Location.new(valid_attributes)

      _(location.geo_location).must_be_instance_of Tyto::Value::GeoLocation
      _(location.geo_location.longitude).must_equal 121.5654
      _(location.geo_location.latitude).must_equal 25.0330
      _(location.geo_location.present?).must_equal true
    end

    it 'returns NullGeoLocation when longitude is missing' do
      location = Tyto::Domain::Courses::Entities::Location.new(valid_attributes.merge(longitude: nil))

      _(location.geo_location).must_be_instance_of Tyto::Value::NullGeoLocation
      _(location.geo_location.null?).must_equal true
    end

    it 'returns NullGeoLocation when latitude is missing' do
      location = Tyto::Domain::Courses::Entities::Location.new(valid_attributes.merge(latitude: nil))

      _(location.geo_location).must_be_instance_of Tyto::Value::NullGeoLocation
      _(location.geo_location.null?).must_equal true
    end
  end

  describe '#has_coordinates?' do
    it 'returns true when coordinates exist' do
      location = Tyto::Domain::Courses::Entities::Location.new(valid_attributes)

      _(location.has_coordinates?).must_equal true
    end

    it 'returns false when coordinates are missing' do
      location = Tyto::Domain::Courses::Entities::Location.new(valid_attributes.merge(longitude: nil))

      _(location.has_coordinates?).must_equal false
    end
  end

  describe '#distance_to' do
    let(:taipei_location) do
      Tyto::Domain::Courses::Entities::Location.new(
        valid_attributes.merge(
          name: 'Taipei Office',
          longitude: 121.5654,
          latitude: 25.0330
        )
      )
    end

    let(:tokyo_location) do
      Tyto::Domain::Courses::Entities::Location.new(
        valid_attributes.merge(
          id: 2,
          name: 'Tokyo Office',
          longitude: 139.6917,
          latitude: 35.6895
        )
      )
    end

    let(:no_coords_location) do
      Tyto::Domain::Courses::Entities::Location.new(
        valid_attributes.merge(
          id: 3,
          name: 'Unknown Location',
          longitude: nil,
          latitude: nil
        )
      )
    end

    it 'calculates distance between two locations with coordinates' do
      distance = taipei_location.distance_to(tokyo_location)

      # Taipei to Tokyo is approximately 2100 km
      _(distance).must_be :>, 2000
      _(distance).must_be :<, 2200
    end

    it 'returns infinity when comparing with location without coordinates' do
      distance = taipei_location.distance_to(no_coords_location)

      _(distance).must_equal Float::INFINITY
    end

    it 'returns infinity when origin has no coordinates' do
      distance = no_coords_location.distance_to(tokyo_location)

      _(distance).must_equal Float::INFINITY
    end
  end
end
