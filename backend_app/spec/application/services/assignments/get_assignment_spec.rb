# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Assignments::GetAssignment do
  let(:owner_account) { Tyto::Account.create(email: 'owner@example.com', name: 'Owner') }
  let(:student_account) { Tyto::Account.create(email: 'student@example.com', name: 'Student') }
  let(:owner_role) { Tyto::Role.first(name: 'owner') }
  let(:student_role) { Tyto::Role.first(name: 'student') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }

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
    it 'returns published assignment with requirements for any enrolled user' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published HW', status: 'published', allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: assignment.id, submission_format: 'file',
        description: 'Source code', sort_order: 0
      )

      result = Tyto::Service::Assignments::GetAssignment.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      msg = result.value!.message
      _(msg.title).must_equal 'Published HW'
      _(msg.requirements_loaded?).must_equal true
      _(msg.submission_requirements.count).must_equal 1
    end

    it 'returns draft assignment for teaching staff' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::GetAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.status).must_equal 'draft'
    end

    it 'returns Failure when student tries to view draft' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::GetAssignment.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure for non-existent assignment' do
      result = Tyto::Service::Assignments::GetAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: 999_999
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'policy summary denies unpublish and delete when assignment has submissions' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published with subs', status: 'published', allow_late_resubmit: false
      )
      Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now
      )

      result = Tyto::Service::Assignments::GetAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      policies = result.value!.message.policies
      _(policies[:can_unpublish]).must_equal false
      _(policies[:can_delete]).must_equal false
      _(policies[:can_update]).must_equal true
    end

    it 'includes linked_event in the response when assignment has event_id set' do
      location = Tyto::Location.create(course_id: course.id, name: 'Room A')
      event = Tyto::Event.create(
        course_id: course.id, location_id: location.id,
        name: 'Week 1 Lecture', start_at: Time.now, end_at: Time.now + 3600
      )
      assignment = Tyto::Assignment.create(
        course_id: course.id, event_id: event.id,
        title: 'With Event', status: 'published', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::GetAssignment.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      linked = result.value!.message.linked_event
      _(linked).wont_be_nil
      _(linked.id).must_equal event.id
      _(linked.name).must_equal 'Week 1 Lecture'
    end

    it 'returns nil linked_event when assignment has no event_id' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'No Event', status: 'published', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::GetAssignment.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.linked_event).must_be_nil
    end

    it 'policy summary allows unpublish and delete when assignment has no submissions' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published no subs', status: 'published', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::GetAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      policies = result.value!.message.policies
      _(policies[:can_unpublish]).must_equal true
      _(policies[:can_delete]).must_equal true
    end
  end
end
