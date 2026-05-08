# frozen_string_literal: true

require_relative '../spec_helper'

# GET /api/course/:course_id/assignments/:assignment_id/submissions/:submission_id/uploads/:upload_id/download
#
# Authorizes the requestor and 302-redirects to a freshly-minted presigned GET.
# Render-time presigned URLs are deliberately avoided — long-open staff views
# would silently expire them. The redirect mints credentials per click.
#
# Authorization mirrors GetSubmission: the submitter can view their own; teaching
# staff can view any submission in the course. Anything else is 403. URL-type
# uploads have no storage and respond 404.

describe 'Upload Download Route' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  def create_test_course(owner_account, name: 'Test Course')
    course = Tyto::Course.create(name: name)
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(
      course_id: course.id, account_id: owner_account.id, role_id: owner_role.id
    )
    course
  end

  def enroll(course, account, role:)
    role_record = Tyto::Role.find(name: role)
    Tyto::AccountCourse.create(
      course_id: course.id, account_id: account.id, role_id: role_record.id
    )
  end

  def create_published_assignment(course)
    assignment = Tyto::Assignment.create(
      course_id: course.id, title: 'HW 1', status: 'published', allow_late_resubmit: false
    )
    file_req = Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id, submission_format: 'file',
      description: 'Source', allowed_types: 'rb,py', sort_order: 0
    )
    url_req = Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id, submission_format: 'url',
      description: 'Repo link', sort_order: 1
    )
    [assignment, file_req, url_req]
  end

  # Lays bytes down on the LocalGateway at the server-reconstructed key,
  # then creates the submission row + entry row pointing at that key.
  def create_file_submission(assignment:, requirement:, account:, filename: 'solution.rb')
    key = Tyto::FileStorage::SubmissionMapper.build_key(
      course_id: assignment.course_id, assignment_id: assignment.id,
      requirement_id: requirement.id, account_id: account.id,
      filename:, submission_format: 'file'
    )
    Tyto::FileStorage.build_gateway.write(key:, body: 'student bytes')

    submission = Tyto::Submission.create(
      assignment_id: assignment.id, account_id: account.id, submitted_at: Time.now.utc
    )
    entry = Tyto::SubmissionEntry.create(
      submission_id: submission.id, requirement_id: requirement.id,
      content: key.to_s, filename: filename, content_type: 'text/plain', file_size: 13
    )
    [submission, entry]
  end

  def create_url_entry(submission:, requirement:, url: 'https://github.com/me/repo')
    Tyto::SubmissionEntry.create(
      submission_id: submission.id, requirement_id: requirement.id,
      content: url, filename: nil, content_type: nil, file_size: nil
    )
  end

  def download_url(course_id, assignment_id, submission_id, upload_id)
    "/api/course/#{course_id}/assignments/#{assignment_id}/" \
      "submissions/#{submission_id}/uploads/#{upload_id}/download"
  end

  describe 'authorized requestors' do
    it 'redirects (302) the submitting student to a freshly-minted presigned GET' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student, student_auth = authenticated_header(roles: ['student'])
      enroll(course, student, role: 'student')
      assignment, file_req, _ = create_published_assignment(course)
      submission, entry = create_file_submission(
        assignment:, requirement: file_req, account: student
      )

      get download_url(course.id, assignment.id, submission.id, entry.id), {}, student_auth

      _(last_response.status).must_equal 302
      location = last_response.headers['Location']
      _(location).wont_be_nil
      _(location).must_include "#{assignment.id}/#{file_req.id}/#{student.id}.rb"
    end

    it 'redirects (302) teaching staff (instructor) for any submission in the course' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student = create_test_account(roles: ['student'])
      enroll(course, student, role: 'student')
      instructor, instructor_auth = authenticated_header(roles: ['creator'])
      enroll(course, instructor, role: 'instructor')
      assignment, file_req, _ = create_published_assignment(course)
      submission, entry = create_file_submission(
        assignment:, requirement: file_req, account: student
      )

      get download_url(course.id, assignment.id, submission.id, entry.id), {}, instructor_auth

      _(last_response.status).must_equal 302
      _(last_response.headers['Location']).wont_be_nil
    end

    it 'mints a fresh presigned URL on each request (token differs)' do
      # The route must NOT cache the presigned URL — each click gets a new TTL.
      # LocalGateway tokens carry a per-mint nonce; AWS presigned URLs vary by
      # signature timestamp. Either way two consecutive Locations should differ.
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student, student_auth = authenticated_header(roles: ['student'])
      enroll(course, student, role: 'student')
      assignment, file_req, _ = create_published_assignment(course)
      submission, entry = create_file_submission(
        assignment:, requirement: file_req, account: student
      )

      get download_url(course.id, assignment.id, submission.id, entry.id), {}, student_auth
      first = last_response.headers['Location']
      get download_url(course.id, assignment.id, submission.id, entry.id), {}, student_auth
      second = last_response.headers['Location']

      _(first).wont_be_nil
      _(second).wont_be_nil
      _(first).wont_equal second
    end
  end

  describe 'unauthorized requestors' do
    it 'returns 403 to a non-submitting student in the same course' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      submitter = create_test_account(roles: ['student'])
      enroll(course, submitter, role: 'student')
      peeker, peeker_auth = authenticated_header(roles: ['student'])
      enroll(course, peeker, role: 'student')
      assignment, file_req, _ = create_published_assignment(course)
      submission, entry = create_file_submission(
        assignment:, requirement: file_req, account: submitter
      )

      get download_url(course.id, assignment.id, submission.id, entry.id), {}, peeker_auth

      _(last_response.status).must_equal 403
    end

    it 'returns 403 to a stranger not enrolled in the course' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      submitter = create_test_account(roles: ['student'])
      enroll(course, submitter, role: 'student')
      _, stranger_auth = authenticated_header(roles: ['student']) # no enrollment
      assignment, file_req, _ = create_published_assignment(course)
      submission, entry = create_file_submission(
        assignment:, requirement: file_req, account: submitter
      )

      get download_url(course.id, assignment.id, submission.id, entry.id), {}, stranger_auth

      _(last_response.status).must_equal 403
    end

    it 'does not leak the presigned URL in the response body or any header' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      submitter = create_test_account(roles: ['student'])
      enroll(course, submitter, role: 'student')
      _, stranger_auth = authenticated_header(roles: ['student'])
      assignment, file_req, _ = create_published_assignment(course)
      submission, entry = create_file_submission(
        assignment:, requirement: file_req, account: submitter
      )

      get download_url(course.id, assignment.id, submission.id, entry.id), {}, stranger_auth

      # The reconstructed key embeds the submitter's account_id — its presence in
      # body or any header would prove the presigned URL leaked downstream.
      key_fragment = "#{assignment.id}/#{file_req.id}/#{submitter.id}.rb"
      _(last_response.body).wont_include key_fragment
      header_blob = last_response.headers.map { |k, v| "#{k}: #{v}" }.join("\n")
      _(header_blob).wont_include key_fragment
    end
  end

  describe 'not found cases' do
    it 'returns 404 when upload_id does not exist' do
      _, student_auth = authenticated_header(roles: ['student'])
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      assignment, _, _ = create_published_assignment(course)

      get download_url(course.id, assignment.id, 99_999, 88_888), {}, student_auth

      _(last_response.status).must_equal 404
    end

    it 'returns 404 when the upload belongs to a different submission' do
      # Cross-submission attack: upload_id exists but isn't part of submission_id.
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student_a = create_test_account(roles: ['student'])
      enroll(course, student_a, role: 'student')
      student_b, student_b_auth = authenticated_header(roles: ['student'])
      enroll(course, student_b, role: 'student')
      assignment, file_req, _ = create_published_assignment(course)
      _, entry_a = create_file_submission(
        assignment:, requirement: file_req, account: student_a
      )
      submission_b, _ = create_file_submission(
        assignment:, requirement: file_req, account: student_b, filename: 'mine.rb'
      )

      # student_b asks for student_a's entry under their own submission_id
      get download_url(course.id, assignment.id, submission_b.id, entry_a.id), {}, student_b_auth

      _(last_response.status).must_equal 404
    end

    it 'returns 404 for a URL-type upload (no storage to redirect to)' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student, student_auth = authenticated_header(roles: ['student'])
      enroll(course, student, role: 'student')
      assignment, file_req, url_req = create_published_assignment(course)
      submission, _ = create_file_submission(
        assignment:, requirement: file_req, account: student
      )
      url_entry = create_url_entry(submission:, requirement: url_req)

      get download_url(course.id, assignment.id, submission.id, url_entry.id), {}, student_auth

      _(last_response.status).must_equal 404
    end
  end
end
