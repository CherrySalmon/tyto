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

      # Builds the `user_options` hash threaded into Representer::Submission
      # so each nested RequirementUploadRepr can emit `download_url`. Reaches
      # for the assignment's requirements once per response — submission and
      # list endpoints already gate on view permission upstream, so any caller
      # who reaches the representer is allowed to see download links.
      def submission_render_options(course_id, assignment_id)
        assignment = Repository::Assignments.new.find_with_requirements(assignment_id.to_i)
        requirements = assignment&.submission_requirements&.to_a || []
        requirements_by_id = requirements.each_with_object({}) { |req, hash| hash[req.id] = req }

        {
          course_id: course_id.to_i,
          assignment_id: assignment_id.to_i,
          requirements_by_id:,
          can_download: true
        }
      end

      route do |r|
        r.on do
          auth_header = r.headers['Authorization']
          requestor = AuthToken::Mapper.new.from_auth_header(auth_header)

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

            r.on 'assignable_roles' do
              # GET api/course/:course_id/assignable_roles
              r.get do
                case Service::Courses::GetAssignableRoles.new.call(requestor:, course_id:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, data: api_result.message }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              end
            end

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
              r.on 'report' do
                # GET api/course/:course_id/attendance/report[?format=csv]
                r.get do
                  case Service::Attendances::GenerateReport.new.call(requestor:, course_id:)
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    if r.params['format'] == 'csv'
                      csv = Presentation::Formatters::CourseAttendanceReportCsv.to_csv(api_result.message)
                      response['Content-Type'] = 'text/csv'
                      response['Content-Disposition'] = 'attachment; filename="attendance-report.csv"'
                      csv
                    else
                      { success: true, data: Representer::CourseAttendanceReport.new(api_result.message).to_hash }.to_json
                    end
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                end
              end

              r.on String do |event_id|
                r.on 'participants' do
                  # GET api/course/:course_id/attendance/:event_id/participants
                  r.get do
                    case Service::Attendances::ListEventParticipants.new.call(requestor:, course_id:, event_id:)
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      { success: true, **api_result.message.to_h }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  end
                end

                r.on 'participant', String do |account_id|
                  # PUT api/course/:course_id/attendance/:event_id/participant/:account_id
                  r.put do
                    request_body = JSON.parse(r.body.read)

                    case Service::Attendances::UpdateParticipantAttendance.new.call(
                      requestor:, course_id:, event_id:,
                      target_account_id: account_id,
                      attended: request_body['attended']
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
                end

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

            r.on 'events' do
              # GET api/course/:course_id/events
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

              # POST api/course/:course_id/events — expects { events: [{...}, ...] }
              r.post do
                request_body = JSON.parse(r.body.read)
                events_data = request_body['events']

                unless events_data.is_a?(Array) && !events_data.empty?
                  response.status = 400
                  next({ error: 'Invalid payload', details: 'Body must include a non-empty "events" array' }.to_json)
                end

                case Service::Events::CreateEvents.new.call(requestor:, course_id:, events_data:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, message: 'Events created',
                    events_info: Representer::EventsList.from_entities(api_result.message).to_array }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
              end

              r.on String do |event_id|
                # PUT api/course/:course_id/events/:event_id
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

                # DELETE api/course/:course_id/events/:event_id
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

            r.on 'assignments' do
              r.on String do |assignment_id|
                r.on 'publish' do
                  # POST api/course/:course_id/assignments/:assignment_id/publish
                  r.post do
                    case Service::Assignments::PublishAssignment.new.call(
                      requestor:, course_id:, assignment_id:
                    )
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      { success: true, message: api_result.message }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  end
                end

                r.on 'unpublish' do
                  # POST api/course/:course_id/assignments/:assignment_id/unpublish
                  r.post do
                    case Service::Assignments::UnpublishAssignment.new.call(
                      requestor:, course_id:, assignment_id:
                    )
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      { success: true, message: api_result.message }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  end
                end

                r.on 'submissions' do
                  r.on String do |submission_id|
                    r.on 'uploads' do
                      r.on String do |upload_id|
                        # GET api/course/:cid/assignments/:aid/submissions/:sid/uploads/:uid/download
                        # Mints a fresh presigned GET and 302-redirects. Each click
                        # gets new credentials so long-open staff views never click
                        # an expired URL.
                        r.get 'download' do
                          case Service::Submissions::DownloadUpload.new.call(
                            requestor:, course_id:, assignment_id:,
                            submission_id:, upload_id:
                          )
                          in Success(api_result)
                            response.status = 302
                            response.headers['Location'] = api_result.message
                            ''
                          in Failure(api_result)
                            response.status = api_result.http_status_code
                            api_result.to_json
                          end
                        end
                      end
                    end

                    # GET api/course/:course_id/assignments/:assignment_id/submissions/:submission_id
                    r.get do
                      case Service::Submissions::GetSubmission.new.call(
                        requestor:, course_id:, assignment_id:, submission_id:
                      )
                      in Success(api_result)
                        response.status = api_result.http_status_code
                        opts = submission_render_options(course_id, assignment_id)
                        { success: true,
                          data: Representer::Submission.new(api_result.message).to_hash(user_options: opts) }.to_json
                      in Failure(api_result)
                        response.status = api_result.http_status_code
                        api_result.to_json
                      end
                    end
                  end

                  # GET api/course/:course_id/assignments/:assignment_id/submissions
                  r.get do
                    case Service::Submissions::ListSubmissions.new.call(
                      requestor:, course_id:, assignment_id:
                    )
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      opts = submission_render_options(course_id, assignment_id)
                      { success: true,
                        data: Representer::SubmissionsList.from_entities(api_result.message).to_array(user_options: opts) }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  end

                  # POST api/course/:course_id/assignments/:assignment_id/submissions
                  r.post do
                    request_body = JSON.parse(r.body.read)

                    case Service::Submissions::CreateSubmission.new.call(
                      requestor:, course_id:, assignment_id:, submission_data: request_body
                    )
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      opts = submission_render_options(course_id, assignment_id)
                      { success: true,
                        data: Representer::Submission.new(api_result.message).to_hash(user_options: opts) }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  rescue JSON::ParserError => e
                    response.status = 400
                    { error: 'Invalid JSON', details: e.message }.to_json
                  end
                end

                r.on 'upload_grants' do
                  # POST api/course/:course_id/assignments/:assignment_id/upload_grants
                  # Mints short-lived upload credentials (key + presigned URL +
                  # signed policy fields) for each requested file. "Grant"
                  # borrows OAuth/IAM vocabulary — the response is a credential,
                  # not just a URL.
                  r.post do
                    request_body = JSON.parse(r.body.read)
                    uploads = request_body['uploads']

                    case Service::Assignments::IssueUploadGrants.new.call(
                      requestor:, course_id:, assignment_id:, uploads:
                    )
                    in Success(api_result)
                      response.status = api_result.http_status_code
                      { success: true, data: api_result.message }.to_json
                    in Failure(api_result)
                      response.status = api_result.http_status_code
                      api_result.to_json
                    end
                  rescue JSON::ParserError => e
                    response.status = 400
                    { error: 'Invalid JSON', details: e.message }.to_json
                  end
                end

                # GET api/course/:course_id/assignments/:assignment_id
                r.get do
                  case Service::Assignments::GetAssignment.new.call(
                    requestor:, course_id:, assignment_id:
                  )
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    { success: true, data: Representer::Assignment.new(api_result.message).to_hash }.to_json
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                end

                # PUT api/course/:course_id/assignments/:assignment_id
                r.put do
                  request_body = JSON.parse(r.body.read)

                  case Service::Assignments::UpdateAssignment.new.call(
                    requestor:, course_id:, assignment_id:, assignment_data: request_body
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

                # DELETE api/course/:course_id/assignments/:assignment_id
                r.delete do
                  case Service::Assignments::DeleteAssignment.new.call(
                    requestor:, course_id:, assignment_id:
                  )
                  in Success(api_result)
                    response.status = api_result.http_status_code
                    { success: true, message: api_result.message }.to_json
                  in Failure(api_result)
                    response.status = api_result.http_status_code
                    api_result.to_json
                  end
                end
              end

              # GET api/course/:course_id/assignments
              r.get do
                case Service::Assignments::ListAssignments.new.call(requestor:, course_id:)
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, data: Representer::AssignmentsList.from_entities(api_result.message).to_array }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              end

              # POST api/course/:course_id/assignments
              r.post do
                request_body = JSON.parse(r.body.read)

                case Service::Assignments::CreateAssignment.new.call(
                  requestor:, course_id:, assignment_data: request_body
                )
                in Success(api_result)
                  response.status = api_result.http_status_code
                  { success: true, message: 'Assignment created',
                    assignment_info: Representer::Assignment.new(api_result.message).to_hash }.to_json
                in Failure(api_result)
                  response.status = api_result.http_status_code
                  api_result.to_json
                end
              rescue JSON::ParserError => e
                response.status = 400
                { error: 'Invalid JSON', details: e.message }.to_json
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
        rescue AuthToken::Mapper::MappingError => e
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
