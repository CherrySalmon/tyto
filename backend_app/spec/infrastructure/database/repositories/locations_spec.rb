# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Todo::Repository::Locations' do
  let(:repository) { Todo::Repository::Locations.new }
  let(:now) { Time.now }

  # Locations require a course, so create one first
  let(:course) { Todo::Course.create(name: 'Test Course') }
  let(:another_course) { Todo::Course.create(name: 'Another Course') }

  describe '#create' do
    it 'persists a new location and returns entity with ID' do
      entity = Todo::Entity::Location.new(
        id: nil,
        course_id: course.id,
        name: 'Main Lecture Hall',
        longitude: 121.5654,
        latitude: 25.0330,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Todo::Entity::Location
      _(result.id).wont_be_nil
      _(result.name).must_equal 'Main Lecture Hall'
      _(result.course_id).must_equal course.id
      _(result.longitude).must_equal 121.5654
      _(result.latitude).must_equal 25.0330
      _(result.created_at).wont_be_nil
      _(result.updated_at).wont_be_nil
    end

    it 'persists location without coordinates' do
      entity = Todo::Entity::Location.new(
        id: nil,
        course_id: course.id,
        name: 'Virtual Room',
        longitude: nil,
        latitude: nil,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.id).wont_be_nil
      _(result.name).must_equal 'Virtual Room'
      _(result.longitude).must_be_nil
      _(result.latitude).must_be_nil
    end
  end

  describe '#find_id' do
    it 'returns domain entity for existing location' do
      orm_location = Todo::Location.create(
        course_id: course.id,
        name: 'Test Location',
        longitude: 121.5654,
        latitude: 25.0330
      )

      result = repository.find_id(orm_location.id)

      _(result).must_be_instance_of Todo::Entity::Location
      _(result.id).must_equal orm_location.id
      _(result.name).must_equal 'Test Location'
      _(result.course_id).must_equal course.id
    end

    it 'returns nil for non-existent location' do
      result = repository.find_id(999_999)

      _(result).must_be_nil
    end
  end

  describe '#find_by_course' do
    it 'returns empty array when no locations exist for course' do
      result = repository.find_by_course(course.id)

      _(result).must_equal []
    end

    it 'returns locations ordered by name' do
      # Create locations out of order
      Todo::Location.create(course_id: course.id, name: 'Room C')
      Todo::Location.create(course_id: course.id, name: 'Room A')
      Todo::Location.create(course_id: course.id, name: 'Room B')

      result = repository.find_by_course(course.id)

      _(result.length).must_equal 3
      _(result.map(&:name)).must_equal ['Room A', 'Room B', 'Room C']
    end

    it 'filters by course_id' do
      Todo::Location.create(course_id: course.id, name: 'Course 1 Location')
      Todo::Location.create(course_id: another_course.id, name: 'Course 2 Location')

      result = repository.find_by_course(course.id)

      _(result.length).must_equal 1
      _(result.first.course_id).must_equal course.id
      _(result.first.name).must_equal 'Course 1 Location'
    end
  end

  describe '#find_all' do
    it 'returns empty array when no locations exist' do
      result = repository.find_all

      _(result).must_equal []
    end

    it 'returns all locations as domain entities' do
      Todo::Location.create(course_id: course.id, name: 'Location 1')
      Todo::Location.create(course_id: course.id, name: 'Location 2')

      result = repository.find_all

      _(result.length).must_equal 2
      result.each { |loc| _(loc).must_be_instance_of Todo::Entity::Location }
    end
  end

  describe '#update' do
    it 'updates existing location and returns updated entity' do
      orm_location = Todo::Location.create(
        course_id: course.id,
        name: 'Original Name',
        longitude: 121.5654,
        latitude: 25.0330
      )

      entity = repository.find_id(orm_location.id)
      updated_entity = entity.new(name: 'Updated Name', longitude: 139.6917)

      result = repository.update(updated_entity)

      _(result.name).must_equal 'Updated Name'
      _(result.longitude).must_equal 139.6917
      _(result.id).must_equal orm_location.id

      # Verify persistence
      reloaded = repository.find_id(orm_location.id)
      _(reloaded.name).must_equal 'Updated Name'
      _(reloaded.longitude).must_equal 139.6917
    end

    it 'raises error for non-existent location' do
      entity = Todo::Entity::Location.new(
        id: 999_999,
        course_id: course.id,
        name: 'Ghost Location',
        longitude: nil,
        latitude: nil,
        created_at: nil,
        updated_at: nil
      )

      _ { repository.update(entity) }.must_raise RuntimeError
    end
  end

  describe '#delete' do
    it 'deletes existing location and returns true' do
      orm_location = Todo::Location.create(
        course_id: course.id,
        name: 'To Delete'
      )

      result = repository.delete(orm_location.id)

      _(result).must_equal true
      _(repository.find_id(orm_location.id)).must_be_nil
    end

    it 'returns false for non-existent location' do
      result = repository.delete(999_999)

      _(result).must_equal false
    end
  end

  describe '#has_events?' do
    it 'returns false for location without events' do
      orm_location = Todo::Location.create(
        course_id: course.id,
        name: 'Empty Location'
      )

      _(repository.has_events?(orm_location.id)).must_equal false
    end

    it 'returns true for location with events' do
      orm_location = Todo::Location.create(
        course_id: course.id,
        name: 'Busy Location'
      )
      Todo::Event.create(
        course_id: course.id,
        location_id: orm_location.id,
        name: 'Test Event'
      )

      _(repository.has_events?(orm_location.id)).must_equal true
    end

    it 'returns false for non-existent location' do
      _(repository.has_events?(999_999)).must_equal false
    end
  end

  describe 'round-trip' do
    it 'maintains data integrity through create -> find -> update -> find cycle' do
      # Create
      original = Todo::Entity::Location.new(
        id: nil,
        course_id: course.id,
        name: 'Full Cycle Test',
        longitude: 121.5654,
        latitude: 25.0330,
        created_at: nil,
        updated_at: nil
      )

      created = repository.create(original)
      _(created.id).wont_be_nil

      # Find
      found = repository.find_id(created.id)
      _(found.name).must_equal 'Full Cycle Test'

      # Update
      modified = found.new(name: 'Updated Cycle Test', longitude: 139.6917)
      updated = repository.update(modified)
      _(updated.name).must_equal 'Updated Cycle Test'
      _(updated.longitude).must_equal 139.6917

      # Verify final state
      final = repository.find_id(created.id)
      _(final.name).must_equal 'Updated Cycle Test'
      _(final.longitude).must_equal 139.6917
      _(final.course_id).must_equal course.id
    end
  end

  describe 'geo_location integration' do
    it 'entity has functioning geo_location value object' do
      entity = Todo::Entity::Location.new(
        id: nil,
        course_id: course.id,
        name: 'Taipei Office',
        longitude: 121.5654,
        latitude: 25.0330,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.geo_location).must_be_instance_of Todo::Value::GeoLocation
      _(result.has_coordinates?).must_equal true
    end

    it 'entity without coordinates has NullGeoLocation' do
      entity = Todo::Entity::Location.new(
        id: nil,
        course_id: course.id,
        name: 'Virtual Location',
        longitude: nil,
        latitude: nil,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.geo_location).must_be_instance_of Todo::Value::NullGeoLocation
      _(result.has_coordinates?).must_equal false
    end
  end
end
