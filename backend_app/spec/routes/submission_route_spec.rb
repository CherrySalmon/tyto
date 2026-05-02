# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Submission Routes' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  def create_test_course(owner_account, name: 'Test Course')
    course = Tyto::Course.create(name: name)
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(
      course_id: course.id,
      account_id: owner_account.id,
      role_id: owner_role.id
    )
    course
  end

  def enroll_student(course, student_account)
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(
      course_id: course.id,
      account_id: student_account.id,
      role_id: student_role.id
    )
  end

  def create_published_assignment(course, title: 'Published HW')
    assignment = Tyto::Assignment.create(
      course_id: course.id, title: title, status: 'published',
      allow_late_resubmit: false
    )
    req = Tyto::SubmissionRequirement.create(
      assignment_id: assignment.id, submission_format: 'file',
      description: 'Source code', allowed_types: 'rb,py', sort_order: 0
    )
    [assignment, req]
  end

  def submission_url(course_id, assignment_id)
    "/api/course/#{course_id}/assignments/#{assignment_id}/submissions"
  end

  # Mirrors the real client → presign → upload flow: lays the bytes down on
  # the LocalGateway at the server-reconstructed key so the service's
  # HEAD-check passes when the route runs.
  def materialize_upload(assignment:, requirement:, account:, filename:)
    key = Tyto::FileStorage::SubmissionMapper.build_key(
      assignment_id: assignment.id, requirement_id: requirement.id,
      account_id: account.id, filename:, submission_format: 'file'
    )
    Tyto::FileStorage.build_gateway.write(key:, body: 'test bytes')
    key
  end

  describe 'POST /api/course/:id/assignments/:aid/submissions' do
    it 'creates submission as enrolled student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, req = create_published_assignment(course)
      materialize_upload(assignment:, requirement: req, account: student_account, filename: 'solution.rb')

      payload = {
        entries: [
          { requirement_id: req.id, filename: 'solution.rb',
            content_type: 'text/plain', file_size: 1024 }
        ]
      }

      post submission_url(course.id, assignment.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
      _(json_response['data']).wont_be_nil
      _(json_response['data']['id']).must_be_kind_of Integer
      _(json_response['data']['assignment_id']).must_equal assignment.id
      _(json_response['data']['account_id']).must_equal student_account.id
      _(json_response['data']['requirement_uploads']).must_be_kind_of Array
      _(json_response['data']['requirement_uploads'].length).must_equal 1
    end

    it 'includes policies in submission response' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, req = create_published_assignment(course)
      materialize_upload(assignment:, requirement: req, account: student_account, filename: 'solution.rb')

      payload = {
        entries: [
          { requirement_id: req.id, filename: 'solution.rb',
            content_type: 'text/plain', file_size: 1024 }
        ]
      }

      post submission_url(course.id, assignment.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 201
      policies = json_response['data']['policies']
      _(policies).wont_be_nil
      _(policies['can_submit']).must_equal true
      _(policies['can_view_own']).must_equal true
      _(policies['can_view_all']).must_equal false
    end

    it 'overwrites existing submission on resubmit' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, req = create_published_assignment(course)
      # Both submissions use a `.rb` file, so the reconstructed key is the
      # same — one materialize call covers both posts.
      materialize_upload(assignment:, requirement: req, account: student_account, filename: 'v1.rb')

      payload = {
        entries: [
          { requirement_id: req.id, filename: 'v1.rb',
            content_type: 'text/plain', file_size: 512 }
        ]
      }
      post submission_url(course.id, assignment.id), payload.to_json, json_headers(student_auth)
      _(last_response.status).must_equal 201
      first_id = json_response['data']['id']

      # Resubmit
      payload2 = {
        entries: [
          { requirement_id: req.id, filename: 'v2.rb',
            content_type: 'text/plain', file_size: 768 }
        ]
      }
      post submission_url(course.id, assignment.id), payload2.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 201
      # Same submission ID (overwrite, not new)
      _(json_response['data']['id']).must_equal first_id
    end

    it 'returns forbidden for teaching staff' do
      owner_account, owner_auth = authenticated_header(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, _req = create_published_assignment(course)

      payload = { entries: [{ requirement_id: 1, content: 'x' }] }
      post submission_url(course.id, assignment.id), payload.to_json, json_headers(owner_auth)

      _(last_response.status).must_equal 403
    end

    it 'returns forbidden for non-enrolled user' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      _, outsider_auth = authenticated_header(roles: ['student'])
      assignment, _req = create_published_assignment(course)

      payload = { entries: [{ requirement_id: 1, content: 'x' }] }
      post submission_url(course.id, assignment.id), payload.to_json, json_headers(outsider_auth)

      _(last_response.status).must_equal 403
    end

    it 'rejects submission for draft assignment' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)

      draft = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft', status: 'draft', allow_late_resubmit: false
      )

      payload = { entries: [{ requirement_id: 1, content: 'x' }] }
      post submission_url(course.id, draft.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 400
    end

    it 'rejects invalid file extension' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, req = create_published_assignment(course)

      payload = {
        entries: [
          { requirement_id: req.id, content: 's3/key/file.exe', filename: 'hack.exe',
            content_type: 'application/octet-stream', file_size: 1024 }
        ]
      }
      post submission_url(course.id, assignment.id), payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 400
    end

    it 'returns bad request with invalid JSON' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      assignment, _req = create_published_assignment(course)

      post submission_url(course.id, assignment.id), 'not json', json_headers(student_auth)

      _(last_response.status).must_equal 400
    end
  end

  describe 'GET /api/course/:id/assignments/:aid/submissions' do
    it 'lists all submissions for teaching staff' do
      owner_account, owner_auth = authenticated_header(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, req = create_published_assignment(course)

      # Create two student submissions via ORM
      student1 = create_test_account(roles: ['student'])
      enroll_student(course, student1)
      sub1 = Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student1.id, submitted_at: Time.now.utc
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub1.id, requirement_id: req.id,
        content: 's3/key1.rb', filename: 'sol1.rb'
      )

      student2 = create_test_account(roles: ['student'])
      enroll_student(course, student2)
      sub2 = Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student2.id, submitted_at: Time.now.utc
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub2.id, requirement_id: req.id,
        content: 's3/key2.rb', filename: 'sol2.rb'
      )

      get submission_url(course.id, assignment.id), nil, owner_auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_equal 2
    end

    it 'lists only own submission for student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, req = create_published_assignment(course)

      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      sub = Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now.utc
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub.id, requirement_id: req.id,
        content: 's3/key.rb', filename: 'sol.rb'
      )

      # Another student's submission
      other_student = create_test_account(roles: ['student'])
      enroll_student(course, other_student)
      Tyto::Submission.create(
        assignment_id: assignment.id, account_id: other_student.id, submitted_at: Time.now.utc
      )

      get submission_url(course.id, assignment.id), nil, student_auth

      _(last_response.status).must_equal 200
      _(json_response['data'].length).must_equal 1
      _(json_response['data'].first['account_id']).must_equal student_account.id
    end

    it 'includes policies in list response for teaching staff' do
      owner_account, owner_auth = authenticated_header(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, req = create_published_assignment(course)

      student = create_test_account(roles: ['student'])
      enroll_student(course, student)
      sub = Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student.id, submitted_at: Time.now.utc
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub.id, requirement_id: req.id,
        content: 's3/key.rb', filename: 'sol.rb'
      )

      get submission_url(course.id, assignment.id), nil, owner_auth

      _(last_response.status).must_equal 200
      policies = json_response['data'].first['policies']
      _(policies).wont_be_nil
      _(policies['can_submit']).must_equal false
      _(policies['can_view_all']).must_equal true
    end

    it 'returns empty array for student with no submission' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, _req = create_published_assignment(course)

      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)

      get submission_url(course.id, assignment.id), nil, student_auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_equal []
    end

    it 'returns forbidden for non-enrolled user' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, _req = create_published_assignment(course)
      _, outsider_auth = authenticated_header(roles: ['student'])

      get submission_url(course.id, assignment.id), nil, outsider_auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'GET /api/course/:id/assignments/:aid/submissions/:sid' do
    it 'returns own submission with entries for student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, req = create_published_assignment(course)

      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      sub = Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now.utc
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub.id, requirement_id: req.id,
        content: 's3/key.rb', filename: 'sol.rb', content_type: 'text/plain', file_size: 1024
      )

      get "#{submission_url(course.id, assignment.id)}/#{sub.id}", nil, student_auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']['id']).must_equal sub.id
      _(json_response['data']['requirement_uploads']).must_be_kind_of Array
      _(json_response['data']['requirement_uploads'].length).must_equal 1
      entry = json_response['data']['requirement_uploads'].first
      _(entry['content']).must_equal 's3/key.rb'
      _(entry['filename']).must_equal 'sol.rb'
    end

    it 'returns any submission for teaching staff' do
      owner_account, owner_auth = authenticated_header(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, req = create_published_assignment(course)

      student = create_test_account(roles: ['student'])
      enroll_student(course, student)
      sub = Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student.id, submitted_at: Time.now.utc
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub.id, requirement_id: req.id,
        content: 's3/key.rb', filename: 'sol.rb'
      )

      get "#{submission_url(course.id, assignment.id)}/#{sub.id}", nil, owner_auth

      _(last_response.status).must_equal 200
      _(json_response['data']['id']).must_equal sub.id
    end

    it 'includes policies in single submission response' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, req = create_published_assignment(course)

      student_account, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student_account)
      sub = Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student_account.id, submitted_at: Time.now.utc
      )
      Tyto::SubmissionEntry.create(
        submission_id: sub.id, requirement_id: req.id,
        content: 's3/key.rb', filename: 'sol.rb'
      )

      get "#{submission_url(course.id, assignment.id)}/#{sub.id}", nil, student_auth

      _(last_response.status).must_equal 200
      policies = json_response['data']['policies']
      _(policies).wont_be_nil
      _(policies['can_submit']).must_equal true
      _(policies['can_view_all']).must_equal false
    end

    it 'returns forbidden when student views another student submission' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, req = create_published_assignment(course)

      student1 = create_test_account(roles: ['student'])
      enroll_student(course, student1)
      sub = Tyto::Submission.create(
        assignment_id: assignment.id, account_id: student1.id, submitted_at: Time.now.utc
      )

      student2, student2_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student2)

      get "#{submission_url(course.id, assignment.id)}/#{sub.id}", nil, student2_auth

      _(last_response.status).must_equal 403
    end

    it 'returns not found for non-existent submission' do
      owner_account, owner_auth = authenticated_header(roles: ['creator'])
      course = create_test_course(owner_account)
      assignment, _req = create_published_assignment(course)

      get "#{submission_url(course.id, assignment.id)}/999999", nil, owner_auth

      _(last_response.status).must_equal 404
    end
  end

  # Locks the route → representer wiring so the frontend can rely on
  # `requirement_uploads[].download_url` showing up in JSON for file-type
  # entries. Without this assertion the contract is unit-tested only at
  # the representer level and would silently regress if a route forgot
  # to thread user_options.
  describe 'download_url wiring on submission JSON' do
    def create_assignment_with_mixed_requirements(course)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Mixed HW', status: 'published',
        allow_late_resubmit: false
      )
      file_req = Tyto::SubmissionRequirement.create(
        assignment_id: assignment.id, submission_format: 'file',
        description: 'Source', allowed_types: 'rb', sort_order: 0
      )
      url_req = Tyto::SubmissionRequirement.create(
        assignment_id: assignment.id, submission_format: 'url',
        description: 'Repo link', sort_order: 1
      )
      [assignment, file_req, url_req]
    end

    def submit_mixed(course:, assignment:, file_req:, url_req:, account:, auth:)
      materialize_upload(assignment:, requirement: file_req, account:, filename: 'main.rb')
      payload = {
        entries: [
          { requirement_id: file_req.id, filename: 'main.rb',
            content_type: 'text/plain', file_size: 7 },
          { requirement_id: url_req.id, content: 'https://github.com/me/repo' }
        ]
      }
      post submission_url(course.id, assignment.id), payload.to_json, json_headers(auth)
    end

    it 'emits download_url for file-type uploads on POST submission response' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student)
      assignment, file_req, url_req = create_assignment_with_mixed_requirements(course)

      submit_mixed(course:, assignment:, file_req:, url_req:, account: student, auth: student_auth)

      _(last_response.status).must_equal 201
      uploads = json_response['data']['requirement_uploads']
      file_entry = uploads.find { |u| u['requirement_id'] == file_req.id }
      url_entry  = uploads.find { |u| u['requirement_id'] == url_req.id }

      _(file_entry['download_url']).must_match(
        %r{\A/api/course/#{course.id}/assignments/#{assignment.id}/submissions/\d+/uploads/\d+/download\z}
      )
      _(url_entry['download_url']).must_be_nil
    end

    it 'emits download_url on GET single submission response' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      student, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student)
      assignment, file_req, url_req = create_assignment_with_mixed_requirements(course)

      submit_mixed(course:, assignment:, file_req:, url_req:, account: student, auth: student_auth)
      submission_id = json_response['data']['id']

      get "#{submission_url(course.id, assignment.id)}/#{submission_id}", nil, student_auth

      _(last_response.status).must_equal 200
      uploads = json_response['data']['requirement_uploads']
      file_entry = uploads.find { |u| u['requirement_id'] == file_req.id }
      _(file_entry['download_url']).must_match(
        %r{\A/api/course/#{course.id}/assignments/#{assignment.id}/submissions/#{submission_id}/uploads/\d+/download\z}
      )
    end

    it 'emits download_url on LIST submissions response (teaching staff)' do
      owner_account, owner_auth = authenticated_header(roles: ['creator'])
      course = create_test_course(owner_account)
      student, student_auth = authenticated_header(roles: ['student'])
      enroll_student(course, student)
      assignment, file_req, url_req = create_assignment_with_mixed_requirements(course)

      submit_mixed(course:, assignment:, file_req:, url_req:, account: student, auth: student_auth)

      get submission_url(course.id, assignment.id), nil, owner_auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_be_kind_of Array
      submission = json_response['data'].first
      file_entry = submission['requirement_uploads'].find { |u| u['requirement_id'] == file_req.id }
      _(file_entry['download_url']).must_match(
        %r{\A/api/course/#{course.id}/assignments/#{assignment.id}/submissions/#{submission['id']}/uploads/\d+/download\z}
      )
    end
  end
end
