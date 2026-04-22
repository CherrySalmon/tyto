# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Events::CreateEvents do
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:event_location) do
    Tyto::Location.create(name: 'Room 101', course_id: course.id, longitude: 121.5, latitude: 25.0)
  end
  let(:account) { Tyto::Account.create(email: 'test@example.com', name: 'Test User') }
  let(:owner_role) { Tyto::Role.first(name: 'owner') }

  before do
    Tyto::AccountCourse.create(account_id: account.id, course_id: course.id, role_id: owner_role.id)
  end

  let(:requestor) { Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['creator']) }

  def valid_row(name:, offset_hours: 0)
    start_at = Time.now + (offset_hours * 3600)
    {
      'name' => name,
      'location_id' => event_location.id,
      'start_at' => start_at.iso8601,
      'end_at' => (start_at + 3600).iso8601
    }
  end

  describe '#call' do
    it 'returns Success with an array of created events for a valid 3-row payload' do
      events_data = [
        valid_row(name: 'Lecture 1', offset_hours: 0),
        valid_row(name: 'Lecture 2', offset_hours: 24),
        valid_row(name: 'Lecture 3', offset_hours: 48)
      ]

      result = Tyto::Service::Events::CreateEvents.new.call(requestor:, course_id: course.id, events_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      events = result.value!.message
      _(events).must_be_kind_of Array
      _(events.size).must_equal 3
      _(events.map(&:name)).must_equal ['Lecture 1', 'Lecture 2', 'Lecture 3']
      _(events.first.longitude).must_equal event_location.longitude
      _(events.first.latitude).must_equal event_location.latitude
    end

    it 'returns Failure(forbidden) when requestor is a student (not teaching staff)' do
      student_account = Tyto::Account.create(email: 'student@example.com', name: 'Student')
      student_role = Tyto::Role.first(name: 'student')
      Tyto::AccountCourse.create(account_id: student_account.id, course_id: course.id, role_id: student_role.id)
      student_requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: student_account.id, roles: ['member']
      )

      events_data = [valid_row(name: 'Lecture 1')]

      result = Tyto::Service::Events::CreateEvents.new.call(
        requestor: student_requestor, course_id: course.id, events_data:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
      _(Tyto::Event.where(course_id: course.id).count).must_equal 0
    end

    it 'rejects the whole batch and persists no rows when a row is missing its name' do
      events_data = [
        valid_row(name: 'Lecture 1', offset_hours: 0),
        valid_row(name: '', offset_hours: 24),
        valid_row(name: 'Lecture 3', offset_hours: 48)
      ]

      result = Tyto::Service::Events::CreateEvents.new.call(requestor:, course_id: course.id, events_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
      _(Tyto::Event.where(course_id: course.id).count).must_equal 0
    end

    it 'rejects the whole batch and persists no rows when a row has end_at before start_at' do
      good = valid_row(name: 'Lecture 1')
      bad_start = Time.now + (24 * 3600)
      bad = {
        'name' => 'Bad Times',
        'location_id' => event_location.id,
        'start_at' => (bad_start + 3600).iso8601,
        'end_at' => bad_start.iso8601
      }
      events_data = [good, bad, valid_row(name: 'Lecture 3', offset_hours: 48)]

      result = Tyto::Service::Events::CreateEvents.new.call(requestor:, course_id: course.id, events_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
      _(Tyto::Event.where(course_id: course.id).count).must_equal 0
    end

    it 'returns Failure(not_found) when the course does not exist' do
      events_data = [valid_row(name: 'Lecture 1')]

      result = Tyto::Service::Events::CreateEvents.new.call(
        requestor:, course_id: 9_999_999, events_data:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'rejects batches larger than 100 rows with a specific error message' do
      events_data = Array.new(101) { |i| valid_row(name: "Lecture #{i + 1}", offset_hours: i) }

      result = Tyto::Service::Events::CreateEvents.new.call(requestor:, course_id: course.id, events_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
      _(result.failure.message).must_match(/Batch too large: 100 events max, got 101/)
      _(Tyto::Event.where(course_id: course.id).count).must_equal 0
    end

    it 'accepts exactly 100 rows (upper bound)' do
      events_data = Array.new(100) { |i| valid_row(name: "Lecture #{i + 1}", offset_hours: i) }

      result = Tyto::Service::Events::CreateEvents.new.call(requestor:, course_id: course.id, events_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.size).must_equal 100
    end

    it 'rolls back the whole batch when a row references an unknown location_id' do
      events_data = [
        valid_row(name: 'Lecture 1', offset_hours: 0),
        valid_row(name: 'Lecture 2', offset_hours: 24).merge('location_id' => 9_999_999),
        valid_row(name: 'Lecture 3', offset_hours: 48)
      ]

      result = Tyto::Service::Events::CreateEvents.new.call(requestor:, course_id: course.id, events_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(Tyto::Event.where(course_id: course.id).count).must_equal 0
    end
  end
end
