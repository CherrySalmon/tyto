# frozen_string_literal: true

require_relative '../../../spec_helper'

# Recording double for the FileStorage Gateway. Lets the file-storage
# integration tests assert call shape (which keys were HEADed, which
# deleted) without a real S3 round-trip and without hitting the LocalGateway
# filesystem. Per-key `head_results` / `delete_results` overrides simulate
# missing files and failing deletes.
class CreateSubmissionRecordingGateway
  include Dry::Monads[:result]

  attr_reader :head_calls, :delete_calls

  def initialize(head_results: {}, delete_results: {})
    @head_results   = head_results
    @delete_results = delete_results
    @head_calls     = []
    @delete_calls   = []
  end

  # Record the underlying string so tests can assert against String literals
  # without having to construct StorageKey instances; result-lookup still
  # accepts the StorageKey because StorageKey equality is symmetric on its
  # side with the underlying String (Hash#fetch uses key.hash + key.eql?).
  def head(key:)
    @head_calls << key.to_s
    @head_results.fetch(key, Success(true))
  end

  def delete(key:)
    @delete_calls << key.to_s
    @delete_results.fetch(key, Success(true))
  end
end

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
            'content' => "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.Rmd",
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

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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
            'content' => "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.Rmd",
            'filename' => 'old_file.Rmd',
            'content_type' => 'text/x-r-markdown',
            'file_size' => 1024
          }
        ]
      }

      Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: first_data
      )

      # Overwrite submission
      overwrite_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content' => "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.qmd",
            'filename' => 'new_file.qmd',
            'content_type' => 'text/x-quarto',
            'file_size' => 4096
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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
            'content' => "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.pdf",
            'filename' => 'report.pdf',
            'content_type' => 'application/pdf',
            'file_size' => 2048
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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
            'content' => "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.RMD",
            'filename' => 'homework1.RMD',
            'content_type' => 'text/x-r-markdown',
            'file_size' => 2048
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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
            'content' => "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.Rmd",
            'filename' => 'huge.Rmd',
            'content_type' => 'text/plain',
            'file_size' => 11_000_000
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'rejects empty entries' do
      submit_data = { 'entries' => [] }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
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

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data: submit_data
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end
  end

  # File-type entries: the service reconstructs the S3 key from the
  # authenticated account_id and HEAD-checks it; the client-supplied
  # `content` is ignored, and a missing object yields bad_request. On
  # resubmit with a changed extension the old key is deleted best-effort
  # outside the DB transaction so a storage blip cannot roll back a valid
  # submission; same-extension resubmits skip the delete.
  #
  # URL-type entries bypass storage entirely — the raw URL stays in
  # `content` with no Gateway interaction. `filename` and `content_type`
  # are stored as the client sent them (untrusted display metadata).
  describe '#call — file storage integration' do
    let(:recording_gateway) { CreateSubmissionRecordingGateway.new }

    # SubmissionMapper lowercases the extension when building the key, so the
    # server-reconstructed key for a `homework1.Rmd` upload ends in `.rmd`.
    let(:expected_file_key) do
      "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.rmd"
    end

    it 'reconstructs the S3 key server-side and HEADs that key, not the client-supplied content' do
      file_requirement
      submission_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content'        => 'totally/bogus/key.Rmd',
            'filename'       => 'homework1.Rmd',
            'content_type'   => 'text/x-r-markdown',
            'file_size'      => 2048
          }
        ]
      }

      Tyto::Service::Submissions::CreateSubmission.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data:
      )

      _(recording_gateway.head_calls).must_equal [expected_file_key]
      _(recording_gateway.head_calls).wont_include 'totally/bogus/key.Rmd'
    end

    it 'ignores client-supplied content for file-type entries (persists server-reconstructed key)' do
      file_requirement
      submission_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content'        => 'totally/bogus/key.Rmd',
            'filename'       => 'homework1.Rmd',
            'content_type'   => 'text/x-r-markdown',
            'file_size'      => 2048
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      upload = result.value!.message.requirement_uploads.find_by_requirement(file_requirement.id)
      _(upload.content).must_equal expected_file_key
    end

    it "rejects a body whose content points at another account's key (server reconstructs from auth)" do
      file_requirement
      foreign_key = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{another_student.id}.rmd"
      own_key     = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.rmd"
      # The foreign key is "present" in storage; the requestor's own key is missing.
      # The server must HEAD the own key (reconstructed from auth) — never the
      # foreign key the body provides.
      gateway = CreateSubmissionRecordingGateway.new(
        head_results: {
          own_key     => Dry::Monads::Result::Failure.new(:not_found),
          foreign_key => Dry::Monads::Result::Success.new(true)
        }
      )

      submission_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content'        => foreign_key,
            'filename'       => 'homework1.Rmd',
            'content_type'   => 'text/x-r-markdown',
            'file_size'      => 2048
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway:).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
      _(gateway.head_calls).must_equal [own_key]
      _(gateway.head_calls).wont_include foreign_key
    end

    it 'returns bad_request when the reconstructed S3 key does not exist (HEAD returns not_found)' do
      file_requirement
      own_key = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.rmd"
      gateway_with_missing = CreateSubmissionRecordingGateway.new(
        head_results: { own_key => Dry::Monads::Result::Failure.new(:not_found) }
      )

      submission_data = {
        'entries' => [
          {
            'requirement_id' => file_requirement.id,
            'content'        => own_key,
            'filename'       => 'homework1.Rmd',
            'content_type'   => 'text/x-r-markdown',
            'file_size'      => 2048
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: gateway_with_missing).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'persists URL-type content as a raw string with no gateway calls' do
      url_requirement
      submission_data = {
        'entries' => [
          {
            'requirement_id' => url_requirement.id,
            'content'        => 'https://github.com/student/repo'
          }
        ]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      upload = result.value!.message.requirement_uploads.find_by_requirement(url_requirement.id)
      _(upload.content).must_equal 'https://github.com/student/repo'
      _(recording_gateway.head_calls).must_be_empty
      _(recording_gateway.delete_calls).must_be_empty
    end

    it 'on resubmit with a changed extension, calls gateway.delete with the old key after persisting the new entry' do
      file_requirement
      old_key = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.rmd"
      new_key = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.qmd"

      Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id,
        submission_data: { 'entries' => [{
          'requirement_id' => file_requirement.id,
          'content'        => old_key,
          'filename'       => 'old.Rmd',
          'content_type'   => 'text/plain',
          'file_size'      => 100
        }] }
      )

      resubmit_gateway = CreateSubmissionRecordingGateway.new
      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: resubmit_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id,
        submission_data: { 'entries' => [{
          'requirement_id' => file_requirement.id,
          'content'        => new_key,
          'filename'       => 'new.qmd',
          'content_type'   => 'text/x-quarto',
          'file_size'      => 4096
        }] }
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(resubmit_gateway.delete_calls).must_equal [old_key]
      upload = result.value!.message.requirement_uploads.find_by_requirement(file_requirement.id)
      _(upload.content).must_equal new_key
    end

    it 'on resubmit with the same extension, does NOT call gateway.delete (overwrite at the same key)' do
      file_requirement
      own_key = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.Rmd"

      Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id,
        submission_data: { 'entries' => [{
          'requirement_id' => file_requirement.id,
          'content'        => own_key,
          'filename'       => 'old.Rmd',
          'content_type'   => 'text/plain',
          'file_size'      => 100
        }] }
      )

      resubmit_gateway = CreateSubmissionRecordingGateway.new
      Tyto::Service::Submissions::CreateSubmission.new(gateway: resubmit_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id,
        submission_data: { 'entries' => [{
          'requirement_id' => file_requirement.id,
          'content'        => own_key,
          'filename'       => 'new.Rmd',
          'content_type'   => 'text/plain',
          'file_size'      => 200
        }] }
      )

      _(resubmit_gateway.delete_calls).must_be_empty
    end

    it 'persists the new entry even when gateway.delete fails for the old key (best-effort cleanup)' do
      file_requirement
      old_key = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.rmd"
      new_key = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.qmd"

      Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id,
        submission_data: { 'entries' => [{
          'requirement_id' => file_requirement.id,
          'content'        => old_key,
          'filename'       => 'old.Rmd',
          'content_type'   => 'text/plain',
          'file_size'      => 100
        }] }
      )

      failing_gateway = CreateSubmissionRecordingGateway.new(
        delete_results: { old_key => Dry::Monads::Result::Failure.new('S3 unreachable') }
      )

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: failing_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id,
        submission_data: { 'entries' => [{
          'requirement_id' => file_requirement.id,
          'content'        => new_key,
          'filename'       => 'new.qmd',
          'content_type'   => 'text/x-quarto',
          'file_size'      => 4096
        }] }
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(failing_gateway.delete_calls).must_equal [old_key]
      upload = result.value!.message.requirement_uploads.find_by_requirement(file_requirement.id)
      _(upload.content).must_equal new_key
      # And the row is actually persisted in the DB (not just rolled back into the response object).
      persisted = Tyto::SubmissionEntry.first(
        submission_id: result.value!.message.id, requirement_id: file_requirement.id
      )
      _(persisted.content).must_equal new_key
    end

    it 'URL-type resubmit overwrites content with no gateway calls (no storage side effects)' do
      url_requirement

      Tyto::Service::Submissions::CreateSubmission.new(gateway: CreateSubmissionRecordingGateway.new).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id,
        submission_data: { 'entries' => [{
          'requirement_id' => url_requirement.id,
          'content'        => 'https://github.com/student/repo-old'
        }] }
      )

      resubmit_gateway = CreateSubmissionRecordingGateway.new
      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: resubmit_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id,
        submission_data: { 'entries' => [{
          'requirement_id' => url_requirement.id,
          'content'        => 'https://github.com/student/repo-new'
        }] }
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      upload = result.value!.message.requirement_uploads.find_by_requirement(url_requirement.id)
      _(upload.content).must_equal 'https://github.com/student/repo-new'
      _(resubmit_gateway.head_calls).must_be_empty
      _(resubmit_gateway.delete_calls).must_be_empty
    end

    it "persists the client's content_type as-is (untrusted display metadata)" do
      file_requirement
      own_key = "#{course.id}/#{assignment.id}/#{file_requirement.id}/#{student_account.id}.Rmd"
      weird_content_type = 'application/x-totally-fake-mime'

      submission_data = {
        'entries' => [{
          'requirement_id' => file_requirement.id,
          'content'        => own_key,
          'filename'       => 'homework1.Rmd',
          'content_type'   => weird_content_type,
          'file_size'      => 2048
        }]
      }

      result = Tyto::Service::Submissions::CreateSubmission.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, submission_data:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      upload = result.value!.message.requirement_uploads.find_by_requirement(file_requirement.id)
      _(upload.content_type).must_equal weird_content_type
    end
  end
end
