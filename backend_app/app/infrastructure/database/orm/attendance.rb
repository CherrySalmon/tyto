# frozen_string_literal: true

# models/attendance.rb

require 'sequel'

module Tyto
  class Attendance < Sequel::Model # rubocop:disable Style/Documentation
    plugin :validation_helpers

    many_to_many :courses, join_table: :account_course_roles
    many_to_many :roles, join_table: :account_course_roles
    many_to_many :accounts, join_table: :account_course_roles
    many_to_one :event

    plugin :timestamps, update_on_create: true

    def validate
      super
      validates_presence %i[created_at course_id account_id]
    end

    def self.list_attendance(account_id, course_id)
      student_role = Role.first(name: "student")

      attendances = Attendance.where(account_id:, course_id:, role_id: student_role.id).all
      attendances.map(&:values)
    end

    def self.add_attendance(account_id, course_id, attendance_details)
      student_role = Role.first(name: "student").id
      event = Event.first(id: attendance_details['event_id'])
      # Create the Attendance record
      attendance = Attendance.find_or_create(
        account_id: account_id,
        role_id: student_role,
        course_id: course_id, # Assuming you also directly relate attendances to courses
        event_id: attendance_details['event_id'],
        # Auto-generate name from event if not provided
        name: attendance_details['name'] || (event&.name ? "#{event.name} Attendance" : 'Attendance'),
        latitude: attendance_details['latitude'],
        longitude: attendance_details['longitude']
      )
      attendance
    rescue StandardError => e
      # Handle error (e.g., AccountCourseRole not found, validation errors)
      { error: "Failed to add attendance: #{e.message}" }
    end

    def attributes
      {
        id:,
        account_id:,
        course_id:,
        event_id:,
        name:,
        latitude:,
        longitude:,
        created_at:,
        updated_at:
      }
    end

    def self.find_account_course_role_id(account_id, course_id)
      account_course_role = AccountCourse.where(account_id:, course_id:).first
      raise 'AccountCourse not found' unless account_course_role

      account_course_role.id
    end
  end
end
