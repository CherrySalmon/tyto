# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Course Routes' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Todo::Api
  end

  # Helper to create a course owned by a given account
  def create_test_course(owner_account, name: 'Test Course')
    course = Todo::Course.create(
      name: name
    )
    # Enroll owner with 'owner' role
    owner_role = Todo::Role.find(name: 'owner')
    Todo::AccountCourse.create(
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
    end
  end

  describe 'GET /api/course/list_all' do
    it 'returns all courses for admin' do
      _, auth = authenticated_header(roles: ['admin'])

      get '/api/course/list_all', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
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
      _(json_response['data']['id']).must_equal course.id
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
      enrollment = Todo::AccountCourse.where(course_id: course_id, account_id: account.id).first
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
    end

    it 'updates course as instructor' do
      owner_account = create_test_account(roles: ['creator'])
      course = create_test_course(owner_account)
      instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

      # Enroll as instructor
      instructor_role = Todo::Role.find(name: 'instructor')
      Todo::AccountCourse.create(
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
      student_role = Todo::Role.find(name: 'student')
      Todo::AccountCourse.create(
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
      instructor_role = Todo::Role.find(name: 'instructor')
      Todo::AccountCourse.create(
        course_id: course.id,
        account_id: instructor_account.id,
        role_id: instructor_role.id
      )

      delete "/api/course/#{course.id}", nil, instructor_auth

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
      end

      it 'returns forbidden as student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
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
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        get "/api/course/#{course.id}", nil, student_auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
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
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: student.id,
          role_id: student_role.id
        )

        payload = { enroll: { roles: 'instructor' } }

        post "/api/course/#{course.id}/enroll/#{student.id}", payload.to_json, json_headers(auth)

        _(last_response.status).must_equal 200
      end
    end

    describe 'DELETE /api/course/:id/enroll/:account_id' do
      it 'removes enrollment as owner' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)
        student = create_test_account(roles: ['student'])

        # Enroll student
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: student.id,
          role_id: student_role.id
        )

        delete "/api/course/#{course.id}/enroll/#{student.id}", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
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
        instructor_role = Todo::Role.find(name: 'instructor')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: instructor_account.id,
          role_id: instructor_role.id
        )

        payload = { name: 'Room 101', latitude: 40.7128, longitude: -74.0060 }

        post "/api/course/#{course.id}/location", payload.to_json, json_headers(instructor_auth)

        _(last_response.status).must_equal 201
        _(json_response['success']).must_equal true
      end

      it 'returns forbidden as student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
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
        Todo::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 0,
          longitude: 0
        )

        get "/api/course/#{course.id}/location", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
        _(json_response['data']).must_be_kind_of Array
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
        location = Todo::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 0,
          longitude: 0
        )

        get "/api/course/#{course.id}/location/#{location.id}", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
      end
    end

    describe 'PUT /api/course/:id/location/:location_id' do
      it 'updates location as instructor' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        instructor_account, instructor_auth = authenticated_header(roles: ['instructor'])

        # Enroll as instructor
        instructor_role = Todo::Role.find(name: 'instructor')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: instructor_account.id,
          role_id: instructor_role.id
        )

        location = Todo::Location.create(
          course_id: course.id,
          name: 'Old Name',
          latitude: 0,
          longitude: 0
        )

        payload = { name: 'Updated Location Name' }

        put "/api/course/#{course.id}/location/#{location.id}", payload.to_json, json_headers(instructor_auth)

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
      end

      it 'returns forbidden as student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        location = Todo::Location.create(
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
        location = Todo::Location.create(
          course_id: course.id,
          name: 'Empty Location',
          latitude: 0,
          longitude: 0
        )

        delete "/api/course/#{course.id}/location/#{location.id}", nil, auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
      end

      it 'fails when location has associated events' do
        account, auth = authenticated_header(roles: ['creator'])
        course = create_test_course(account)
        location = Todo::Location.create(
          course_id: course.id,
          name: 'Active Location',
          latitude: 0,
          longitude: 0
        )

        # Create an event at this location
        Todo::Event.create(
          course_id: course.id,
          location_id: location.id,
          name: 'Test Event',
          start_at: Time.now,
          end_at: Time.now + 3600
        )

        delete "/api/course/#{course.id}/location/#{location.id}", nil, auth

        # Should fail because location has events
        _(last_response.status).must_equal 404
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
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        # Create location and event
        location = Todo::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 40.7128,
          longitude: -74.0060
        )
        event = Todo::Event.create(
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
      end

      it 'includes GPS coordinates' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: student_account.id,
          role_id: student_role.id
        )

        # Create location and event
        location = Todo::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 40.7128,
          longitude: -74.0060
        )
        event = Todo::Event.create(
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
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
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
        instructor_role = Todo::Role.find(name: 'instructor')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: instructor_account.id,
          role_id: instructor_role.id
        )

        get "/api/course/#{course.id}/attendance/list_all", nil, instructor_auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
      end

      it 'returns forbidden for student' do
        owner_account = create_test_account(roles: ['creator'])
        course = create_test_course(owner_account)
        student_account, student_auth = authenticated_header(roles: ['student'])

        # Enroll as student
        student_role = Todo::Role.find(name: 'student')
        Todo::AccountCourse.create(
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
        instructor_role = Todo::Role.find(name: 'instructor')
        Todo::AccountCourse.create(
          course_id: course.id,
          account_id: instructor_account.id,
          role_id: instructor_role.id
        )

        # Create location and event
        location = Todo::Location.create(
          course_id: course.id,
          name: 'Test Location',
          latitude: 0,
          longitude: 0
        )
        event = Todo::Event.create(
          course_id: course.id,
          location_id: location.id,
          name: 'Test Event',
          start_at: Time.now,
          end_at: Time.now + 3600
        )

        get "/api/course/#{course.id}/attendance/#{event.id}", nil, instructor_auth

        _(last_response.status).must_equal 200
        _(json_response['success']).must_equal true
      end
    end
  end
end
