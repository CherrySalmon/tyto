# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Course Routes' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  # Helper to create a course owned by a given account
  def create_test_course(owner_account, name: 'Test Course')
    course = Tyto::Course.create(
      name: name
    )
    # Enroll owner with 'owner' role
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(
      course_id: course.id,
      account_id: owner_account.id,
      role_id: owner_role.id
    )
    course
  end

  describe 'GET /api/course' do
    it 'returns enrolled courses for authenticated user' do
      account, auth = authenticated_header(roles: ['creator'])
      create_test_course(account, name: 'My Course')

      get '/api/course', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_be :>, 0

      course_data = json_response['data'].first
      _(course_data).must_include 'id'
      _(course_data).must_include 'name'
      _(course_data).must_include 'enroll_identity'
      _(course_data['id']).must_be_kind_of Integer
      _(course_data['name']).must_be_kind_of String
      _(course_data['enroll_identity']).must_be_kind_of Array
    end
  end

  describe 'GET /api/course/list_all' do
    it 'returns all courses for admin' do
      _, auth = authenticated_header(roles: ['admin'])

      get '/api/course/list_all', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
    end

    it 'returns forbidden for non-admin' do
      _, auth = authenticated_header(roles: ['creator'])

      get '/api/course/list_all', nil, auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'GET /api/course/:id' do
    it 'returns course for enrolled user' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      get "/api/course/#{course.id}", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true

      course_data = json_response['data']
      _(course_data['id']).must_equal course.id
      _(course_data['name']).must_be_kind_of String
      _(course_data).must_include 'created_at'
      _(course_data).must_include 'updated_at'
      _(course_data['enroll_identity']).must_be_kind_of Array
      _(course_data['enroll_identity']).must_include 'owner'
    end

    it 'returns forbidden for non-enrolled user' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      _, auth = authenticated_header(roles: ['creator'])

      get "/api/course/#{course.id}", nil, auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'POST /api/course' do
    it 'creates course with creator role' do
      _, auth = authenticated_header(roles: ['creator'])
      payload = { name: 'New Course' }

      post '/api/course', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
      _(json_response['message']).must_equal 'Course created'
      _(json_response['course_info']).wont_be_nil
      _(json_response['course_info']['id']).must_be_kind_of Integer
      _(json_response['course_info']['name']).must_equal 'New Course'
      _(json_response['course_info']).must_include 'created_at'
      _(json_response['course_info']).must_include 'updated_at'
      _(json_response['course_info']).must_include 'enroll_identity'
    end

    it 'returns forbidden without creator role' do
      _, auth = authenticated_header(roles: ['student'])
      payload = { name: 'Forbidden Course' }

      post '/api/course', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 403
    end

    it 'makes creator the owner of new course' do
      account, auth = authenticated_header(roles: ['creator'])
      payload = { name: 'Owned Course' }

      post '/api/course', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 201
      course_id = json_response['course_info']['id']

      # Verify enrollment exists with owner role
      enrollment = Tyto::AccountCourse.where(course_id: course_id, account_id: account.id).first
      _(enrollment).wont_be_nil
      _(enrollment.role.name).must_equal 'owner'
    end
  end

  describe 'PUT /api/course/:id' do
    it 'updates course as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)
      payload = { name: 'Updated Course Name' }

      put "/api/course/#{course.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_be_kind_of String
    end

    it 'updates course as instructor' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

      # Enroll as instructor
      instructor_role = Tyto::Role.find(name: 'instructor')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: instructor_account.id,
        role_id: instructor_role.id
      )

      payload = { logo: 'updated-logo.png' }
      put "/api/course/#{course.id}", payload.to_json, json_headers(instructor_auth)

      _(last_response.status).must_equal 200
    end

    it 'returns forbidden as student' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      student_account, student_auth = authenticated_header(roles: ['student'])

      # Enroll as student
      student_role = Tyto::Role.find(name: 'student')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: student_account.id,
        role_id: student_role.id
      )

      payload = { name: 'Hacked Name' }
      put "/api/course/#{course.id}", payload.to_json, json_headers(student_auth)

      _(last_response.status).must_equal 403
    end
  end

  describe 'DELETE /api/course/:id' do
    it 'deletes course as owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      delete "/api/course/#{course.id}", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_be_kind_of String
    end

    it 'deletes course as admin' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      _, admin_auth = authenticated_header(roles: ['admin'])

      delete "/api/course/#{course.id}", nil, admin_auth

      _(last_response.status).must_equal 200
    end

    it 'returns forbidden when requester is not the course owner (e.g., instructor or student)' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

      # Enroll as instructor
      instructor_role = Tyto::Role.find(name: 'instructor')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: instructor_account.id,
        role_id: instructor_role.id
      )

      delete "/api/course/#{course.id}", nil, instructor_auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'GET /api/course/:id/assignable_roles' do
    it 'returns all course roles for owner' do
      account, auth = authenticated_header(roles: ['creator'])
      course = create_test_course(account)

      get "/api/course/#{course.id}/assignable_roles", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data']).must_include 'owner'
      _(json_response['data']).must_include 'instructor'
      _(json_response['data']).must_include 'staff'
      _(json_response['data']).must_include 'student'
    end

    it 'returns limited roles for instructor' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      instructor_account, instructor_auth = authenticated_header(roles: ['member'])

      instructor_role = Tyto::Role.find(name: 'instructor')
      Tyto::AccountCourse.create(
        course_id: course.id,
        account_id: instructor_account.id,
        role_id: instructor_role.id
      )

      get "/api/course/#{course.id}/assignable_roles", nil, instructor_auth

      _(last_response.status).must_equal 200
      _(json_response['data']).must_include 'staff'
      _(json_response['data']).must_include 'student'
      _(json_response['data']).wont_include 'owner'
      _(json_response['data']).wont_include 'instructor'
    end

    it 'returns forbidden for non-enrolled user' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      _, other_auth = authenticated_header(roles: ['member'])

      get "/api/course/#{course.id}/assignable_roles", nil, other_auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'Course Enrollment' do
    describe 'POST /api/course/:id/enroll' do
      it 'enrolls users as owner' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)
        new_user = create_test_account(email: 'newstudent@test.com', roles: ['student'])

        payload = {
          enroll: [
            { email: new_user.email, roles: 'student' }
          ]
        }

        post "/api/course/#{course.id}/enroll", payload.to_json, json_headers(auth)

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['message']).must_be_kind_of String
      end

      it 'returns forbidden as student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        new_user = create_test_account(email: 'another@test.com')
        payload = {
          enroll: [
            { email: new_user.email, roles: 'student' }
          ]
        }

        post "/api/course/#{course.id}/enroll", payload.to_json, json_headers(student_auth)

        _(last_response.status).must_equal 403
      end

      it 'allows enrolled user to view course' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        get "/api/course/#{course.id}", nil, student_auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['data']['enroll_identity']).must_be_kind_of Array
        _(json_response['data']['enroll_identity']).must_include 'student'
      end
    end

    describe 'GET /api/course/:id/enroll' do
      it 'lists enrollments for enrolled users' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)

        get "/api/course/#{course.id}/enroll", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['data']).must_be_kind_of Array
        _(json_response['data'].length).must_be :>, 0

        enrollment = json_response['data'].first
        _(enrollment).must_include 'account'
        _(enrollment).must_include 'enroll_identity'
        _(enrollment['account']).must_include 'id'
        _(enrollment['account']).must_include 'email'
        _(enrollment['account']).must_include 'name'
        _(enrollment['enroll_identity']).must_be_kind_of Array
      end

      it 'returns forbidden for non-enrolled users' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        _, other_auth = authenticated_header(roles: ['creator'])

        get "/api/course/#{course.id}/enroll", nil, other_auth

        _(last_response.status).must_equal 403
      end
    end

    describe 'POST /api/course/:id/enroll/:account_id' do
      it 'updates enrollment as owner' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)
        student = create_test_account(roles: ['student'])

        # First enroll the student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student.id,
          role_id: student_role.id
        )

        payload = { enroll: { roles: 'instructor' } }

        post "/api/course/#{course.id}/enroll/#{student.id}", payload.to_json, json_headers(auth)

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['message']).must_be_kind_of String
      end
    end

    describe 'DELETE /api/course/:id/enroll/:account_id' do
      it 'removes enrollment as owner' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)
        student = create_test_account(roles: ['student'])

        # Enroll student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student.id,
          role_id: student_role.id
        )

        delete "/api/course/#{course.id}/enroll/#{student.id}", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['message']).must_be_kind_of String
      end
    end
  end

  describe 'Location Routes' do
    describe 'POST /api/course/:id/location' do
      it 'creates location as instructor' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

        # Enroll as instructor
        instructor_role = Tyto::Role.find(name: 'instructor')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: instructor_account.id,
          role_id: instructor_role.id
        )

        payload = { name: 'Room 101', latitude: 40.7128, longitude: -74.0060 }

        post "/api/course/#{course.id}/location", payload.to_json, json_headers(instructor_auth)

        _(last_response.status).must_equal 201
        _(json_response['success']).must_equal true
        _(json_response['message']).must_equal 'Location created'
        _(json_response['location_info']).wont_be_nil
        _(json_response['location_info']['id']).must_be_kind_of Integer
        _(json_response['location_info']['course_id']).must_be_kind_of Integer
        _(json_response['location_info']['name']).must_equal 'Room 101'
        _(json_response['location_info']).must_include 'latitude'
        _(json_response['location_info']).must_include 'longitude'
      end

      it 'returns forbidden as student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        payload = { name: 'Forbidden Location', latitude: 0, longitude: 0 }

        post "/api/course/#{course.id}/location", payload.to_json, json_headers(student_auth)

        _(last_response.status).must_equal 403
      end
    end

    describe 'GET /api/course/:id/location' do
      it 'lists locations for enrolled users' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)

        # Create a location
        Tyto::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 0,
          longitude: 0
        )

        get "/api/course/#{course.id}/location", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['data']).must_be_kind_of Array
        _(json_response['data'].length).must_be :>, 0

        location_data = json_response['data'].first
        _(location_data).must_include 'id'
        _(location_data).must_include 'course_id'
        _(location_data).must_include 'name'
        _(location_data).must_include 'latitude'
        _(location_data).must_include 'longitude'
      end

      it 'returns forbidden for non-enrolled users' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        _, other_auth = authenticated_header(roles: ['creator'])

        get "/api/course/#{course.id}/location", nil, other_auth

        _(last_response.status).must_equal 403
      end
    end

    describe 'GET /api/course/:id/location/:location_id' do
      it 'returns location for enrolled users' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)
        location = Tyto::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 0,
          longitude: 0
        )

        get "/api/course/#{course.id}/location/#{location.id}", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['data']).wont_be_nil
        _(json_response['data']['id']).must_equal location.id
        _(json_response['data']['course_id']).must_be_kind_of Integer
        _(json_response['data']['name']).must_equal 'Test Location'
        _(json_response['data']).must_include 'latitude'
        _(json_response['data']).must_include 'longitude'
      end
    end

    describe 'PUT /api/course/:id/location/:location_id' do
      it 'updates location as instructor' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

        # Enroll as instructor
        instructor_role = Tyto::Role.find(name: 'instructor')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: instructor_account.id,
          role_id: instructor_role.id
        )

        location = Tyto::Location.create(
          course_id: course.id,
          name: 'Old Name',
          latitude: 0,
          longitude: 0
        )

        payload = { name: 'Updated Location Name' }

        put "/api/course/#{course.id}/location/#{location.id}", payload.to_json, json_headers(instructor_auth)

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['message']).must_equal 'Location updated'
        _(json_response['location_info']).wont_be_nil
        _(json_response['location_info']['id']).must_equal location.id
        _(json_response['location_info']['name']).must_equal 'Updated Location Name'
      end

      it 'returns forbidden as student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        location = Tyto::Location.create(
          course_id: course.id,
          name: 'Protected Location',
          latitude: 0,
          longitude: 0
        )

        payload = { name: 'Hacked Name' }

        put "/api/course/#{course.id}/location/#{location.id}", payload.to_json, json_headers(student_auth)

        _(last_response.status).must_equal 403
      end
    end

    describe 'DELETE /api/course/:id/location/:location_id' do
      it 'succeeds when location has no events' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)
        location = Tyto::Location.create(
          course_id: course.id,
          name: 'Empty Location',
          latitude: 0,
          longitude: 0
        )

        delete "/api/course/#{course.id}/location/#{location.id}", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['message']).must_be_kind_of String
      end

      it 'fails when location has associated events' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)
        location = Tyto::Location.create(
          course_id: course.id,
          name: 'Active Location',
          latitude: 0,
          longitude: 0
        )

        # Create an event at this location
        Tyto::Event.create(
          course_id: course.id,
          location_id: location.id,
          name: 'Test Event',
          start_at: Time.now,
          end_at: Time.now + 3600
        )

        delete "/api/course/#{course.id}/location/#{location.id}", nil, auth

        # Should fail because location has events (400 - business rule violation)
        _(last_response.status).must_equal 400
      end
    end
  end

  describe 'Attendance Routes' do
    describe 'POST /api/course/:id/attendance' do
      it 'records attendance as student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        # Create location and event
        location = Tyto::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 40.7128,
          longitude: -74.0060
        )
        event = Tyto::Event.create(
          course_id: course.id,
          location_id: location.id,
          name: 'Test Event',
          start_at: Time.now - 300,
          end_at: Time.now + 3600
        )

        payload = {
          event_id: event.id,
          account_id: student_account.id,
          latitude: 40.7128,
          longitude: -74.0060
        }

        post "/api/course/#{course.id}/attendance", payload.to_json, json_headers(student_auth)

        _(last_response.status).must_equal 201
        _(json_response['success']).must_equal true
        _(json_response['message']).must_equal 'Attendance created'
        _(json_response['attendance_info']).wont_be_nil
        _(json_response['attendance_info']['id']).must_be_kind_of Integer
        _(json_response['attendance_info']['account_id']).must_be_kind_of Integer
        _(json_response['attendance_info']['course_id']).must_be_kind_of Integer
        _(json_response['attendance_info']['event_id']).must_be_kind_of Integer
        _(json_response['attendance_info']).must_include 'latitude'
        _(json_response['attendance_info']).must_include 'longitude'
        _(json_response['attendance_info']).must_include 'created_at'
        _(json_response['attendance_info']).must_include 'updated_at'
      end

      it 'includes GPS coordinates' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        # Create location and event
        location = Tyto::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 40.7128,
          longitude: -74.0060
        )
        event = Tyto::Event.create(
          course_id: course.id,
          location_id: location.id,
          name: 'Test Event',
          start_at: Time.now - 300,
          end_at: Time.now + 3600
        )

        payload = {
          event_id: event.id,
          account_id: student_account.id,
          latitude: 40.7130,
          longitude: -74.0062
        }

        post "/api/course/#{course.id}/attendance", payload.to_json, json_headers(student_auth)

        _(last_response.status).must_equal 201
        attendance = json_response['attendance_info']
        _(attendance['latitude']).must_equal(40.713)
        _(attendance['longitude']).must_equal(-74.0062)
      end
    end

    describe 'GET /api/course/:id/attendance' do
      it 'returns own attendance for student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        get "/api/course/#{course.id}/attendance", nil, student_auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['data']).must_be_kind_of Array
      end
    end

    describe 'GET /api/course/:id/attendance/list_all' do
      it 'returns all attendance for instructor' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

        # Enroll as instructor
        instructor_role = Tyto::Role.find(name: 'instructor')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: instructor_account.id,
          role_id: instructor_role.id
        )

        get "/api/course/#{course.id}/attendance/list_all", nil, instructor_auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['data']).must_be_kind_of Array
      end

      it 'returns forbidden for student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Tyto::Role.find(name: 'student')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        get "/api/course/#{course.id}/attendance/list_all", nil, student_auth

        _(last_response.status).must_equal 403
      end
    end

    describe 'GET /api/course/:id/attendance/:event_id' do
      it 'returns attendance for specific event' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

        # Enroll as instructor
        instructor_role = Tyto::Role.find(name: 'instructor')
        Tyto::AccountCourse.create(
          course_id: course.id,
          account_id: instructor_account.id,
          role_id: instructor_role.id
        )

        # Create location and event
        location = Tyto::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 0,
          longitude: 0
        )
        event = Tyto::Event.create(
          course_id: course.id,
          location_id: location.id,
          name: 'Test Event',
          start_at: Time.now,
          end_at: Time.now + 3600
        )

        get "/api/course/#{course.id}/attendance/#{event.id}", nil, instructor_auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['data']).must_be_kind_of Array
      end
    end
  end
end
