# frozen_string_literal: true

require_relative '../spec_helper'
require 'stringio'
require 'uri'

# End-to-end integration: drives the same HTTP sequence the browser will run.
# Catches the hybrid-layer bugs that unit specs miss — request-body parsing,
# multipart form-POST handling, route-to-route plumbing, representer wiring,
# StorageKey reconstruction across the auth boundary.
#
#   1. POST /upload_grants                        — student mints upload credentials
#   2. POST /api/_local_storage/upload            — multipart form-POST (LocalGateway in dev/test)
#   3. POST /submissions                          — backend HEAD-checks the reconstructed key
#   4. GET  .../uploads/:id/download              — 302 to a freshly-minted presigned GET
#   5. GET  /api/_local_storage/download/<key>?token=... — bytes match the original upload
describe 'File upload flow (presign → upload → submit → download)' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  let(:owner)         { create_test_account(roles: ['creator']) }
  let(:file_bytes)    { "an .Rmd source file's bytes\n" }
  let(:filename)      { 'work.rmd' }
  let(:content_type)  { 'text/plain' }

  before do
    @student, @student_auth = authenticated_header(roles: ['student'])

    @course = Tyto::Course.create(name: 'Integration Course')
    Tyto::AccountCourse.create(
      course_id: @course.id, account_id: owner.id,
      role_id: Tyto::Role.find(name: 'owner').id
    )
    Tyto::AccountCourse.create(
      course_id: @course.id, account_id: @student.id,
      role_id: Tyto::Role.find(name: 'student').id
    )

    @assignment = Tyto::Assignment.create(
      course_id: @course.id, title: 'Submit your .Rmd', status: 'published',
      allow_late_resubmit: false
    )
    @file_req = Tyto::SubmissionRequirement.create(
      assignment_id: @assignment.id, submission_format: 'file',
      description: 'R Markdown source', allowed_types: 'rmd', sort_order: 0
    )
  end

  # LocalGateway writes survive transaction rollback. Clean up the specific
  # key each test might have written so a later test that relies on file
  # absence doesn't see ghost bytes (sqlite IDs reset across rolled-back
  # transactions, so two consecutive tests can land on the same key path).
  after do
    key = Tyto::FileStorage::SubmissionMapper.build_key(
      assignment_id: @assignment.id, requirement_id: @file_req.id,
      account_id: @student.id, filename: filename, submission_format: 'file'
    )
    Tyto::FileStorage.build_gateway.delete(key:)
  rescue StandardError
    nil
  end

  def path_of(url)
    parsed = URI.parse(url)
    parsed.query ? "#{parsed.path}?#{parsed.query}" : parsed.path
  end

  def issue_grant
    payload = { uploads: [{ requirement_id: @file_req.id, filename: }] }
    post "/api/course/#{@course.id}/assignments/#{@assignment.id}/upload_grants",
         payload.to_json, json_headers(@student_auth)

    _(last_response.status).must_equal 201
    json_response['data'].first
  end

  def upload_to_grant(grant)
    fields = grant['fields'].merge(
      'file' => Rack::Test::UploadedFile.new(
        StringIO.new(file_bytes), content_type, original_filename: filename
      )
    )
    post path_of(grant['upload_url']), fields

    _(last_response.status).must_equal 204
  end

  def post_submission
    payload = {
      entries: [{
        requirement_id: @file_req.id,
        filename: filename,
        content_type: content_type,
        file_size: file_bytes.bytesize
      }]
    }
    post "/api/course/#{@course.id}/assignments/#{@assignment.id}/submissions",
         payload.to_json, json_headers(@student_auth)

    _(last_response.status).must_equal 201
    json_response['data']
  end

  it 'drives the full presign → upload → submit → download path with matching bytes' do
    grant = issue_grant
    upload_to_grant(grant)

    submission = post_submission

    upload_entry = submission['requirement_uploads'].first
    _(upload_entry['download_url']).must_match(
      %r{\A/api/course/#{@course.id}/assignments/#{@assignment.id}/submissions/\d+/uploads/\d+/download\z}
    )

    get upload_entry['download_url'], nil, @student_auth
    _(last_response.status).must_equal 302
    presigned_path = path_of(last_response.headers['Location'])

    get presigned_path, nil, @student_auth
    _(last_response.status).must_equal 200
    _(last_response.body).must_equal file_bytes
  end

  it 'rejects the submission when the student skips the upload step (HEAD-check fires)' do
    # A frontend that calls /submissions without first PUTting bytes should
    # see a clean 400 from the HEAD-check, not a 500 or a phantom record.
    issue_grant # mint credentials but never upload

    payload = {
      entries: [{
        requirement_id: @file_req.id,
        filename: filename,
        content_type: content_type,
        file_size: file_bytes.bytesize
      }]
    }
    post "/api/course/#{@course.id}/assignments/#{@assignment.id}/submissions",
         payload.to_json, json_headers(@student_auth)

    _(last_response.status).must_equal 400
    _(last_response.body).must_include 'Uploaded file not found in storage'
  end
end
