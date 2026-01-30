# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Repository::Attendances' do
  let(:repository) { Tyto::Repository::Attendances.new }
  let(:now) { Time.now }

  # Attendances require course, account, and optionally event
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:account) { Tyto::Account.create(email: 'student@example.com') }
  let(:another_account) { Tyto::Account.create(email: 'another@example.com') }
  let(:event_location) { Tyto::Location.create(course_id: course.id, name: 'Room 101') }
  let(:event) { Tyto::Event.create(course_id: course.id, location_id: event_location.id, name: 'Lecture 1') }
  let(:another_event) { Tyto::Event.create(course_id: course.id, location_id: event_location.id, name: 'Lecture 2') }
  let(:student_role) { Tyto::Role.first(name: 'student') }

  describe '#create' do
    it 'persists a new attendance and returns entity with ID' do
      entity = Tyto::Entity::Attendance.new(
        id: nil,
        account_id: account.id,
        course_id: course.id,
        event_id: event.id,
        role_id: student_role.id,
        name: 'Lecture 1 Attendance',
        longitude: 121.5654,
        latitude: 25.0330,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result).must_be_instance_of Tyto::Entity::Attendance
      _(result.id).wont_be_nil
      _(result.account_id).must_equal account.id
      _(result.course_id).must_equal course.id
      _(result.event_id).must_equal event.id
      _(result.longitude).must_equal 121.5654
      _(result.latitude).must_equal 25.0330
    end

    it 'persists attendance without coordinates' do
      entity = Tyto::Entity::Attendance.new(
        id: nil,
        account_id: account.id,
        course_id: course.id,
        event_id: event.id,
        role_id: nil,
        name: 'No Location',
        longitude: nil,
        latitude: nil,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.id).wont_be_nil
      _(result.longitude).must_be_nil
      _(result.latitude).must_be_nil
    end
  end

  describe '#find_id' do
    it 'returns domain entity for existing attendance' do
      orm_attendance = Tyto::Attendance.create(
        account_id: account.id,
        course_id: course.id,
        event_id: event.id,
        name: 'Test Attendance'
      )

      result = repository.find_id(orm_attendance.id)

      _(result).must_be_instance_of Tyto::Entity::Attendance
      _(result.id).must_equal orm_attendance.id
      _(result.name).must_equal 'Test Attendance'
    end

    it 'returns nil for non-existent attendance' do
      _(repository.find_id(999_999)).must_be_nil
    end
  end

  describe '#find_by_course' do
    it 'returns empty array when no attendances exist' do
      result = repository.find_by_course(course.id)

      _(result).must_equal []
    end

    it 'returns attendances for a course ordered by created_at' do
      Tyto::Attendance.create(
        account_id: account.id,
        course_id: course.id,
        event_id: event.id,
        name: 'First'
      )
      Tyto::Attendance.create(
        account_id: another_account.id,
        course_id: course.id,
        event_id: event.id,
        name: 'Second'
      )

      result = repository.find_by_course(course.id)

      _(result.length).must_equal 2
      result.each { |a| _(a.course_id).must_equal course.id }
    end
  end

  describe '#find_by_event' do
    it 'returns attendances for an event' do
      Tyto::Attendance.create(
        account_id: account.id,
        course_id: course.id,
        event_id: event.id,
        name: 'Event 1 Attendance'
      )
      Tyto::Attendance.create(
        account_id: another_account.id,
        course_id: course.id,
        event_id: another_event.id,
        name: 'Event 2 Attendance'
      )

      result = repository.find_by_event(event.id)

      _(result.length).must_equal 1
      _(result.first.event_id).must_equal event.id
    end
  end

  describe '#find_by_account_course' do
    it 'returns attendances for an account in a course' do
      Tyto::Attendance.create(
        account_id: account.id,
        course_id: course.id,
        event_id: event.id,
        name: 'Account Attendance 1'
      )
      Tyto::Attendance.create(
        account_id: account.id,
        course_id: course.id,
        event_id: another_event.id,
        name: 'Account Attendance 2'
      )
      Tyto::Attendance.create(
        account_id: another_account.id,
        course_id: course.id,
        event_id: event.id,
        name: 'Other Account'
      )

      result = repository.find_by_account_course(account.id, course.id)

      _(result.length).must_equal 2
      result.each { |a| _(a.account_id).must_equal account.id }
    end
  end

  describe '#find_by_account_event' do
    it 'returns attendance for account at event' do
      Tyto::Attendance.create(
        account_id: account.id,
        course_id: course.id,
        event_id: event.id,
        name: 'Found'
      )

      result = repository.find_by_account_event(account.id, event.id)

      _(result).must_be_instance_of Tyto::Entity::Attendance
      _(result.account_id).must_equal account.id
      _(result.event_id).must_equal event.id
    end

    it 'returns nil when not found' do
      _(repository.find_by_account_event(account.id, 999_999)).must_be_nil
    end
  end

  describe '#find_all' do
    it 'returns empty array when no attendances exist' do
      result = repository.find_all

      _(result).must_equal []
    end

    it 'returns all attendances as domain entities' do
      Tyto::Attendance.create(account_id: account.id, course_id: course.id, name: 'One')
      Tyto::Attendance.create(account_id: another_account.id, course_id: course.id, name: 'Two')

      result = repository.find_all

      _(result.length).must_equal 2
      result.each { |a| _(a).must_be_instance_of Tyto::Entity::Attendance }
    end
  end

  describe '#delete' do
    it 'deletes existing attendance and returns true' do
      orm_attendance = Tyto::Attendance.create(
        account_id: account.id,
        course_id: course.id,
        name: 'To Delete'
      )

      result = repository.delete(orm_attendance.id)

      _(result).must_equal true
      _(repository.find_id(orm_attendance.id)).must_be_nil
    end

    it 'returns false for non-existent attendance' do
      _(repository.delete(999_999)).must_equal false
    end
  end

  describe 'check_in_location integration' do
    it 'entity has functioning check_in_location' do
      entity = Tyto::Entity::Attendance.new(
        id: nil,
        account_id: account.id,
        course_id: course.id,
        event_id: event.id,
        role_id: nil,
        name: 'With Location',
        longitude: 121.5654,
        latitude: 25.0330,
        created_at: nil,
        updated_at: nil
      )

      result = repository.create(entity)

      _(result.check_in_location).must_be_instance_of Tyto::Value::GeoLocation
      _(result.has_coordinates?).must_equal true
    end
  end
end
