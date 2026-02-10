# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Domain::Courses::Entities::Event' do
  let(:now) { Time.now }
  let(:one_hour) { 3600 }
  let(:one_day) { 24 * 60 * 60 }

  let(:valid_attributes) do
    {
      id: 1,
      course_id: 10,
      location_id: 5,
      name: 'Lecture 1: Introduction',
      start_at: now,
      end_at: now + 2 * one_hour,
      created_at: now - one_day,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid event' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes)

      _(event.id).must_equal 1
      _(event.course_id).must_equal 10
      _(event.location_id).must_equal 5
      _(event.name).must_equal 'Lecture 1: Introduction'
    end

    it 'creates an event with minimal attributes' do
      event = Tyto::Domain::Courses::Entities::Event.new(
        id: nil,
        course_id: 10,
        location_id: 5,
        name: 'Minimal Event',
        start_at: nil,
        end_at: nil,
        created_at: nil,
        updated_at: nil
      )

      _(event.name).must_equal 'Minimal Event'
      _(event.id).must_be_nil
    end

    it 'rejects empty event name' do
      _ { Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(name: '')) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects event name over 200 characters' do
      _ { Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(name: 'A' * 201)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires course_id' do
      _ { Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(course_id: nil)) }
        .must_raise Dry::Struct::Error
    end

    it 'requires location_id' do
      _ { Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(location_id: nil)) }
        .must_raise Dry::Struct::Error
    end
  end

  describe 'immutability and constraint enforcement' do
    it 'enforces name constraint on updates via new()' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes)

      # Valid update
      updated = event.new(name: 'Lecture 2: Advanced Topics')
      _(updated.name).must_equal 'Lecture 2: Advanced Topics'
      _(updated.id).must_equal event.id # Other attributes preserved

      # Invalid update - empty name
      _ { event.new(name: '') }.must_raise Dry::Struct::Error
    end

    it 'preserves other attributes on partial update' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes)
      updated = event.new(location_id: 99)

      _(updated.location_id).must_equal 99
      _(updated.name).must_equal event.name
      _(updated.id).must_equal event.id
      _(updated.course_id).must_equal event.course_id
    end
  end

  describe '#time_range' do
    it 'returns TimeRange when start and end times exist' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes)

      _(event.time_range).must_be_instance_of Tyto::Value::TimeRange
      _(event.time_range.start_at).must_equal event.start_at
      _(event.time_range.end_at).must_equal event.end_at
      _(event.time_range.present?).must_equal true
    end

    it 'returns NullTimeRange when start_at is missing' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(start_at: nil))

      _(event.time_range).must_be_instance_of Tyto::Value::NullTimeRange
      _(event.time_range.null?).must_equal true
    end

    it 'returns NullTimeRange when end_at is missing' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(end_at: nil))

      _(event.time_range).must_be_instance_of Tyto::Value::NullTimeRange
      _(event.time_range.null?).must_equal true
    end
  end

  describe '#duration' do
    it 'returns duration in seconds' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes)

      _(event.duration).must_equal 2 * one_hour
    end

    it 'returns 0 when dates are missing (via NullTimeRange)' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(start_at: nil))

      _(event.duration).must_equal 0
    end
  end

  describe '#active?' do
    it 'returns true for currently running event' do
      event = Tyto::Domain::Courses::Entities::Event.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(event.active?).must_equal true
    end

    it 'returns false for future event' do
      event = Tyto::Domain::Courses::Entities::Event.new(
        valid_attributes.merge(
          start_at: now + one_hour,
          end_at: now + 2 * one_hour
        )
      )

      _(event.active?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(start_at: nil))

      _(event.active?).must_equal false
    end
  end

  describe '#upcoming?' do
    it 'returns true for future event' do
      event = Tyto::Domain::Courses::Entities::Event.new(
        valid_attributes.merge(
          start_at: now + one_hour,
          end_at: now + 2 * one_hour
        )
      )

      _(event.upcoming?).must_equal true
    end

    it 'returns false for current event' do
      event = Tyto::Domain::Courses::Entities::Event.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(event.upcoming?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(start_at: nil))

      _(event.upcoming?).must_equal false
    end
  end

  describe '#ended?' do
    it 'returns true for past event' do
      event = Tyto::Domain::Courses::Entities::Event.new(
        valid_attributes.merge(
          start_at: now - 2 * one_hour,
          end_at: now - one_hour
        )
      )

      _(event.ended?).must_equal true
    end

    it 'returns false for current event' do
      event = Tyto::Domain::Courses::Entities::Event.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(event.ended?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      event = Tyto::Domain::Courses::Entities::Event.new(valid_attributes.merge(start_at: nil))

      _(event.ended?).must_equal false
    end
  end
end
