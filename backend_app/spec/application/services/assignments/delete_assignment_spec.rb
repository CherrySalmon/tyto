# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Assignments::DeleteAssignment do
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
    it 'deletes draft assignment and returns Success' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft to Delete', status: 'draft', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::DeleteAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(Tyto::Assignment[assignment.id]).must_be_nil
    end

    it 'returns Failure when student tries to delete' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'draft', allow_late_resubmit: false
      )

      result = Tyto::Service::Assignments::DeleteAssignment.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent assignment' do
      result = Tyto::Service::Assignments::DeleteAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: 999_999
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure forbidden when the assignment has at least one submission' do
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'published', allow_late_resubmit: false
      )
      Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now
      )

      result = Tyto::Service::Assignments::DeleteAssignment.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
      _(Tyto::Assignment[assignment.id]).wont_be_nil
    end
  end
end
