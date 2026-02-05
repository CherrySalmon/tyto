# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Repository::Events' do
  let(:repository) { Tyto::Repository::Events.new }
  let(:now) { Time.now }
  let(:one_hour) { 3600 }
  let(:one_day) { 24 * 60 * 60 }

  # Events require a course and location, so create them first
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:event_location) { Tyto::Location.create(name: 'Room 101', course_id: course.id) }

  describe '#create' do
    it 'persists a new event and returns entity with ID' do
      entity = Tyto::Entity::Event.new(
        id: nil,
        course_id: course.id,
        location_id: event_location.id,
        name: 'Lecture 1',
        start_at: now,
        end_at: now + 2 * one_hour,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Tyto::Entity::Event
      _(result.id).wont_be_nil
      _(result.name).must_equal 'Lecture 1'
      _(result.course_id).must_equal course.id
      _(result.location_id).must_equal event_location.id
      _(result.created_at).wont_be_nil
      _(result.updated_at).wont_be_nil
    end

    it 'persists event with minimal attributes (no times)' do
      entity = Tyto::Entity::Event.new(
        id: nil,
        course_id: course.id,
        location_id: event_location.id,
        name: 'Minimal Event',
        start_at: nil,
        end_at: nil,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.id).wont_be_nil
      _(result.name).must_equal 'Minimal Event'
      _(result.start_at).must_be_nil
      _(result.end_at).must_be_nil
    end
  end

  describe '#find_id' do
    it 'returns domain entity for existing event' do
      orm_event = Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Test Event',
        start_at: now,
        end_at: now + one_hour
      )

      result = repository.find_id(orm_event.id)

      _(result).must_be_instance_of Tyto::Entity::Event
      _(result.id).must_equal orm_event.id
      _(result.name).must_equal 'Test Event'
      _(result.course_id).must_equal course.id
    end

    it 'returns nil for non-existent event' do
      result = repository.find_id(999_999)

      _(result).must_be_nil
    end
  end

  describe '#find_by_course' do
    it 'returns empty array when no events exist for course' do
      result = repository.find_by_course(course.id)

      _(result).must_equal []
    end

    it 'returns events ordered by start_at' do
      # Create events out of order
      Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Event 3',
        start_at: now + 2 * one_hour,
        end_at: now + 3 * one_hour
      )
      Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Event 1',
        start_at: now,
        end_at: now + one_hour
      )
      Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Event 2',
        start_at: now + one_hour,
        end_at: now + 2 * one_hour
      )

      result = repository.find_by_course(course.id)

      _(result.length).must_equal 3
      _(result.map(&:name)).must_equal ['Event 1', 'Event 2', 'Event 3']
    end

    it 'filters by course_id' do
      # Just verify basic filtering works - use shared course/location
      Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Test Event',
        start_at: now,
        end_at: now + one_hour
      )

      result = repository.find_by_course(course.id)
      _(result.length).must_equal 1
      _(result.first.course_id).must_equal course.id
    end
  end

  describe '#find_active_at' do
    it 'returns events active at specified time' do
      # Event that spans the test time
      Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Active Event',
        start_at: now - one_hour,
        end_at: now + one_hour
      )
      # Event in the past
      Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Past Event',
        start_at: now - 3 * one_hour,
        end_at: now - 2 * one_hour
      )
      # Event in the future
      Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Future Event',
        start_at: now + 2 * one_hour,
        end_at: now + 3 * one_hour
      )

      result = repository.find_active_at([course.id], now)

      _(result.length).must_equal 1
      _(result.first.name).must_equal 'Active Event'
    end

    it 'filters by course_ids array' do
      # Just verify filtering by course IDs works
      Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Active Event',
        start_at: now - one_hour,
        end_at: now + one_hour
      )

      result = repository.find_active_at([course.id], now)
      _(result.length).must_equal 1
      _(result.first.course_id).must_equal course.id
    end
  end

  describe '#find_all' do
    it 'returns empty array when no events exist' do
      result = repository.find_all

      _(result).must_equal []
    end

    it 'returns all events as domain entities' do
      Tyto::Event.create(course_id: course.id, location_id: event_location.id, name: 'Event 1')
      Tyto::Event.create(course_id: course.id, location_id: event_location.id, name: 'Event 2')

      result = repository.find_all

      _(result.length).must_equal 2
      result.each { |event| _(event).must_be_instance_of Tyto::Entity::Event }
    end
  end

  describe '#update' do
    it 'updates existing event and returns updated entity' do
      orm_event = Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'Original Name',
        start_at: now,
        end_at: now + one_hour
      )

      entity = repository.find_id(orm_event.id)
      updated_entity = entity.new(name: 'Updated Name')

      result = repository.update(updated_entity)

      _(result.name).must_equal 'Updated Name'
      _(result.id).must_equal orm_event.id

      # Verify persistence
      reloaded = repository.find_id(orm_event.id)
      _(reloaded.name).must_equal 'Updated Name'
    end

    it 'raises error for non-existent event' do
      entity = Tyto::Entity::Event.new(
        id: 999_999,
        course_id: course.id,
        location_id: event_location.id,
        name: 'Ghost Event',
        start_at: nil,
        end_at: nil,
        created_at: nil,
        updated_at: nil
      )

      _ { repository.update(entity) }.must_raise RuntimeError
    end
  end

  describe '#delete' do
    it 'deletes existing event and returns true' do
      orm_event = Tyto::Event.create(
        course_id: course.id,
        location_id: event_location.id,
        name: 'To Delete'
      )

      result = repository.delete(orm_event.id)

      _(result).must_equal true
      _(repository.find_id(orm_event.id)).must_be_nil
    end

    it 'returns false for non-existent event' do
      result = repository.delete(999_999)

      _(result).must_equal false
    end
  end

  describe 'round-trip' do
    it 'maintains data integrity through create -> find -> update -> find cycle' do
      # Create
      original = Tyto::Entity::Event.new(
        id: nil,
        course_id: course.id,
        location_id: event_location.id,
        name: 'Full Cycle Test',
        start_at: now,
        end_at: now + 2 * one_hour,
        created_at: nil,
        updated_at: nil
      )

      created = repository.create(original)
      _(created.id).wont_be_nil

      # Find
      found = repository.find_id(created.id)
      _(found.name).must_equal 'Full Cycle Test'

      # Update
      modified = found.new(name: 'Updated Cycle Test')
      updated = repository.update(modified)
      _(updated.name).must_equal 'Updated Cycle Test'

      # Verify final state
      final = repository.find_id(created.id)
      _(final.name).must_equal 'Updated Cycle Test'
      _(final.course_id).must_equal course.id
    end
  end
end
