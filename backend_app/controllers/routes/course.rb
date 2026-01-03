# routes/course.rb

require 'json'

module Todo
  module Routes
    class Courses < Roda
      plugin :all_verbs
      plugin :request_headers

      route do |r|
        r.on do
          auth_header = r.headers['Authorization']
          requestor = JWTCredential.decode_jwt(auth_header)

          # GET api/course/list_all
          r.on 'list_all' do
            r.get do
              courses = CourseService.list_all(requestor)
              response.status = 200
              { success: true, data: courses }.to_json
            rescue CourseService::ForbiddenError => e
              response.status = 403
              { error: 'Forbidden', details: e.message }.to_json
            end
          end

          r.on String do |course_id|

            r.on 'enroll' do
              r.on String do |account_id|
                # POST api/course/:course_id/enroll/:enroll_id
                r.post do
                  request_body = JSON.parse(r.body.read)
                  enrolled_data = request_body["enroll"]
                  CourseService.update_enrollment(requestor, course_id, account_id, enrolled_data)
                  response.status = 200
                  { success: true, message: 'Enroll update' }.to_json
                rescue CourseService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
                end

                # DELETE api/course/:course_id/enroll/:enroll_id
                r.delete do
                  CourseService.remove_enroll(requestor, course_id, account_id)
                  response.status = 200
                  { success: true, message: 'Course deleted' }.to_json
                rescue CourseService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
                end
              end

              # GET api/course/:course_id/enroll - Retrieve enrollment information
              r.get do
                enrollments = CourseService.get_enrollments(requestor, course_id)
                response.status = 200
                { success: true, data: enrollments }.to_json

              rescue CourseService::ForbiddenError => e
                response.status = 403
                { error: 'Forbidden', details: e.message }.to_json
              rescue CourseService::CourseNotFoundError => e
                response.status = 404
                { error: 'Course not found', details: e.message }.to_json
              end
              # POST api/course/:course_id/enroll - Update or add enrollments
              r.post do
                request_body = JSON.parse(r.body.read)
                enrolled_data = request_body["enroll"] # Expects an array of {email: "email", roles: "role1,role2"}
                CourseService.update_enrollments(requestor, course_id, enrolled_data)
                response.status = 200
                { success: true, message: 'Enrollments updated' }.to_json
              rescue JSON::ParserError
                response.status = 400
                { error: 'Invalid JSON format' }.to_json
              rescue CourseService::CourseNotFoundError => e
                response.status = 404
                { error: 'Course not found', details: e.message }.to_json
              end
            end

            r.on 'attendance' do
              r.on 'list_all' do
                # GET api/course/:course_id/attendance/list_all
                r.get do
                  attendances = AttendanceService.list_all(requestor, course_id)
                  response.status = 200
                  { success: true, data: attendances }.to_json
                rescue AttendanceService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
                end
              end
              r.on String do |event_id|
                # GET api/course/:course_id/attendance/:event_id
                r.get do
                  attendances = AttendanceService.list_by_event(requestor, course_id, event_id)
                  response.status = 200
                  { success: true, data: attendances }.to_json
                rescue AttendanceService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
                end
              end
              # GET api/course/:course_id/attendance
              r.get do
                attendances = AttendanceService.list(requestor, course_id)
                response.status = 200
                { success: true, data: attendances }.to_json
                rescue AttendanceService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
              end

              # POST api/course/:course_id/attendance/
              r.post do
                request_body = JSON.parse(r.body.read)
                attendance = AttendanceService.create(requestor, request_body, course_id)
                response.status = 201
                { success: true, message: 'Attendance created', attendance_info: attendance.attributes }.to_json
                rescue JSON::ParserError => e
                  response.status = 400
                  { error: 'Invalid JSON', details: e.message }.to_json
                rescue AttendanceService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
              end
            end

            r.on 'event' do
              # GET api/course/:course_id/event/
              r.get do
                events = EventService.list(requestor, course_id)
                response.status = 200
                { success: true, data: events }.to_json
                rescue EventService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
              end

              # POST api/course/:course_id/event/
              r.post do
                request_body = JSON.parse(r.body.read)
                event = EventService.create(requestor, request_body, course_id)
                response.status = 201
                { success: true, message: 'Event created', event_info: event.attributes }.to_json
                rescue JSON::ParserError => e
                  response.status = 400
                  { error: 'Invalid JSON', details: e.message }.to_json
                rescue EventService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
              end

              r.on String do |event_id|
                # PUT api/course/:course_id/event/:event_id
                r.put do
                  request_body = JSON.parse(r.body.read)
                  EventService.update(requestor, event_id, request_body)
                  response.status = 200
                  { success: true, message: 'Event updated'}.to_json
                rescue EventService::EventNotFoundError => e
                  response.status = 404
                  { error: 'Forbidden', details: e.message }.to_json
                rescue EventService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
                end

                # DELETE api/course/:course_id/event/:event_id
                r.delete do
                  EventService.remove_event(requestor, event_id, course_id)
                  response.status = 200
                  { success: true, message: 'Event deleted' }.to_json
                rescue EventService::ForbiddenError => e
                  response.status = 403
                  { error: 'Forbidden', details: e.message }.to_json
                end
              end
            end

            r.on 'location' do
              r.on String do |location_id|
                r.on do
                  # GET api/course/:course_id/location/:id
                  r.get do
                    location = LocationService.get(requestor, location_id)
                    response.status = 200
                    { success: true, data: location }.to_json
                  rescue LocationService::ForbiddenError => e
                    response.status = 403
                    { error: 'Forbidden', details: e.message }.to_json
                  end
                  # PUT api/course/:course_id/location/:id
                  r.put do
                    request_body = JSON.parse(r.body.read)
                    LocationService.update(requestor, course_id, location_id, request_body)
                    response.status = 200
                    { success: true, message: 'Location updated'}.to_json
                  rescue LocationService::LocationNotFoundError => e
                    response.status = 404
                    { error: 'Location not found', details: e.message }.to_json
                  rescue LocationService::ForbiddenError => e
                    response.status = 403
                    { error: 'Forbidden', details: e.message }.to_json
                  end

                  # DELETE api/course/:course_id/location/:id
                  r.delete do
                    LocationService.remove(requestor, location_id, course_id)
                    response.status = 200
                    { success: true, message: 'Location deleted' }.to_json
                  rescue LocationService::ForbiddenError => e
                    response.status = 403
                    { error: 'Forbidden', details: e.message }.to_json
                  rescue JSON::ParserError => e
                    response.status = 400
                    { error: 'Invalid JSON', details: e.message }.to_json
                  rescue Sequel::NoMatchingRow => e
                    response.status = 404
                    { error: 'Location not found', details: e.message }.to_json
                  end
                end
              end

              # GET api/course/:course_id/location
              r.get do
                locations = LocationService.list_all(requestor, course_id)
                response.status = 200
                { success: true, data: locations }.to_json
              rescue LocationService::ForbiddenError => e
                response.status = 403
                { error: 'Forbidden', details: e.message }.to_json
              end

              # POST api/course/:course_id/location
              r.post do
                request_body = JSON.parse(r.body.read)
                location = LocationService.create(requestor, request_body, course_id)
                response.status = 201
                { success: true, message: 'Location created', location_info: location.attributes }.to_json
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
              rescue LocationService::ForbiddenError => e
                response.status = 403
                { error: 'Forbidden', details: e.message }.to_json
              end
            end

            r.on do
              # GET api/course/:id
              r.get do
                course = CourseService.get(requestor, course_id)
                response.status = 200
                { success: true, data: course }.to_json
              rescue CourseService::ForbiddenError => e
                response.status = 403
                { error: 'Forbidden', details: e.message }.to_json
              end
              # PUT api/course/:id
              r.put do
                request_body = JSON.parse(r.body.read)
                CourseService.update(requestor, course_id, request_body)
                response.status = 200
                { success: true, message: 'Course updated'}.to_json
              rescue CourseService::CourseNotFoundError => e
                response.status = 404
                { error: 'Course not found', details: e.message }.to_json
              rescue CourseService::ForbiddenError => e
                response.status = 403
                { error: 'Forbidden', details: e.message }.to_json
              end

              # DELETE api/course/:id
              r.delete do
                CourseService.remove(requestor, course_id)
                response.status = 200
                { success: true, message: 'Course deleted' }.to_json
              rescue CourseService::ForbiddenError => e
                response.status = 403
                { error: 'Forbidden', details: e.message }.to_json
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
              rescue Sequel::NoMatchingRow => e
                response.status = 404
                { error: 'Course not found', details: e.message }.to_json
              end
            end
          end

          # GET api/course
          r.get do
            courses = CourseService.list(requestor)
            response.status = 200
            { success: true, data: courses }.to_json
          rescue CourseService::ForbiddenError => e
            response.status = 403
            { error: 'Forbidden', details: e.message }.to_json
          end

          # POST api/course
          r.post do
            request_body = JSON.parse(r.body.read)
            course = CourseService.create(requestor, request_body)
            response.status = 201
            { success: true, message: 'Course created', course_info: course }.to_json
          rescue JSON::ParserError => e
            response.status = 400
            { error: 'Invalid JSON', details: e.message }.to_json
          rescue CourseService::ForbiddenError => e
            response.status = 403
            { error: 'Forbidden', details: e.message }.to_json
          end
        rescue JWTCredential::ArgumentError => e
          response.status = 400
          response.write({ error: 'Token error', details: e.message }.to_json)
          r.halt
        rescue StandardError => e
          response.status = 500
          response.write({ error: 'Internal server error', details: e.message }.to_json)
          r.halt
        end
      end
    end
  end
end
