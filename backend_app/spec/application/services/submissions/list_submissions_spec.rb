# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Submissions::ListSubmissions do
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

  describe '#call' do
    it 'returns all submissions for teaching staff' do
      Tyto::Submission.create(assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now)
      Tyto::Submission.create(assignment_id: assignment.id, account_id: another_student.id, submitted_at: Time.now)

      result = Tyto::Service::Submissions::ListSubmissions.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      submissions = result.value!.message
      _(submissions.length).must_equal 2
    end

    it 'returns only own submission for student' do
      Tyto::Submission.create(assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now)
      Tyto::Submission.create(assignment_id: assignment.id, account_id: another_student.id, submitted_at: Time.now)

      result = Tyto::Service::Submissions::ListSubmissions.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      submissions = result.value!.message
      _(submissions.length).must_equal 1
      _(submissions.first.account_id).must_equal student_account.id
    end

    it 'returns empty array for student with no submission' do
      result = Tyto::Service::Submissions::ListSubmissions.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message).must_equal []
    end

    it 'returns Failure for non-enrolled user' do
      outsider = Tyto::Account.create(email: 'outsider@example.com', name: 'Outsider')
      outsider_requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: outsider.id, roles: ['member']
      )

      result = Tyto::Service::Submissions::ListSubmissions.new.call(
        requestor: outsider_requestor, course_id: course.id, assignment_id: assignment.id
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'returns submissions with entries loaded' do
      sub = Tyto::Submission.create(assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now)
      req = Tyto::SubmissionRequirement.create(
        assignment_id: assignment.id, submission_format: 'file',
        description: 'Source', sort_order: 0
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub.id, requirement_id: req.id,
        content: "#{assignment.id}/#{req.id}/#{student_account.id}.Rmd",
        filename: 'homework1.Rmd'
      )

      result = Tyto::Service::Submissions::ListSubmissions.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      submission = result.value!.message.first
      _(submission.uploads_loaded?).must_equal true
      _(submission.requirement_uploads.count).must_equal 1
    end

    it 'attaches a Submitter (name + email) to each submission when teaching staff views' do
      Tyto::Submission.create(assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now)
      Tyto::Submission.create(assignment_id: assignment.id, account_id: another_student.id, submitted_at: Time.now + 60)

      result = Tyto::Service::Submissions::ListSubmissions.new.call(
        requestor: owner_requestor, course_id: course.id, assignment_id: assignment.id
      )

      submissions = result.value!.message
      first = submissions.find { |s| s.account_id == student_account.id }
      second = submissions.find { |s| s.account_id == another_student.id }

      _(first.submitter).must_be_kind_of Tyto::Domain::Assignments::Values::Submitter
      _(first.submitter.name).must_equal 'Student'
      _(first.submitter.email).must_equal 'student@example.com'
      _(second.submitter.name).must_equal 'Student 2'
      _(second.submitter.email).must_equal 'student2@example.com'
    end

    it 'attaches a Submitter when a student views their own submission' do
      Tyto::Submission.create(assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now)

      result = Tyto::Service::Submissions::ListSubmissions.new.call(
        requestor: student_requestor, course_id: course.id, assignment_id: assignment.id
      )

      sub = result.value!.message.first
      _(sub.submitter).must_be_kind_of Tyto::Domain::Assignments::Values::Submitter
      _(sub.submitter.name).must_equal 'Student'
      _(sub.submitter.email).must_equal 'student@example.com'
    end
  end
end
