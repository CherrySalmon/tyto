# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Assignment Routes' do
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

  describe 'POST /api/course/:id/assignments' do
    it 'creates assignment as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      payload = {
        title: 'Homework 1',
        description: 'First assignment',
        submission_requirements: [
          { submission_format: 'file', description: 'Source code', allowed_types: 'rb,py' }
        ]
      }

      post "/api/course/#{course.id}/assignments", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
      _(json_response['message']).must_equal 'Assignment created'
      _(json_response['assignment_info']).wont_be_nil
      _(json_response['assignment_info']['id']).must_be_kind_of Integer
      _(json_response['assignment_info']['course_id']).must_equal course.id
      _(json_response['assignment_info']['title']).must_equal 'Homework 1'
      _(json_response['assignment_info']['status']).must_equal 'draft'
      _(json_response['assignment_info']['submission_requirements']).must_be_kind_of Array
      _(json_response['assignment_info']['submission_requirements'].length).must_equal 1
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      payload = { title: 'Forbidden Assignment' }

      post "/api/course/#{course.id}/assignments", payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 403
    end

    it 'returns bad request with invalid JSON' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      post "/api/course/#{course.id}/assignments", 'invalid json', json_headers(auth)

      _(last_response.status).must_equal 400
      _(json_response['error']).must_equal 'Invalid JSON'
    end
  end

  describe 'GET /api/course/:id/assignments' do
    it 'lists all assignments for teaching staff' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      Tyto::Assignment.create(
        course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false
      )
      Tyto::Assignment.create(
        course_id: course.id, title: 'Published HW', status: 'published', allow_late_resubmit: false
      )

      get "/api/course/#{course.id}/assignments", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_equal 2
    end

    it 'includes policies for teaching staff' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'draft', allow_late_resubmit: false
      )

      get "/api/course/#{course.id}/assignments", nil, auth

      policies = json_response['data'].first['policies']
      _(policies).wont_be_nil
      _(policies['can_create']).must_equal true
      _(policies['can_update']).must_equal true
      _(policies['can_delete']).must_equal true
      _(policies['can_submit']).must_equal false
    end

    it 'includes policies for students' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      Tyto::Assignment.create(
        course_id: course.id, title: 'Published HW', status: 'published', allow_late_resubmit: false
      )

      get "/api/course/#{course.id}/assignments", nil, student_auth

      policies = json_response['data'].first['policies']
      _(policies).wont_be_nil
      _(policies['can_create']).must_equal false
      _(policies['can_update']).must_equal false
      _(policies['can_submit']).must_equal true
    end

    it 'lists only published assignments for students' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      Tyto::Assignment.create(
        course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false
      )
      Tyto::Assignment.create(
        course_id: course.id, title: 'Published HW', status: 'published', allow_late_resubmit: false
      )

      get "/api/course/#{course.id}/assignments", nil, student_auth

      _(last_response.status).must_equal 200
      _(json_response['data'].length).must_equal 1
      _(json_response['data'].first['title']).must_equal 'Published HW'
    end

    it 'returns forbidden for non-enrolled user' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      _, other_auth = authenticated_header(roles: ['creator'])

      get "/api/course/#{course.id}/assignments", nil, other_auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'GET /api/course/:id/assignments/:assignment_id' do
    it 'returns published assignment with requirements for enrolled user' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published HW', status: 'published', allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: assignment.id, submission_format: 'file',
        description: 'Source code', sort_order: 0
      )

      get "/api/course/#{course.id}/assignments/#{assignment.id}", nil, student_auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']['id']).must_equal assignment.id
      _(json_response['data']['title']).must_equal 'Published HW'
      _(json_response['data']['submission_requirements']).must_be_kind_of Array
      _(json_response['data']['submission_requirements'].length).must_equal 1
    end

    it 'includes policies in response' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'draft', allow_late_resubmit: false
      )

      get "/api/course/#{course.id}/assignments/#{assignment.id}", nil, auth

      _(last_response.status).must_equal 200
      policies = json_response['data']['policies']
      _(policies).wont_be_nil
      _(policies['can_update']).must_equal true
      _(policies['can_publish']).must_equal true
    end

    it 'returns not found when student tries to view draft' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false
      )

      get "/api/course/#{course.id}/assignments/#{assignment.id}", nil, student_auth

      _(last_response.status).must_equal 404
    end

    it 'returns not found for non-existent assignment' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      get "/api/course/#{course.id}/assignments/999999", nil, auth

      _(last_response.status).must_equal 404
    end
  end

  describe 'PUT /api/course/:id/assignments/:assignment_id' do
    it 'updates assignment as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Original', status: 'draft', allow_late_resubmit: false
      )

      payload = { title: 'Updated Title', description: 'New description' }

      put "/api/course/#{course.id}/assignments/#{assignment.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_be_kind_of String
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'draft', allow_late_resubmit: false
      )

      payload = { title: 'Hacked' }

      put "/api/course/#{course.id}/assignments/#{assignment.id}", payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 403
    end

    it 'updates requirements for draft assignment' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft', status: 'draft', allow_late_resubmit: false
      )
      Tyto::SubmissionRequirement.create(
        assignment_id: assignment.id, submission_format: 'file',
        description: 'Old req', sort_order: 0
      )

      payload = {
        title: 'Updated',
        submission_requirements: [
          { submission_format: 'url', description: 'New URL req' }
        ]
      }

      put "/api/course/#{course.id}/assignments/#{assignment.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 200
    end

    it 'rejects requirements update for published assignment' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published', status: 'published', allow_late_resubmit: false
      )

      payload = {
        submission_requirements: [
          { submission_format: 'file', description: 'Sneaky' }
        ]
      }

      put "/api/course/#{course.id}/assignments/#{assignment.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 400
    end

    it 'returns not found for non-existent assignment' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      payload = { title: 'Ghost' }

      put "/api/course/#{course.id}/assignments/999999", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 404
    end
  end

  describe 'DELETE /api/course/:id/assignments/:assignment_id' do
    it 'deletes draft assignment as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft to Delete', status: 'draft', allow_late_resubmit: false
      )

      delete "/api/course/#{course.id}/assignments/#{assignment.id}", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_be_kind_of String
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'draft', allow_late_resubmit: false
      )

      delete "/api/course/#{course.id}/assignments/#{assignment.id}", nil, student_auth

      _(last_response.status).must_equal 403
    end

    it 'returns not found for non-existent assignment' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      delete "/api/course/#{course.id}/assignments/999999", nil, auth

      _(last_response.status).must_equal 404
    end
  end

  describe 'POST /api/course/:id/assignments/:assignment_id/unpublish' do
    it 'unpublishes published assignment as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published HW', status: 'published', allow_late_resubmit: false
      )

      post "/api/course/#{course.id}/assignments/#{assignment.id}/unpublish", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_be_kind_of String
      _(Tyto::Assignment[assignment.id].status).must_equal 'draft'
    end

    it 'returns bad request when unpublishing draft assignment' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft', status: 'draft', allow_late_resubmit: false
      )

      post "/api/course/#{course.id}/assignments/#{assignment.id}/unpublish", nil, auth

      _(last_response.status).must_equal 400
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'published', allow_late_resubmit: false
      )

      post "/api/course/#{course.id}/assignments/#{assignment.id}/unpublish", nil, student_auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'POST /api/course/:id/assignments/:assignment_id/publish' do
    it 'publishes draft assignment as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Draft HW', status: 'draft', allow_late_resubmit: false
      )

      post "/api/course/#{course.id}/assignments/#{assignment.id}/publish", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_be_kind_of String
    end

    it 'returns bad request when publishing already published assignment' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'Published', status: 'published', allow_late_resubmit: false
      )

      post "/api/course/#{course.id}/assignments/#{assignment.id}/publish", nil, auth

      _(last_response.status).must_equal 400
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      assignment = Tyto::Assignment.create(
        course_id: course.id, title: 'HW', status: 'draft', allow_late_resubmit: false
      )

      post "/api/course/#{course.id}/assignments/#{assignment.id}/publish", nil, student_auth

      _(last_response.status).must_equal 403
    end
  end
end
