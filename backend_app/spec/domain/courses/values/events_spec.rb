# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Domain::Courses::Values::Events do
  let(:now) { Time.now }
  let(:one_hour) { 3600 }

  let(:event1) do
    Tyto::Domain::Courses::Entities::Event.new(
      id: 1, course_id: 1, location_id: 1, name: 'Lecture 1',
      start_at: now, end_at: now + one_hour,
      created_at: now, updated_at: now
    )
  end

  let(:event2) do
    Tyto::Domain::Courses::Entities::Event.new(
      id: 2, course_id: 1, location_id: 2, name: 'Lecture 2',
      start_at: now + one_hour, end_at: now + 2 * one_hour,
      created_at: now, updated_at: now
    )
  end

  let(:event3) do
    Tyto::Domain::Courses::Entities::Event.new(
      id: 3, course_id: 1, location_id: 1, name: 'Lab Session',
      start_at: now + 2 * one_hour, end_at: now + 3 * one_hour,
      created_at: now, updated_at: now
    )
  end

  describe '.from' do
    it 'creates collection from array of events' do
      collection = Tyto::Domain::Courses::Values::Events.from([event1, event2])

      _(collection.count).must_equal 2
    end

    it 'handles empty array' do
      collection = Tyto::Domain::Courses::Values::Events.from([])

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end

    it 'handles nil as empty collection' do
      collection = Tyto::Domain::Courses::Values::Events.from(nil)

      _(collection.count).must_equal 0
      _(collection.empty?).must_equal true
    end
  end

  describe '#find' do
    let(:collection) { Tyto::Domain::Courses::Values::Events.from([event1, event2, event3]) }

    it 'finds event by ID' do
      found = collection.find(2)

      _(found.name).must_equal 'Lecture 2'
    end

    it 'returns nil when event not found' do
      _(collection.find(999)).must_be_nil
    end
  end

  describe '#count' do
    it 'returns number of events' do
      collection = Tyto::Domain::Courses::Values::Events.from([event1, event2])

      _(collection.count).must_equal 2
    end

    it 'returns 0 for empty collection' do
      collection = Tyto::Domain::Courses::Values::Events.from([])

      _(collection.count).must_equal 0
    end
  end

  describe '#to_a' do
    it 'returns array of events' do
      collection = Tyto::Domain::Courses::Values::Events.from([event1, event2])

      arr = collection.to_a
      _(arr).must_be_kind_of Array
      _(arr.length).must_equal 2
      _(arr.first.name).must_equal 'Lecture 1'
    end
  end

  describe 'iteration' do
    it 'supports each' do
      collection = Tyto::Domain::Courses::Values::Events.from([event1, event2])
      names = []
      collection.each { |e| names << e.name }

      _(names).must_equal ['Lecture 1', 'Lecture 2']
    end

    it 'supports map via Enumerable' do
      collection = Tyto::Domain::Courses::Values::Events.from([event1, event2])

      names = collection.map(&:name)
      _(names).must_equal ['Lecture 1', 'Lecture 2']
    end
  end

  describe '#any?' do
    it 'returns true when collection has events' do
      collection = Tyto::Domain::Courses::Values::Events.from([event1])

      _(collection.any?).must_equal true
    end

    it 'returns false when collection is empty' do
      collection = Tyto::Domain::Courses::Values::Events.from([])

      _(collection.any?).must_equal false
    end
  end

  describe '#empty?' do
    it 'returns true when collection is empty' do
      collection = Tyto::Domain::Courses::Values::Events.from([])

      _(collection.empty?).must_equal true
    end

    it 'returns false when collection has events' do
      collection = Tyto::Domain::Courses::Values::Events.from([event1])

      _(collection.empty?).must_equal false
    end
  end

  describe 'type safety' do
    it 'rejects non-Event objects' do
      _ { Tyto::Domain::Courses::Values::Events.from(['not an event']) }
        .must_raise Dry::Struct::Error
    end
  end
end
