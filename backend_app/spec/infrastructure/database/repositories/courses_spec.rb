# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Repository::Courses' do
  let(:repository) { Tyto::Repository::Courses.new }
  let(:now) { Time.now }
  let(:one_day) { 24 * 60 * 60 }

  describe '#create' do
    it 'persists a new course and returns entity with ID' do
      entity = Tyto::Entity::Course.new(
        id: nil,
        name: 'Ruby Programming',
        logo: 'ruby.png',
        start_at: now,
        end_at: now + 30 * one_day,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Tyto::Entity::Course
      _(result.id).wont_be_nil
      _(result.name).must_equal 'Ruby Programming'
      _(result.logo).must_equal 'ruby.png'
      _(result.created_at).wont_be_nil
      _(result.updated_at).wont_be_nil
    end

    it 'persists course with minimal attributes' do
      entity = Tyto::Entity::Course.new(
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
      orm_course = Tyto::Course.create(
        name: 'Test Course',
        logo: 'test.png',
        start_at: now,
        end_at: now + 30 * one_day
      )

      result = repository.find_id(orm_course.id)

      _(result).must_be_instance_of Tyto::Entity::Course
      _(result.id).must_equal orm_course.id
      _(result.name).must_equal 'Test Course'
      _(result.logo).must_equal 'test.png'
    end

    it 'returns course with children not loaded (nil)' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      orm_location = Tyto::Location.create(course_id: orm_course.id, name: 'Room A')
      Tyto::Event.create(course_id: orm_course.id, location_id: orm_location.id, name: 'Event 1')

      result = repository.find_id(orm_course.id)

      _(result.events).must_be_nil
      _(result.locations).must_be_nil
      _(result.enrollments).must_be_nil
      _(result.events_loaded?).must_equal false
      _(result.locations_loaded?).must_equal false
      _(result.enrollments_loaded?).must_equal false
    end

    it 'returns nil for non-existent course' do
      result = repository.find_id(999_999)

      _(result).must_be_nil
    end
  end

  describe '#find_with_events' do
    it 'returns course with events loaded' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      orm_location = Tyto::Location.create(course_id: orm_course.id, name: 'Room A')
      Tyto::Event.create(course_id: orm_course.id, location_id: orm_location.id, name: 'Event 1')
      Tyto::Event.create(course_id: orm_course.id, location_id: orm_location.id, name: 'Event 2')

      result = repository.find_with_events(orm_course.id)

      _(result.events_loaded?).must_equal true
      _(result.events.length).must_equal 2
      _(result.events.map(&:name)).must_include 'Event 1'
      _(result.events.map(&:name)).must_include 'Event 2'
    end

    it 'returns empty array for course with no events' do
      orm_course = Tyto::Course.create(name: 'Test Course')

      result = repository.find_with_events(orm_course.id)

      _(result.events_loaded?).must_equal true
      _(result.events).must_equal []
    end

    it 'does not load locations' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      Tyto::Location.create(course_id: orm_course.id, name: 'Room A')

      result = repository.find_with_events(orm_course.id)

      _(result.locations).must_be_nil
      _(result.locations_loaded?).must_equal false
    end

    it 'returns nil for non-existent course' do
      _(repository.find_with_events(999_999)).must_be_nil
    end
  end

  describe '#find_with_locations' do
    it 'returns course with locations loaded' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      Tyto::Location.create(course_id: orm_course.id, name: 'Room A')
      Tyto::Location.create(course_id: orm_course.id, name: 'Room B')

      result = repository.find_with_locations(orm_course.id)

      _(result.locations_loaded?).must_equal true
      _(result.locations.length).must_equal 2
      _(result.locations.map(&:name)).must_include 'Room A'
      _(result.locations.map(&:name)).must_include 'Room B'
    end

    it 'returns empty array for course with no locations' do
      orm_course = Tyto::Course.create(name: 'Test Course')

      result = repository.find_with_locations(orm_course.id)

      _(result.locations_loaded?).must_equal true
      _(result.locations).must_equal []
    end

    it 'does not load events' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      orm_location = Tyto::Location.create(course_id: orm_course.id, name: 'Room A')
      Tyto::Event.create(course_id: orm_course.id, location_id: orm_location.id, name: 'Event 1')

      result = repository.find_with_locations(orm_course.id)

      _(result.events).must_be_nil
      _(result.events_loaded?).must_equal false
    end

    it 'returns nil for non-existent course' do
      _(repository.find_with_locations(999_999)).must_be_nil
    end
  end

  describe '#find_with_enrollments' do
    let(:owner_role) { Tyto::Role.first(name: 'owner') }
    let(:instructor_role) { Tyto::Role.first(name: 'instructor') }
    let(:student_role) { Tyto::Role.first(name: 'student') }

    it 'returns course with enrollments loaded' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      account1 = Tyto::Account.create(email: 'owner@example.com', name: 'Owner')
      account2 = Tyto::Account.create(email: 'student@example.com', name: 'Student')

      Tyto::AccountCourse.create(course_id: orm_course.id, account_id: account1.id, role_id: owner_role.id)
      Tyto::AccountCourse.create(course_id: orm_course.id, account_id: account2.id, role_id: student_role.id)

      result = repository.find_with_enrollments(orm_course.id)

      _(result.enrollments_loaded?).must_equal true
      _(result.enrollments.length).must_equal 2
    end

    it 'aggregates multiple roles for same account into one enrollment' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      account = Tyto::Account.create(email: 'multi@example.com', name: 'Multi-Role')

      # Same account has both instructor and student roles
      Tyto::AccountCourse.create(course_id: orm_course.id, account_id: account.id, role_id: instructor_role.id)
      Tyto::AccountCourse.create(course_id: orm_course.id, account_id: account.id, role_id: student_role.id)

      result = repository.find_with_enrollments(orm_course.id)

      _(result.enrollments.length).must_equal 1
      enrollment = result.enrollments.first
      _(enrollment.roles.length).must_equal 2
      _(enrollment.roles).must_include 'instructor'
      _(enrollment.roles).must_include 'student'
      _(enrollment.account_email).must_equal 'multi@example.com'
    end

    it 'returns empty array for course with no enrollments' do
      orm_course = Tyto::Course.create(name: 'Test Course')

      result = repository.find_with_enrollments(orm_course.id)

      _(result.enrollments_loaded?).must_equal true
      _(result.enrollments).must_equal []
    end

    it 'does not load events or locations' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      orm_location = Tyto::Location.create(course_id: orm_course.id, name: 'Room A')
      Tyto::Event.create(course_id: orm_course.id, location_id: orm_location.id, name: 'Event 1')

      result = repository.find_with_enrollments(orm_course.id)

      _(result.events).must_be_nil
      _(result.locations).must_be_nil
    end

    it 'returns nil for non-existent course' do
      _(repository.find_with_enrollments(999_999)).must_be_nil
    end
  end

  describe '#find_full' do
    let(:student_role) { Tyto::Role.first(name: 'student') }

    it 'returns course with all children loaded' do
      orm_course = Tyto::Course.create(name: 'Test Course')
      orm_location = Tyto::Location.create(course_id: orm_course.id, name: 'Room A')
      Tyto::Event.create(course_id: orm_course.id, location_id: orm_location.id, name: 'Event 1')
      account = Tyto::Account.create(email: 'student@example.com', name: 'Student')
      Tyto::AccountCourse.create(course_id: orm_course.id, account_id: account.id, role_id: student_role.id)

      result = repository.find_full(orm_course.id)

      _(result.events_loaded?).must_equal true
      _(result.locations_loaded?).must_equal true
      _(result.enrollments_loaded?).must_equal true
      _(result.events.length).must_equal 1
      _(result.locations.length).must_equal 1
      _(result.enrollments.length).must_equal 1
    end

    it 'returns empty arrays for course with no children' do
      orm_course = Tyto::Course.create(name: 'Test Course')

      result = repository.find_full(orm_course.id)

      _(result.events).must_equal []
      _(result.locations).must_equal []
      _(result.enrollments).must_equal []
    end

    it 'returns nil for non-existent course' do
      _(repository.find_full(999_999)).must_be_nil
    end
  end

  describe '#find_all' do
    it 'returns empty array when no courses exist' do
      result = repository.find_all

      _(result).must_equal []
    end

    it 'returns all courses as domain entities' do
      # Create courses via ORM
      Tyto::Course.create(name: 'Course 1')
      Tyto::Course.create(name: 'Course 2')
      Tyto::Course.create(name: 'Course 3')

      result = repository.find_all

      _(result.length).must_equal 3
      _(result).must_be_kind_of Array
      result.each { |course| _(course).must_be_instance_of Tyto::Entity::Course }
      _(result.map(&:name)).must_include 'Course 1'
      _(result.map(&:name)).must_include 'Course 2'
      _(result.map(&:name)).must_include 'Course 3'
    end
  end

  describe '#update' do
    it 'updates existing course and returns updated entity' do
      # Create via ORM
      orm_course = Tyto::Course.create(
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
      entity = Tyto::Entity::Course.new(
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
      orm_course = Tyto::Course.create(name: 'To Delete')

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
      original = Tyto::Entity::Course.new(
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
