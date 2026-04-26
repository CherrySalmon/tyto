# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'json'
require 'base64'

# 3.8a — IssueUploadGrants service spec (red).
#
# IssueUploadGrants (R-P10 rename — was CreateUploadUrls) is the application
# service the frontend calls before uploading any files. For each requested
# upload it:
#   - authorizes the requestor via Policy::Submission#can_submit?
#   - validates the target requirement (must exist, must be submission_format='file',
#     extension must match allowed_types)
#   - builds the S3 key server-side via SubmissionMapper from the **authenticated**
#     account_id (R-P2 — never trusts a body-supplied account_id)
#   - asks the Gateway to presign a POST upload (R-P1) carrying MAX_SIZE_BYTES
#     in its content-length-range condition (R-P7)
#   - returns an array of `{requirement_id, key, upload_url, fields}` entries
#
# Tests use the AWS S3 SDK's stub mode for the gateway dependency — presigned-POST
# is pure local crypto, so the Policy doc decodes to its real contents in stub mode.
# That lets us assert content-length-range = MAX_SIZE_BYTES at the service layer.

# Shared helpers for IssueUploadGrants service specs — kept top-level so each
# describe stays readable. The AWS Gateway is built in stub mode so presigned
# POST policy docs decode to their real contents (R-P1, R-P7); the
# RecordingGateway lets tests assert call shape without a real S3 round-trip.
module IssueUploadGrantsSpecSupport
  TEST_BUCKET = 'tyto-test-bucket'

  def stub_aws_gateway
    client = Aws::S3::Client.new(
      stub_responses: true,
      region: 'us-east-1',
      access_key_id: 'AKIA-TEST',
      secret_access_key: 'TEST-SECRET'
    )
    Tyto::FileStorage::Gateway.new(client:, bucket: TEST_BUCKET)
  end

  def recording_gateway
    RecordingGateway.new
  end

  # Records every presign_upload call so tests can assert on call shape
  # (key, allowed_extensions, call count) without round-tripping through AWS.
  class RecordingGateway
    include Dry::Monads[:result]

    attr_reader :calls

    def initialize
      @calls = []
    end

    def presign_upload(key:, allowed_extensions: nil)
      # Record the underlying string so tests can assert against String
      # literals — IssueUploadGrants now passes a Tyto::FileStorage::StorageKey.
      @calls << { key: key.to_s, allowed_extensions: }
      Success(upload_url: 'https://example.invalid/upload', fields: { 'key' => key.to_s })
    end
  end

  def decode_post_policy(fields)
    policy_b64 = fields['policy'] || fields[:policy]
    JSON.parse(Base64.decode64(policy_b64))
  end
end

