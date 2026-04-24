# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::Service::Submissions::CreateSubmission do
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
      due_at: Time.now + 7 * 86_400,
      allow_late_resubmit: false
    )
  end

  let(:file_requirement) do
    Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id,
      submission_format: 'file',
      description: 'R Markdown source',
      allowed_types: 'rmd,qmd',
      sort_order: 0
    )
  end

  let(:url_requirement) do
    Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id,
      submission_format: 'url',
      description: 'GitHub repo link',
      sort_order: 1
    )
  end

  before do
    Tyto::AccountCourse.create(course_id: course.id, account_id: owner_account.id, role_id: owner_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: student_account.id, role_id: student_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: another_student.id, role_id: student_role.id)
  end

  let(:student_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student_account.id, roles: ['member'])
  end
  let(:owner_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: owner_account.id, roles: ['member'])
  end

  describe '#call' do
    it 'creates a new submission with file and URL entries' do
      # Force lazy lets
      file_requirement
      url_requirement

      submission_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content' => "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.Rmd",
            'filename' => 'homework1.Rmd',
            'content_type' => 'text/x-r-markdown',
            'file_size' => 2048
          },
          {
            'requirement_id' => url_requirement.id,
            'content' => "#{assignment.id}/#{url_requirement.id}/#{student_account.id}.url"
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      submission = result.value!.message
      _(submission.assignment_id).must_equal assignment.id
      _(submission.account_id).must_equal student_account.id
      _(submission.uploads_loaded?).must_equal true
      _(submission.requirement_uploads.count).must_equal 2
    end

    it 'overwrites existing submission (upsert entries)' do
      file_requirement
      url_requirement

      # First submission
      first_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content' => "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.Rmd",
            'filename' => 'old_file.Rmd',
            'content_type' => 'text/x-r-markdown',
            'file_size' => 1024
          }
        ]
      }

      Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: first_data
      )

      # Overwrite submission
      overwrite_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content' => "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.qmd",
            'filename' => 'new_file.qmd',
            'content_type' => 'text/x-quarto',
            'file_size' => 4096
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: overwrite_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      submission = result.value!.message
      upload = submission.requirement_uploads.find_by_requirement(file_requirement.id)
      _(upload.filename).must_equal 'new_file.qmd'

      # Only one submission in DB (overwrite, not duplicate)
      _(Tyto::Submission.where(assignment_id: assignment.id, account_id: student_account.id).count).must_equal 1
    end

    it 'blocks late resubmission when allow_late_resubmit is false' do
      # Create assignment with past due date
      past_assignment = Tyto::Assignment.create(
        course_id: course.id,
        title: 'Past Due HW',
        status: 'published',
        due_at: Time.now - 86_400,
        allow_late_resubmit: false
      )
      past_req = Tyto::SubmissionRequirement.create(
        assignment_id: past_assignment.id,
        submission_format: 'file',
        description: 'Source', allowed_types: 'rmd',
        sort_order: 0
      )

      # Create existing submission (simulating on-time submission)
      Tyto::Submission.create(
        assignment_id: past_assignment.id,
        account_id: student_account.id,
        submitted_at: Time.now - 2 * 86_400
      )

      resubmit_data = {
        'entries' => [
          {
            'requirement_id' => past_req.id,
            'content' => "#{past_assignment.id}/#{past_req.id}/#{student_account.id}.Rmd",
            'filename' => 'late.Rmd',
            'content_type' => 'text/plain',
            'file_size' => 100
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: past_assignment.id, submission_data: resubmit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'allows first-time late submission even when allow_late_resubmit is false' do
      past_assignment = Tyto::Assignment.create(
        course_id: course.id,
        title: 'Past Due HW',
        status: 'published',
        due_at: Time.now - 86_400,
        allow_late_resubmit: false
      )
      past_req = Tyto::SubmissionRequirement.create(
        assignment_id: past_assignment.id,
        submission_format: 'file',
        description: 'Source', allowed_types: 'rmd',
        sort_order: 0
      )

      # No existing submission — first-time late submit
      submit_data = {
        'entries' => [
          {
            'requirement_id' => past_req.id,
            'content' => "#{past_assignment.id}/#{past_req.id}/#{student_account.id}.Rmd",
            'filename' => 'late_first.Rmd',
            'content_type' => 'text/plain',
            'file_size' => 100
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: past_assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
    end

    it 'allows late resubmission when allow_late_resubmit is true' do
      late_ok_assignment = Tyto::Assignment.create(
        course_id: course.id,
        title: 'Late OK HW',
        status: 'published',
        due_at: Time.now - 86_400,
        allow_late_resubmit: true
      )
      late_ok_req = Tyto::SubmissionRequirement.create(
        assignment_id: late_ok_assignment.id,
        submission_format: 'file',
        description: 'Source', allowed_types: 'rmd',
        sort_order: 0
      )

      # Existing submission
      Tyto::Submission.create(
        assignment_id: late_ok_assignment.id,
        account_id: student_account.id,
        submitted_at: Time.now - 2 * 86_400
      )

      resubmit_data = {
        'entries' => [
          {
            'requirement_id' => late_ok_req.id,
            'content' => "#{late_ok_assignment.id}/#{late_ok_req.id}/#{student_account.id}.Rmd",
            'filename' => 'late_resubmit.Rmd',
            'content_type' => 'text/plain',
            'file_size' => 100
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: late_ok_assignment.id, submission_data: resubmit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
    end

    it 'rejects submission to draft assignment' do
      draft_assignment = Tyto::Assignment.create(
        course_id: course.id,
        title: 'Draft HW',
        status: 'draft',
        allow_late_resubmit: false
      )
      draft_req = Tyto::SubmissionRequirement.create(
        assignment_id: draft_assignment.id,
        submission_format: 'file',
        description: 'Source',
        sort_order: 0
      )

      submit_data = {
        'entries' => [
          {
            'requirement_id' => draft_req.id,
            'content' => 'fake/key.Rmd',
            'filename' => 'test.Rmd',
            'file_size' => 100
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: draft_assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'rejects submission from teaching staff' do
      file_requirement

      submit_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content' => 'fake/key.Rmd',
            'filename' => 'test.Rmd',
            'file_size' => 100
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: owner_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end

    it 'rejects file with disallowed extension' do
      file_requirement

      submit_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content' => "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.pdf",
            'filename' => 'report.pdf',
            'content_type' => 'application/pdf',
            'file_size' => 2048
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'validates file extension case-insensitively' do
      file_requirement

      submit_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content' => "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.RMD",
            'filename' => 'homework1.RMD',
            'content_type' => 'text/x-r-markdown',
            'file_size' => 2048
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
    end

    it 'rejects file over 10 MB' do
      file_requirement

      submit_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content' => "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.Rmd",
            'filename' => 'huge.Rmd',
            'content_type' => 'text/plain',
            'file_size' => 11_000_000
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'rejects empty entries' do
      submit_data = { 'entries' => [] }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'rejects entry for non-existent requirement' do
      file_requirement

      submit_data = {
        'entries' => [
          {
            'requirement_id' => 999_999,
            'content' => 'fake/key.Rmd',
            'filename' => 'test.Rmd',
            'file_size' => 100
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new.call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end
  end
end
