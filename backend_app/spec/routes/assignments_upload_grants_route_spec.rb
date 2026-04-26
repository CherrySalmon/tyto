# frozen_string_literal: true

require_relative '../spec_helper'

# 3.8b — POST /api/course/:course_id/assignments/:assignment_id/upload_grants (red).
#
# This is the presign endpoint that mints short-lived upload credentials before
# the frontend form-POSTs files directly to S3 (or LocalGateway in dev/test).
# The route delegates to Service::Assignments::IssueUploadGrants (R-P10) and
# never returns a key the client can choose — keys are reconstructed server-side
# from authenticated context (R-P2).
#
# Spec coverage:
#   - 201 with array of {requirement_id, key, upload_url, fields}
#   - 403 for wrong role (teaching staff cannot mint student credentials)
#   - 403 for non-enrolled requestor
#   - 400 on invalid JSON body
#   - 400 on missing/empty uploads
#   - 400 on URL-type requirement (not a file)
#   - 404 for missing assignment
#   - key in response is built from the authenticated account_id, never from a
#     body-supplied account_id (R-P2 — defence-in-depth at the route layer)

describe 'Assignments Upload Grants Route' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  def upload_grants_url(course_id, assignment_id)
    "/api/course/#{course_id}/assignments/#{assignment_id}/upload_grants"
  end

  def create_test_course(owner_account, name: 'Test Course')
    course = Tyto::Course.create(name: name)
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(
      course_id: course.id, account_id: owner_account.id, role_id: owner_role.id
    )
    course
  end

  def enroll_student(course, student_account)
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(
      course_id: course.id, account_id: student_account.id, role_id: student_role.id
    )
  end

  def create_published_assignment(course)
    assignment = Tyto::Assignment.create(
      course_id: course.id, title: 'HW 1', status: 'published', allow_late_resubmit: false
    )
    file_req = Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id, submission_format: 'file',
      description: 'R Markdown source', allowed_types: 'rmd,qmd', sort_order: 0
    )
    url_req = Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id, submission_format: 'url',
      description: 'GitHub repo link', sort_order: 1
    )
    [assignment, file_req, url_req]
  end

  describe 'POST /api/course/:id/assignments/:aid/upload_grants' do
    it 'returns 201 with one presigned upload entry per requested file (success path)' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, file_req, _url_req = create_published_assignment(course)

      payload = { uploads: [{ requirement_id: file_req.id, filename: 'work.Rmd' }] }

      post upload_grants_url(course.id, assignment.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_equal 1
      entry = json_response['data'].first
      _(entry['requirement_id']).must_equal file_req.id
      _(entry['key']).must_be_kind_of String
      _(entry['upload_url']).must_be_kind_of String
      _(entry['fields']).must_be_kind_of Hash
    end

    it 'reconstructs the S3 key server-side from the authenticated account_id (R-P2)' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, file_req, _ = create_published_assignment(course)
      other_student = create_test_account(roles: ['student'])
      enroll_student(course, other_student)

      # Body tries to inject other_student's id; route must ignore it.
      payload = {
        uploads: [
          { requirement_id: file_req.id, filename: 'work.Rmd', account_id: other_student.id }
        ]
      }
      post upload_grants_url(course.id, assignment.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 201
      key = json_response['data'].first['key']
      _(key).must_equal "#{assignment.id}/#{file_req.id}/#{student_account.id}.rmd"
    end

    it 'returns 403 when teaching staff requests upload URLs (only students can submit)' do
      _, owner_auth = authenticated_header(roles: ['creator'])
      course = create_test_course(create_test_account(roles: ['creator']))
      assignment, file_req, _ = create_published_assignment(course)

      payload = { uploads: [{ requirement_id: file_req.id, filename: 'work.Rmd' }] }
      post upload_grants_url(course.id, assignment.id), payload.to_json, json_headers(owner_auth)

      _(last_response.status).must_equal 403
    end

    it 'returns 403 for a requestor who is not enrolled in the course' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, file_req, _ = create_published_assignment(course)
      _, outsider_auth = authenticated_header(roles: ['student'])

      payload = { uploads: [{ requirement_id: file_req.id, filename: 'work.Rmd' }] }
      post upload_grants_url(course.id, assignment.id), payload.to_json, json_headers(outsider_auth)

      _(last_response.status).must_equal 403
    end

    it 'returns 400 on invalid JSON body' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, _, _ = create_published_assignment(course)

      post upload_grants_url(course.id, assignment.id), 'not json', json_headers(student_auth)

      _(last_response.status).must_equal 400
    end

    it 'returns 400 when uploads array is missing or empty' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, _, _ = create_published_assignment(course)

      post upload_grants_url(course.id, assignment.id), { uploads: [] }.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 400
    end

    it 'returns 400 when an entry targets a URL-type requirement (file-type only)' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, _, url_req = create_published_assignment(course)

      payload = { uploads: [{ requirement_id: url_req.id, filename: 'link.url' }] }
      post upload_grants_url(course.id, assignment.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 400
    end

    it 'returns 400 when filename extension does not match allowed_types' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, file_req, _ = create_published_assignment(course)

      payload = { uploads: [{ requirement_id: file_req.id, filename: 'report.pdf' }] }
      post upload_grants_url(course.id, assignment.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 400
    end

    it 'returns 404 when the assignment does not exist' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)

      payload = { uploads: [{ requirement_id: 1, filename: 'work.Rmd' }] }
      post upload_grants_url(course.id, 999_999), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 404
    end

    it 'returns 400 when the assignment exists but is in draft status' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)

      draft = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft', status: 'draft', allow_late_resubmit: false
      )
      draft_req = Tyto::SubmissionRequirement.create(
        assignment_id: draft.id, submission_format: 'file',
        description: 'Source', allowed_types: 'rmd', sort_order: 0
      )

      payload = { uploads: [{ requirement_id: draft_req.id, filename: 'work.Rmd' }] }
      post upload_grants_url(course.id, draft.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 400
    end

  end
end
