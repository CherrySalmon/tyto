# frozen_string_literal: true

require_relative '../values/attendance_register'
require_relative '../values/student_attendance_record'

module Tyto
  module Entity
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
        @events ||= raw_events.map { |e| ReportEvent.new(id: e.id, name: e.name) }
      end

      def student_records
        @student_records ||= students.map do |enrollment|
          Domain::Attendance::Values::StudentAttendanceRecord.new(
            enrollment:, events: raw_events, register:
          )
        end
      end

      private

      def raw_events
        @raw_events ||= @course.events_loaded? ? @course.events : []
      end

      def students
        @students ||= @course.enrollments_loaded? ? @course.students : []
      end

      def register
        @register ||= Domain::Attendance::Values::AttendanceRegister.new(attendances: @attendances)
      end
    end
  end
end
