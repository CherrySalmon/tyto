# frozen_string_literal: true

# models/attendance.rb

require 'sequel'

module Todo
  class Attendance < Sequel::Model # rubocop:disable Style/Documentation
    plugin :validation_helpers

    many_to_one :course, class: :'Todo::Course'
    many_to_one :account_course_role, class: :'Todo::AccountCourse'
    many_to_one :event, class: :'Todo::Event'

    plugin :timestamps, update_on_create: true

    def validate
      super
      validates_presence %i[name created_at course_id account_id]
    end

    def self.list_attendance(account_id, course_id)
      # Assuming Attendance::account_id actually references account_course_roles.id
      # First, find the account_course_role_id(s) that match the account_id and course_id
      account_course_role_ids = AccountCourse.where(account_id:, course_id:).select_map(:id)

      # Then, query the attendances using those account_course_role_id(s)
      attendances = Attendance.where(account_id: account_course_role_ids).all
      attendances.map(&:values) # or any other way you wish to serialize the data
    end

    def self.add_attendance(account_id, course_id, attendance_details)
      account_course_role_id = find_account_course_role_id(account_id, course_id)

      # result = Attendance.where(account_id: account_course_role_id, course_id: course_id, event_id: attendance_details['event_id']).first
      # raise 'Attendance already done' if result

      # Create the Attendance record
      attendance = Attendance.create(
        account_id: account_course_role_id, # This is actually the AccountCourseRole ID
        course_id: course_id, # Assuming you also directly relate attendances to courses
        event_id: attendance_details['event_id'],
        name: attendance_details['name'],
        latitude: attendance_details['latitude'],
        longitude: attendance_details['longitude'],
        created_at: Time.now, # or omit if using automatic timestamps
        updated_at: Time.now  # or omit if using automatic timestamps
      )

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
