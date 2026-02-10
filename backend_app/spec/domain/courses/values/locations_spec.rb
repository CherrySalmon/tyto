# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Courses::Values::Locations do
  let(:now) { Time.now }

  let(:location1) do
    Tyto::Entity::Location.new(
      id: 1, course_id: 1, name: 'Room A',
      longitude: 121.5654, latitude: 25.0330,
      created_at: now, updated_at: now
    )
  end

  let(:location2) do
    Tyto::Entity::Location.new(
      id: 2, course_id: 1, name: 'Room B',
      longitude: 121.5700, latitude: 25.0400,
      created_at: now, updated_at: now
    )
  end

  describe '.from' do
    it 'creates collection from array of locations' do
      collection = Tyto::Domain::Courses::Values::Locations.from([location1, location2])

      _(collection.count).must_equal 2
    end

    it 'handles empty array' do
      collection = Tyto::Domain::Courses::Values::Locations.from([])

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end

    it 'handles nil as empty collection' do
      collection = Tyto::Domain::Courses::Values::Locations.from(nil)

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end
  end

  describe '#find' do
    let(:collection) { Tyto::Domain::Courses::Values::Locations.from([location1, location2]) }

    it 'finds location by ID' do
      found = collection.find(2)

      _(found.name).must_equal 'Room B'
    end

    it 'returns nil when location not found' do
      _(collection.find(999)).must_be_nil
    end
  end

  describe '#count' do
    it 'returns number of locations' do
      collection = Tyto::Domain::Courses::Values::Locations.from([location1, location2])

      _(collection.count).must_equal 2
    end

    it 'returns 0 for empty collection' do
      collection = Tyto::Domain::Courses::Values::Locations.from([])

      _(collection.count).must_equal 0
    end
  end

  describe '#to_a' do
    it 'returns array of locations' do
      collection = Tyto::Domain::Courses::Values::Locations.from([location1, location2])

      arr = collection.to_a
      _(arr).must_be_kind_of Array
      _(arr.length).must_equal 2
      _(arr.first.name).must_equal 'Room A'
    end
  end

  describe 'iteration' do
    it 'supports each' do
      collection = Tyto::Domain::Courses::Values::Locations.from([location1, location2])
      names = []
      collection.each { |l| names << l.name }

      _(names).must_equal ['Room A', 'Room B']
    end

    it 'supports map via Enumerable' do
      collection = Tyto::Domain::Courses::Values::Locations.from([location1, location2])

      names = collection.map(&:name)
      _(names).must_equal ['Room A', 'Room B']
    end
  end

  describe '#any?' do
    it 'returns true when collection has locations' do
      collection = Tyto::Domain::Courses::Values::Locations.from([location1])

      _(collection.any?).must_equal true
    end

    it 'returns false when collection is empty' do
      collection = Tyto::Domain::Courses::Values::Locations.from([])

      _(collection.any?).must_equal false
    end
  end

  describe '#empty?' do
    it 'returns true when collection is empty' do
      collection = Tyto::Domain::Courses::Values::Locations.from([])

      _(collection.empty?).must_equal true
    end

    it 'returns false when collection has locations' do
      collection = Tyto::Domain::Courses::Values::Locations.from([location1])

      _(collection.empty?).must_equal false
    end
  end

  describe 'type safety' do
    it 'rejects non-Location objects' do
      _ { Tyto::Domain::Courses::Values::Locations.from(['not a location']) }
        .must_raise Dry::Struct::Error
    end
  end
end
