# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Todo::Repository::Courses' do
  let(:repository) { Todo::Repository::Courses.new }
  let(:now) { Time.now }
  let(:one_day) { 24 * 60 * 60 }

  describe '#create' do
    it 'persists a new course and returns entity with ID' do
      entity = Todo::Entity::Course.new(
        id: nil,
        name: 'Ruby Programming',
        logo: 'ruby.png',
        start_at: now,
        end_at: now + 30 * one_day,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Todo::Entity::Course
      _(result.id).wont_be_nil
      _(result.name).must_equal 'Ruby Programming'
      _(result.logo).must_equal 'ruby.png'
      _(result.created_at).wont_be_nil
      _(result.updated_at).wont_be_nil
    end

    it 'persists course with minimal attributes' do
      entity = Todo::Entity::Course.new(
        id: nil,
        name: 'Minimal Course',
        logo: nil,
        start_at: nil,
        end_at: nil,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.id).wont_be_nil
      _(result.name).must_equal 'Minimal Course'
      _(result.logo).must_be_nil
      _(result.start_at).must_be_nil
    end
  end

  describe '#find_id' do
    it 'returns domain entity for existing course' do
      # Create via ORM for test setup
      orm_course = Todo::Course.create(
        name: 'Test Course',
        logo: 'test.png',
        start_at: now,
        end_at: now + 30 * one_day
      )

      result = repository.find_id(orm_course.id)

      _(result).must_be_instance_of Todo::Entity::Course
      _(result.id).must_equal orm_course.id
      _(result.name).must_equal 'Test Course'
      _(result.logo).must_equal 'test.png'
    end

    it 'returns nil for non-existent course' do
      result = repository.find_id(999_999)

      _(result).must_be_nil
    end
  end

  describe '#find_all' do
    it 'returns empty array when no courses exist' do
      result = repository.find_all

      _(result).must_equal []
    end

    it 'returns all courses as domain entities' do
      # Create courses via ORM
      Todo::Course.create(name: 'Course 1')
      Todo::Course.create(name: 'Course 2')
      Todo::Course.create(name: 'Course 3')

      result = repository.find_all

      _(result.length).must_equal 3
      _(result).must_be_kind_of Array
      result.each { |course| _(course).must_be_instance_of Todo::Entity::Course }
      _(result.map(&:name)).must_include 'Course 1'
      _(result.map(&:name)).must_include 'Course 2'
      _(result.map(&:name)).must_include 'Course 3'
    end
  end

  describe '#update' do
    it 'updates existing course and returns updated entity' do
      # Create via ORM
      orm_course = Todo::Course.create(
        name: 'Original Name',
        logo: 'old.png'
      )

      # Get entity, modify via new(), then update
      entity = repository.find_id(orm_course.id)
      updated_entity = entity.new(name: 'Updated Name', logo: 'new.png')

      result = repository.update(updated_entity)

      _(result.name).must_equal 'Updated Name'
      _(result.logo).must_equal 'new.png'
      _(result.id).must_equal orm_course.id

      # Verify persistence
      reloaded = repository.find_id(orm_course.id)
      _(reloaded.name).must_equal 'Updated Name'
    end

    it 'raises error for non-existent course' do
      entity = Todo::Entity::Course.new(
        id: 999_999,
        name: 'Ghost Course',
        logo: nil,
        start_at: nil,
        end_at: nil,
        created_at: nil,
        updated_at: nil
      )

      _ { repository.update(entity) }.must_raise RuntimeError
    end
  end

  describe '#delete' do
    it 'deletes existing course and returns true' do
      orm_course = Todo::Course.create(name: 'To Delete')

      result = repository.delete(orm_course.id)

      _(result).must_equal true
      _(repository.find_id(orm_course.id)).must_be_nil
    end

    it 'returns false for non-existent course' do
      result = repository.delete(999_999)

      _(result).must_equal false
    end
  end

  describe 'round-trip' do
    it 'maintains data integrity through create -> find -> update -> find cycle' do
      # Create
      original = Todo::Entity::Course.new(
        id: nil,
        name: 'Full Cycle Test',
        logo: 'cycle.png',
        start_at: now,
        end_at: now + 30 * one_day,
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
      _(final.logo).must_equal 'cycle.png'
    end
  end
end
