# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Submissions::GetSubmission do
  let(:owner_account) { Tyto::Account.create(email: 'owner@example.com', name: 'Owner') }
  let(:student_account) { Tyto::Account.create(email: 'student@example.com', name: 'Student') }
  let(:another_student) { Tyto::Account.create(email: 'student2@example.com', name: 'Student 2') }
  let(:owner_role) { Tyto::Role.first(name: 'owner') }
  let(:student_role) { Tyto::Role.first(name: 'student') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }

  let(:assignment) do
    Tyto::Assignment.create(
      course_id: course.id,
      title: 'Homework 1',
      status: 'published',
      allow_late_resubmit: false
    )
  end

  before do
    Tyto::AccountCourse.create(course_id: course.id, account_id: owner_account.id, role_id: owner_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: student_account.id, role_id: student_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: another_student.id, role_id: student_role.id)
  end

  let(:owner_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: owner_account.id, roles: ['member'])
  end
  let(:student_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student_account.id, roles: ['member'])
  end
  let(:another_student_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: another_student.id, roles: ['member'])
  end

  describe '#call' do
    it 'returns submission with entries for the student' do
      sub = Tyto::Submission.create(
        assignment_id: assignment.id,
        account_id: student_account.id,
        submitted_at: Time.now
      )

      result = Tyto::Service::Submissions::GetSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_id: sub.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      submission = result.value!.message
      _(submission.id).must_equal sub.id
      _(submission.uploads_loaded?).must_equal true
    end

    it 'allows teaching staff to view any submission' do
      sub = Tyto::Submission.create(
        assignment_id: assignment.id,
        account_id: student_account.id,
        submitted_at: Time.now
      )

      result = Tyto::Service::Submissions::GetSubmission.new.call(
        requestor: owner_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_id: sub.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
    end

    it 'denies student from viewing another students submission' do
      sub = Tyto::Submission.create(
        assignment_id: assignment.id,
        account_id: student_account.id,
        submitted_at: Time.now
      )

      result = Tyto::Service::Submissions::GetSubmission.new.call(
        requestor: another_student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_id: sub.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns Failure for non-existent submission' do
      result = Tyto::Service::Submissions::GetSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_id: 999_999
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'returns Failure for submission from different assignment' do
      other_assignment = Tyto::Assignment.create(
        course_id: course.id,
        title: 'Other HW',
        status: 'published',
        allow_late_resubmit: false
      )
      sub = Tyto::Submission.create(
        assignment_id: other_assignment.id,
        account_id: student_account.id,
        submitted_at: Time.now
      )

      result = Tyto::Service::Submissions::GetSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_id: sub.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end
  end
end
