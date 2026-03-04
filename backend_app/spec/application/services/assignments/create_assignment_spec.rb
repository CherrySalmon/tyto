# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Assignments::CreateAssignment do
  let(:owner_account) { Tyto::Account.create(email: 'owner@example.com', name: 'Owner') }
  let(:student_account) { Tyto::Account.create(email: 'student@example.com', name: 'Student') }
  let(:owner_role) { Tyto::Role.first(name: 'owner') }
  let(:student_role) { Tyto::Role.first(name: 'student') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }
  let(:course_location) { Tyto::Location.create(course_id: course.id, name: 'Room A') }
  let(:event) do
    Tyto::Event.create(
      course_id: course.id, location_id: course_location.id,
      name: 'Lecture 1', start_at: Time.now, end_at: Time.now + 3600
    )
  end

  before do
    Tyto::AccountCourse.create(course_id: course.id, account_id: owner_account.id, role_id: owner_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: student_account.id, role_id: student_role.id)
  end

  let(:owner_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: owner_account.id, roles: ['member'])
  end
  let(:student_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student_account.id, roles: ['member'])
  end

  describe '#call' do
    it 'creates assignment with requirements and returns Success' do
      assignment_data = {
        'title' => 'Homework 1',
        'description' => 'Clean the data.',
        'due_at' => (Time.now + 7 * 86_400).iso8601,
        'submission_requirements' => [
          { 'submission_format' => 'file', 'description' => 'R Markdown source', 'allowed_types' => '.Rmd,.qmd' },
          { 'submission_format' => 'url', 'description' => 'GitHub repo link' }
        ]
      }

      result = Tyto::Service::Assignments::CreateAssignment.new.call(requestor: owner_requestor, course_id: course.id,
                                        assignment_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      msg = result.value!.message
      _(msg.title).must_equal 'Homework 1'
      _(msg.status).must_equal 'draft'
      _(msg.submission_requirements.count).must_equal 2
    end

    it 'creates assignment with optional event_id' do
      assignment_data = {
        'title' => 'Event-Linked HW',
        'event_id' => event.id
      }

      result = Tyto::Service::Assignments::CreateAssignment.new.call(requestor: owner_requestor, course_id: course.id,
                                        assignment_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.event_id).must_equal event.id
    end

    it 'creates assignment with minimal data (title only)' do
      assignment_data = { 'title' => 'Minimal' }

      result = Tyto::Service::Assignments::CreateAssignment.new.call(requestor: owner_requestor, course_id: course.id,
                                        assignment_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.title).must_equal 'Minimal'
    end

    it 'returns Failure when title is missing' do
      assignment_data = { 'description' => 'No title' }

      result = Tyto::Service::Assignments::CreateAssignment.new.call(requestor: owner_requestor, course_id: course.id,
                                        assignment_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when student tries to create' do
      assignment_data = { 'title' => 'Student Attempt' }

      result = Tyto::Service::Assignments::CreateAssignment.new.call(requestor: student_requestor, course_id: course.id,
                                        assignment_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for invalid course_id' do
      assignment_data = { 'title' => 'Bad Course' }

      result = Tyto::Service::Assignments::CreateAssignment.new.call(requestor: owner_requestor, course_id: 999_999,
                                        assignment_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
    end

    it 'validates event belongs to same course' do
      other_course = Tyto::Course.create(name: 'Other')
      other_location = Tyto::Location.create(course_id: other_course.id, name: 'Room B')
      other_event = Tyto::Event.create(
        course_id: other_course.id, location_id: other_location.id,
        name: 'Wrong Event', start_at: Time.now, end_at: Time.now + 3600
      )
      assignment_data = { 'title' => 'Cross-Course Event', 'event_id' => other_event.id }

      result = Tyto::Service::Assignments::CreateAssignment.new.call(requestor: owner_requestor, course_id: course.id,
                                        assignment_data:)

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end
  end
end
