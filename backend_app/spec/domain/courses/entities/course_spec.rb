# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Todo::Entity::Course' do
  let(:now) { Time.now }
  let(:one_hour) { 3600 }
  let(:one_day) { 24 * 60 * 60 }

  let(:valid_attributes) do
    {
      id: 1,
      name: 'Ruby Programming',
      logo: 'ruby.png',
      start_at: now,
      end_at: now + 30 * one_day,
      created_at: now - one_day,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid course' do
      course = Todo::Entity::Course.new(valid_attributes)

      _(course.id).must_equal 1
      _(course.name).must_equal 'Ruby Programming'
      _(course.logo).must_equal 'ruby.png'
    end

    it 'creates a course with minimal attributes' do
      course = Todo::Entity::Course.new(
        id: nil,
        name: 'Minimal Course',
        logo: nil,
        start_at: nil,
        end_at: nil,
        created_at: nil,
        updated_at: nil
      )

      _(course.name).must_equal 'Minimal Course'
      _(course.id).must_be_nil
    end

    it 'rejects empty course name' do
      _ { Todo::Entity::Course.new(valid_attributes.merge(name: '')) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects course name over 200 characters' do
      _ { Todo::Entity::Course.new(valid_attributes.merge(name: 'A' * 201)) }
        .must_raise Dry::Struct::Error
    end
  end

  describe 'immutability and constraint enforcement' do
    it 'enforces name constraint on updates via new()' do
      course = Todo::Entity::Course.new(valid_attributes)

      # Valid update
      updated = course.new(name: 'Advanced Ruby')
      _(updated.name).must_equal 'Advanced Ruby'
      _(updated.id).must_equal course.id # Other attributes preserved

      # Invalid update - empty name (dry-struct wraps constraint errors)
      _ { course.new(name: '') }.must_raise Dry::Struct::Error
    end

    it 'preserves other attributes on partial update' do
      course = Todo::Entity::Course.new(valid_attributes)
      updated = course.new(logo: 'new_logo.png')

      _(updated.logo).must_equal 'new_logo.png'
      _(updated.name).must_equal course.name
      _(updated.id).must_equal course.id
      _(updated.start_at).must_equal course.start_at
    end
  end

  describe '#time_range' do
    it 'returns TimeRange when start and end times exist' do
      course = Todo::Entity::Course.new(valid_attributes)

      _(course.time_range).must_be_instance_of Todo::Value::TimeRange
      _(course.time_range.start_at).must_equal course.start_at
      _(course.time_range.end_at).must_equal course.end_at
      _(course.time_range.present?).must_equal true
    end

    it 'returns NullTimeRange when start_at is missing' do
      course = Todo::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.time_range).must_be_instance_of Todo::Value::NullTimeRange
      _(course.time_range.null?).must_equal true
    end

    it 'returns NullTimeRange when end_at is missing' do
      course = Todo::Entity::Course.new(valid_attributes.merge(end_at: nil))

      _(course.time_range).must_be_instance_of Todo::Value::NullTimeRange
      _(course.time_range.null?).must_equal true
    end
  end

  describe '#duration' do
    it 'returns duration in seconds' do
      course = Todo::Entity::Course.new(valid_attributes)

      _(course.duration).must_equal 30 * one_day
    end

    it 'returns 0 when dates are missing (via NullTimeRange)' do
      course = Todo::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.duration).must_equal 0
    end
  end

  describe '#active?' do
    it 'returns true for currently running course' do
      course = Todo::Entity::Course.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(course.active?).must_equal true
    end

    it 'returns false for future course' do
      course = Todo::Entity::Course.new(
        valid_attributes.merge(
          start_at: now + one_hour,
          end_at: now + 2 * one_hour
        )
      )

      _(course.active?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      course = Todo::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.active?).must_equal false
    end
  end

  describe '#upcoming?' do
    it 'returns true for future course' do
      course = Todo::Entity::Course.new(
        valid_attributes.merge(
          start_at: now + one_hour,
          end_at: now + 2 * one_hour
        )
      )

      _(course.upcoming?).must_equal true
    end

    it 'returns false for current course' do
      course = Todo::Entity::Course.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(course.upcoming?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      course = Todo::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.upcoming?).must_equal false
    end
  end

  describe '#ended?' do
    it 'returns true for past course' do
      course = Todo::Entity::Course.new(
        valid_attributes.merge(
          start_at: now - 2 * one_hour,
          end_at: now - one_hour
        )
      )

      _(course.ended?).must_equal true
    end

    it 'returns false for current course' do
      course = Todo::Entity::Course.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(course.ended?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      course = Todo::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.ended?).must_equal false
    end
  end

  describe '#new_record?' do
    it 'returns true when id is nil' do
      course = Todo::Entity::Course.new(valid_attributes.merge(id: nil))

      _(course.new_record?).must_equal true
    end

    it 'returns false when id exists' do
      course = Todo::Entity::Course.new(valid_attributes)

      _(course.new_record?).must_equal false
    end
  end

  describe '#to_persistence_hash' do
    it 'includes id for existing records' do
      course = Todo::Entity::Course.new(valid_attributes)
      hash = course.to_persistence_hash

      _(hash[:id]).must_equal 1
      _(hash[:name]).must_equal 'Ruby Programming'
      _(hash[:logo]).must_equal 'ruby.png'
    end

    it 'excludes id for new records' do
      course = Todo::Entity::Course.new(valid_attributes.merge(id: nil))
      hash = course.to_persistence_hash

      _(hash.key?(:id)).must_equal false
      _(hash[:name]).must_equal 'Ruby Programming'
    end

    it 'excludes timestamps' do
      course = Todo::Entity::Course.new(valid_attributes)
      hash = course.to_persistence_hash

      _(hash.key?(:created_at)).must_equal false
      _(hash.key?(:updated_at)).must_equal false
    end
  end
end
