# frozen_string_literal: true

require_relative '../values/attendance_register'
require_relative '../values/student_attendance_record'

module Tyto
  module Domain
    module Attendance
      module Entities
        # Domain entity representing an attendance report for a course.
        # Takes course and attendances in constructor; computes report data on demand.
        class AttendanceReport
          ReportEvent = Data.define(:id, :name)

          attr_reader :course_name, :generated_at

          def initialize(course:, attendances:)
            @course_name = course.name
            @generated_at = Time.now
            @course = course
            @attendances = attendances
          end

          def events
            @events ||= @course.events.map { |e| ReportEvent.new(id: e.id, name: e.name) }
          end

          def student_records
            @student_records ||= @course.students.map do |enrollment|
              Values::StudentAttendanceRecord.new(
                enrollment:, events: @course.events, register:
              )
            end
          end

          private

          def register
            @register ||= Values::AttendanceRegister.new(attendances: @attendances)
          end
        end
      end
    end
  end
end
