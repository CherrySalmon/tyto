# frozen_string_literal: true

require 'json'
require 'dry/monads'

module Tyto
  module Routes
    # Course routes including events, locations, attendance, and enrollments
    class Courses < Roda
      include Dry::Monads[:result]

      plugin :all_verbs
      plugin :request_headers

      route do |r|
        r.on do
          auth_header = r.headers['Authorization']
          requestor = JWTCredential.decode_jwt(auth_header)

          # GET api/course/list_all
          r.on 'list_all' do
            r.get do
              case Service::Courses::ListAllCourses.new.call(requestor:)
              in Success(api_result)
                response.status = api_result.http_status_code
                { success: true, data: Representer::CoursesList.from_entities(api_result.message).to_array }.to_json
              in Failure(api_result)
                response.status = api_result.http_status_code
                api_result.to_json
              end
            end
          end

          r.on String do |course_id|

            r.on 'enroll' do
              r.on String do |account_id|
                # POST api/course/:course_id/enroll/:enroll_id
                r.post do
                  request_body = JSON.parse(r.body.read)
                  enrolled_data = request_body['enroll']

                  case Service::Courses::UpdateEnrollment.new.call(
                    requestor:, course_id:, account_id:, enrolled_data:
                  )
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    { success: true, message: api_result.message }.to_json
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                rescue JSON::ParserError => e
                  response.status = 400
                  { error: 'Invalid JSON', details: e.message }.to_json
                end

                # DELETE api/course/:course_id/enroll/:enroll_id
                r.delete do
                  case Service::Courses::RemoveEnrollment.new.call(requestor:, course_id:, account_id:)
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    { success: true, message: api_result.message }.to_json
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                end
              end

              # GET api/course/:course_id/enroll - Retrieve enrollment information
              r.get do
                case Service::Courses::GetEnrollments.new.call(requestor:, course_id:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, data: Representer::EnrollmentsList.from_entities(api_result.message).to_array }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              end
              # POST api/course/:course_id/enroll - Update or add enrollments
              r.post do
                request_body = JSON.parse(r.body.read)
                enrolled_data = request_body['enroll'] # Expects an array of {email: "email", roles: "role1,role2"}

                case Service::Courses::UpdateEnrollments.new.call(requestor:, course_id:, enrolled_data:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, message: api_result.message }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
              end
            end

            r.on 'attendance' do
              r.on 'list_all' do
                # GET api/course/:course_id/attendance/list_all
                r.get do
                  case Service::Attendances::ListAllAttendances.new.call(requestor:, course_id:)
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    { success: true, data: Representer::AttendancesList.from_entities(api_result.message).to_array }.to_json
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                end
              end

              r.on String do |event_id|
                # GET api/course/:course_id/attendance/:event_id
                r.get do
                  case Service::Attendances::ListAttendancesByEvent.new.call(requestor:, course_id:, event_id:)
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    { success: true, data: Representer::AttendancesList.from_entities(api_result.message).to_array }.to_json
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                end
              end

              # GET api/course/:course_id/attendance
              r.get do
                case Service::Attendances::ListUserAttendances.new.call(requestor:, course_id:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, data: Representer::AttendancesList.from_entities(api_result.message).to_array }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              end

              # POST api/course/:course_id/attendance/
              r.post do
                request_body = JSON.parse(r.body.read)

                case Service::Attendances::RecordAttendance.new.call(
                  requestor:, course_id:, attendance_data: request_body
                )
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, message: 'Attendance created',
                    attendance_info: Representer::Attendance.new(api_result.message).to_hash }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
              end
            end

            r.on 'event' do
              # GET api/course/:course_id/event/
              r.get do
                case Service::Events::ListEvents.new.call(requestor:, course_id:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, data: Representer::EventsList.from_entities(api_result.message).to_array }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              end

              # POST api/course/:course_id/event/
              r.post do
                request_body = JSON.parse(r.body.read)

                case Service::Events::CreateEvent.new.call(requestor:, course_id:, event_data: request_body)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, message: 'Event created', event_info: Representer::Event.new(api_result.message).to_hash }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
              end

              r.on String do |event_id|
                # PUT api/course/:course_id/event/:event_id
                r.put do
                  request_body = JSON.parse(r.body.read)

                  case Service::Events::UpdateEvent.new.call(
                    requestor:, course_id:, event_id:, event_data: request_body
                  )
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    { success: true, message: 'Event updated',
                      event_info: Representer::Event.new(api_result.message).to_hash }.to_json
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                rescue JSON::ParserError => e
                  response.status = 400
                  { error: 'Invalid JSON', details: e.message }.to_json
                end

                # DELETE api/course/:course_id/event/:event_id
                r.delete do
                  case Service::Events::DeleteEvent.new.call(requestor:, course_id:, event_id:)
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    { success: true, message: api_result.message }.to_json
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                end
              end
            end

            r.on 'location' do
              r.on String do |location_id|
                r.on do
                  # GET api/course/:course_id/location/:id
                  r.get do
                    case Service::Locations::GetLocation.new.call(requestor:, location_id:)
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      { success: true, data: Representer::Location.new(api_result.message).to_hash }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  end

                  # PUT api/course/:course_id/location/:id
                  r.put do
                    request_body = JSON.parse(r.body.read)

                    case Service::Locations::UpdateLocation.new.call(
                      requestor:, course_id:, location_id:, location_data: request_body
                    )
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      { success: true, message: 'Location updated',
                        location_info: Representer::Location.new(api_result.message).to_hash }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  rescue JSON::ParserError => e
                    response.status = 400
                    { error: 'Invalid JSON', details: e.message }.to_json
                  end

                  # DELETE api/course/:course_id/location/:id
                  r.delete do
                    case Service::Locations::DeleteLocation.new.call(requestor:, course_id:, location_id:)
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      { success: true, message: api_result.message }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  end
                end
              end

              # GET api/course/:course_id/location
              r.get do
                case Service::Locations::ListLocations.new.call(requestor:, course_id:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, data: Representer::LocationsList.from_entities(api_result.message).to_array }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              end

              # POST api/course/:course_id/location
              r.post do
                request_body = JSON.parse(r.body.read)

                case Service::Locations::CreateLocation.new.call(
                  requestor:, course_id:, location_data: request_body
                )
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, message: 'Location created',
                    location_info: Representer::Location.new(api_result.message).to_hash }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
              end
            end

            r.on do
              # GET api/course/:id
              r.get do
                case Service::Courses::GetCourse.new.call(requestor:, course_id:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, data: Representer::CourseWithEnrollment.new(api_result.message).to_hash }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              end

              # PUT api/course/:id
              r.put do
                request_body = JSON.parse(r.body.read)

                case Service::Courses::UpdateCourse.new.call(requestor:, course_id:, course_data: request_body)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, message: api_result.message }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
              end

              # DELETE api/course/:id
              r.delete do
                case Service::Courses::DeleteCourse.new.call(requestor:, course_id:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, message: api_result.message }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              end
            end
          end

          # GET api/course
          r.get do
            case Service::Courses::ListUserCourses.new.call(requestor:)
            in Success(api_result)
              response.status = api_result.http_status_code
              { success: true, data: Representer::CoursesWithEnrollmentList.from_entities(api_result.message).to_array }.to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              api_result.to_json
            end
          end

          # POST api/course
          r.post do
            request_body = JSON.parse(r.body.read)

            case Service::Courses::CreateCourse.new.call(requestor:, course_data: request_body)
            in Success(api_result)
              response.status = api_result.http_status_code
              { success: true, message: 'Course created',
                course_info: Representer::CourseWithEnrollment.new(api_result.message).to_hash }.to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              api_result.to_json
            end
          rescue JSON::ParserError => e
            response.status = 400
            { error: 'Invalid JSON', details: e.message }.to_json
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