describe Tyto::Service::Assignments::IssueUploadGrants do
  include IssueUploadGrantsSpecSupport

  let(:owner_account)   { Tyto::Account.create(email: 'owner@example.com',   name: 'Owner') }
  let(:student_account) { Tyto::Account.create(email: 'student@example.com', name: 'Student') }
  let(:other_student)   { Tyto::Account.create(email: 'other@example.com',   name: 'Other Student') }
  let(:owner_role)   { Tyto::Role.first(name: 'owner') }
  let(:student_role) { Tyto::Role.first(name: 'student') }
  let(:course) { Tyto::Course.create(name: 'Test Course') }

  let(:assignment) do
    Tyto::Assignment.create(
      course_id: course.id, title: 'HW 1', status: 'published',
      due_at: Time.now + 7 * 86_400, allow_late_resubmit: false
    )
  end

  let(:file_requirement) do
    Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id, submission_format: 'file',
      description: 'R Markdown source', allowed_types: 'rmd,qmd', sort_order: 0
    )
  end

  let(:url_requirement) do
    Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id, submission_format: 'url',
      description: 'GitHub repo link', sort_order: 1
    )
  end

  before do
    Tyto::AccountCourse.create(course_id: course.id, account_id: owner_account.id,   role_id: owner_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: student_account.id, role_id: student_role.id)
    Tyto::AccountCourse.create(course_id: course.id, account_id: other_student.id,   role_id: student_role.id)
  end

  let(:student_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student_account.id, roles: ['member'])
  end
  let(:owner_requestor) do
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: owner_account.id, roles: ['member'])
  end

  describe '#call success path' do
    it 'returns one entry per requested upload, each with requirement_id, key, upload_url, and fields' do
      file_requirement
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'homework1.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: stub_aws_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      payload = result.value!.message
      _(payload).must_be_kind_of Array
      _(payload.size).must_equal 1
      entry = payload.first
      _(entry[:requirement_id]).must_equal file_requirement.id
      _(entry[:key]).must_be_kind_of String
      _(entry[:upload_url]).must_be_kind_of String
      _(entry[:fields]).must_be_kind_of Hash
    end

    it 'builds the S3 key from authenticated account_id, requirement_id, and filename extension' do
      file_requirement
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: stub_aws_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      key = result.value!.message.first[:key]
      _(key).must_equal "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.rmd"
    end

    it 'returns one presigned entry per upload when multiple are requested' do
      req1 = file_requirement
      req2 = Tyto::SubmissionRequirement.create(
        assignment_id: assignment.id, submission_format: 'file',
        description: 'PDF report', allowed_types: 'pdf', sort_order: 2
      )
      uploads = [
        { 'requirement_id' => req1.id, 'filename' => 'a.Rmd' },
        { 'requirement_id' => req2.id, 'filename' => 'b.pdf' }
      ]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: stub_aws_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      _(result.value!.message.size).must_equal 2
      _(result.value!.message.map { |e| e[:requirement_id] }).must_equal [req1.id, req2.id]
    end
  end

  describe '#call security — server-side key reconstruction (R-P2)' do
    it 'ignores any account_id supplied in the body and uses the authenticated requestor instead' do
      file_requirement
      uploads = [{
        'requirement_id' => file_requirement.id,
        'filename'       => 'work.Rmd',
        # Attempt to inject another student's account_id into the key:
        'account_id'     => other_student.id
      }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: stub_aws_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      key = result.value!.message.first[:key]
      _(key).must_include "/#{student_account.id}."
      _(key).wont_include "/#{other_student.id}."
    end

    it 'ignores any client-supplied key and constructs its own' do
      file_requirement
      uploads = [{
        'requirement_id' => file_requirement.id,
        'filename'       => 'work.Rmd',
        'key'            => "999/999/#{other_student.id}.rmd"
      }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: stub_aws_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
      key = result.value!.message.first[:key]
      _(key).must_equal "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.rmd"
    end

    it 'forwards the reconstructed key (not any client value) to the gateway' do
      file_requirement
      recorder = recording_gateway
      uploads = [{
        'requirement_id' => file_requirement.id,
        'filename'       => 'work.Rmd',
        'account_id'     => other_student.id
      }]

      Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recorder).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(recorder.calls.size).must_equal 1
      _(recorder.calls.first[:key])
        .must_equal "#{assignment.id}/#{file_requirement.id}/#{student_account.id}.rmd"
    end
  end

  describe '#call presigned-POST policy (R-P1, R-P7)' do
    it 'embeds content-length-range = MAX_SIZE_BYTES in the signed policy' do
      file_requirement
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: stub_aws_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      fields = result.value!.message.first[:fields]
      policy = decode_post_policy(fields)
      size_cond = policy['conditions'].find { |c| c.is_a?(Array) && c.first == 'content-length-range' }
      _(size_cond).wont_be_nil
      _(size_cond[2]).must_equal Tyto::FileStorage::MAX_SIZE_BYTES
    end

    it 'forwards the requirement\'s allowed extensions to the gateway' do
      file_requirement # allowed_types: 'rmd,qmd'
      recorder = recording_gateway
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'work.Rmd' }]

      Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recorder).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      forwarded = recorder.calls.first[:allowed_extensions]
      _(forwarded).wont_be_nil
      _(forwarded.map { |e| e.delete_prefix('.').downcase }.sort).must_equal %w[qmd rmd]
    end
  end

  describe '#call authorization' do
    it 'forbids teaching staff (only students can submit)' do
      file_requirement
      recorder = recording_gateway
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recorder).call(
        requestor: owner_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
      _(recorder.calls).must_be_empty
    end

    it 'forbids a requestor who is not enrolled in the course' do
      file_requirement
      stranger = Tyto::Account.create(email: 'stranger@example.com', name: 'Stranger')
      stranger_requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(
        account_id: stranger.id, roles: ['member']
      )
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: stranger_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :forbidden
    end
  end

  describe '#call validation' do
    it 'rejects URL-type requirements (only file-type get presigned uploads)' do
      url_requirement
      recorder = recording_gateway
      uploads = [{ 'requirement_id' => url_requirement.id, 'filename' => 'link.url' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recorder).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
      _(recorder.calls).must_be_empty
    end

    it 'rejects an unknown requirement_id' do
      file_requirement
      uploads = [{ 'requirement_id' => 999_999, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'rejects a filename whose extension is not in allowed_types' do
      file_requirement # allowed_types: 'rmd,qmd'
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'report.pdf' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'accepts allowed extensions case-insensitively (.RMD matches "rmd")' do
      file_requirement
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'WORK.RMD' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: stub_aws_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Success
    end

    it 'rejects a filename with no extension' do
      file_requirement
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'no_extension' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'rejects an empty uploads array' do
      file_requirement
      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads: []
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'returns 404 when course does not exist' do
      file_requirement
      uploads = [{ 'requirement_id' => file_requirement.id, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: 999_999,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'returns 404 when assignment does not exist' do
      uploads = [{ 'requirement_id' => 1, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: 999_999, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :not_found
    end

    it 'rejects upload requests for an unpublished assignment' do
      draft_assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft', status: 'draft', allow_late_resubmit: false
      )
      draft_req = Tyto::SubmissionRequirement.create(
        assignment_id: draft_assignment.id, submission_format: 'file',
        description: 'Source', allowed_types: 'rmd', sort_order: 0
      )
      uploads = [{ 'requirement_id' => draft_req.id, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: draft_assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end

    it 'rejects an upload entry whose requirement belongs to a different assignment' do
      other_assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Other', status: 'published', allow_late_resubmit: false
      )
      foreign_req = Tyto::SubmissionRequirement.create(
        assignment_id: other_assignment.id, submission_format: 'file',
        description: 'Source', allowed_types: 'rmd', sort_order: 0
      )
      uploads = [{ 'requirement_id' => foreign_req.id, 'filename' => 'work.Rmd' }]

      result = Tyto::Service::Assignments::IssueUploadGrants.new(gateway: recording_gateway).call(
        requestor: student_requestor, course_id: course.id,
        assignment_id: assignment.id, uploads:
      )

      _(result).must_be_kind_of Dry::Monads::Result::Failure
      _(result.failure.status).must_equal :bad_request
    end
  end
end
