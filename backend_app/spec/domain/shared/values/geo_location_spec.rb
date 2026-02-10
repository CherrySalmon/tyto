# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Value::GeoLocation' do
  # Reference coordinates for testing
  let(:taipei) { Tyto::Value::GeoLocation.new(longitude: 121.5654, latitude: 25.0330) }
  let(:tokyo) { Tyto::Value::GeoLocation.new(longitude: 139.6917, latitude: 35.6895) }
  let(:new_york) { Tyto::Value::GeoLocation.new(longitude: -74.0060, latitude: 40.7128) }

  describe 'creation' do
    it 'creates a valid geo location' do
      geo = Tyto::Value::GeoLocation.new(longitude: 121.5654, latitude: 25.0330)

      _(geo.longitude).must_equal 121.5654
      _(geo.latitude).must_equal 25.0330
    end

    it 'accepts longitude at boundaries' do
      west = Tyto::Value::GeoLocation.new(longitude: -180.0, latitude: 0.0)
      east = Tyto::Value::GeoLocation.new(longitude: 180.0, latitude: 0.0)

      _(west.longitude).must_equal(-180.0)
      _(east.longitude).must_equal 180.0
    end

    it 'accepts latitude at boundaries' do
      south = Tyto::Value::GeoLocation.new(longitude: 0.0, latitude: -90.0)
      north = Tyto::Value::GeoLocation.new(longitude: 0.0, latitude: 90.0)

      _(south.latitude).must_equal(-90.0)
      _(north.latitude).must_equal 90.0
    end

    it 'rejects longitude below -180' do
      _ { Tyto::Value::GeoLocation.new(longitude: -180.1, latitude: 0.0) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects longitude above 180' do
      _ { Tyto::Value::GeoLocation.new(longitude: 180.1, latitude: 0.0) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects latitude below -90' do
      _ { Tyto::Value::GeoLocation.new(longitude: 0.0, latitude: -90.1) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects latitude above 90' do
      _ { Tyto::Value::GeoLocation.new(longitude: 0.0, latitude: 90.1) }
        .must_raise Dry::Struct::Error
    end
  end

  describe 'immutability' do
    it 'allows valid updates via new()' do
      geo = Tyto::Value::GeoLocation.new(longitude: 121.5654, latitude: 25.0330)
      updated = geo.new(longitude: 139.6917)

      _(updated.longitude).must_equal 139.6917
      _(updated.latitude).must_equal 25.0330 # Preserved
    end

    it 'creates immutable copies' do
      geo = Tyto::Value::GeoLocation.new(longitude: 121.5654, latitude: 25.0330)
      updated = geo.new(longitude: 139.6917)

      _(geo.longitude).must_equal 121.5654 # Original unchanged
    end
  end

  describe '#distance_to' do
    it 'returns 0 for same location' do
      _(taipei.distance_to(taipei)).must_equal 0.0
    end

    it 'calculates distance between Taipei and Tokyo (approximately 2100 km)' do
      distance = taipei.distance_to(tokyo)

      # Haversine formula result should be around 2100 km
      _(distance).must_be :>, 2000
      _(distance).must_be :<, 2200
    end

    it 'calculates distance between Tokyo and New York (approximately 10800 km)' do
      distance = tokyo.distance_to(new_york)

      # Haversine formula result should be around 10800 km
      _(distance).must_be :>, 10500
      _(distance).must_be :<, 11000
    end

    it 'is symmetric' do
      _(taipei.distance_to(tokyo)).must_be_close_to tokyo.distance_to(taipei), 0.001
    end

    it 'returns infinity when other is NullGeoLocation' do
      null_geo = Tyto::Value::NullGeoLocation.new

      _(taipei.distance_to(null_geo)).must_equal Float::INFINITY
    end
  end

  describe 'null object interface' do
    it 'returns false for null?' do
      _(taipei.null?).must_equal false
    end

    it 'returns true for present?' do
      _(taipei.present?).must_equal true
    end
  end

  describe '.build factory method' do
    it 'creates a valid geo location from numeric values' do
      geo = Tyto::Value::GeoLocation.build(longitude: 121.5654, latitude: 25.0330)

      _(geo.longitude).must_equal 121.5654
      _(geo.latitude).must_equal 25.0330
    end

    it 'converts string values to floats' do
      geo = Tyto::Value::GeoLocation.build(longitude: '121.5654', latitude: '25.0330')

      _(geo.longitude).must_equal 121.5654
      _(geo.latitude).must_equal 25.0330
    end

    it 'raises InvalidCoordinatesError for longitude below -180' do
      error = _ { Tyto::Value::GeoLocation.build(longitude: -181.0, latitude: 0.0) }
              .must_raise Tyto::Value::GeoLocation::InvalidCoordinatesError

      _(error.message).must_equal 'Longitude must be between -180 and 180'
    end

    it 'raises InvalidCoordinatesError for longitude above 180' do
      error = _ { Tyto::Value::GeoLocation.build(longitude: 181.0, latitude: 0.0) }
              .must_raise Tyto::Value::GeoLocation::InvalidCoordinatesError

      _(error.message).must_equal 'Longitude must be between -180 and 180'
    end

    it 'raises InvalidCoordinatesError for latitude below -90' do
      error = _ { Tyto::Value::GeoLocation.build(longitude: 0.0, latitude: -91.0) }
              .must_raise Tyto::Value::GeoLocation::InvalidCoordinatesError

      _(error.message).must_equal 'Latitude must be between -90 and 90'
    end

    it 'raises InvalidCoordinatesError for latitude above 90' do
      error = _ { Tyto::Value::GeoLocation.build(longitude: 0.0, latitude: 91.0) }
              .must_raise Tyto::Value::GeoLocation::InvalidCoordinatesError

      _(error.message).must_equal 'Latitude must be between -90 and 90'
    end

    it 'accepts boundary values' do
      geo = Tyto::Value::GeoLocation.build(longitude: -180.0, latitude: -90.0)

      _(geo.longitude).must_equal(-180.0)
      _(geo.latitude).must_equal(-90.0)
    end
  end
end
