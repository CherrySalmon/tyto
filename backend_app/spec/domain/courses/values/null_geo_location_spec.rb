# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Value::NullGeoLocation' do
  let(:null_geo) { Tyto::Value::NullGeoLocation.new }
  let(:real_geo) { Tyto::Value::GeoLocation.new(longitude: 121.5654, latitude: 25.0330) }

  describe 'attributes' do
    it 'returns nil for longitude' do
      _(null_geo.longitude).must_be_nil
    end

    it 'returns nil for latitude' do
      _(null_geo.latitude).must_be_nil
    end
  end

  describe '#distance_to' do
    it 'returns infinity for distance to any location' do
      _(null_geo.distance_to(real_geo)).must_equal Float::INFINITY
    end

    it 'returns infinity for distance to another null location' do
      _(null_geo.distance_to(Tyto::Value::NullGeoLocation.new)).must_equal Float::INFINITY
    end
  end

  describe 'null object interface' do
    it 'returns true for null?' do
      _(null_geo.null?).must_equal true
    end

    it 'returns false for present?' do
      _(null_geo.present?).must_equal false
    end
  end

  describe 'equality' do
    it 'is equal to another NullGeoLocation' do
      _(null_geo).must_equal Tyto::Value::NullGeoLocation.new
    end

    it 'has same hash as another NullGeoLocation' do
      _(null_geo.hash).must_equal Tyto::Value::NullGeoLocation.new.hash
    end
  end
end
