# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Assignments::PublishAssignment do
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
    it 'publishes a draft assignment and returns Success' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::PublishAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(Tyto::Assignment[assignment.id].status).must_equal 'published'
    end

    it 'returns Failure when publishing already published assignment' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published', status: 'published', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::PublishAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when publishing disabled assignment' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Disabled', status: 'disabled', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::PublishAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns Failure when student tries to publish' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'draft', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::PublishAssignment.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end
end
