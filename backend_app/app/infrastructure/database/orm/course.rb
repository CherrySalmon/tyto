# frozen_string_literal: true

# models/course.rb

require 'sequel'

module Tyto
  class Course < Sequel::Model
    plugin :validation_helpers
    many_to_many :events
    one_to_many :locations

    many_to_many :attendances, join_table: :account_course_roles
    many_to_many :roles, join_table: :account_course_roles
    many_to_many :accounts, join_table: :account_course_roles

    plugin :timestamps, update_on_create: true

    def validate
      super
      validates_presence %i[name]
    end

    def attributes(account_id = nil)
      {
        id: id,
        name: name,
        created_at: created_at&.utc&.iso8601,
        updated_at: updated_at&.utc&.iso8601,
        logo: logo,
        start_at: start_at&.utc&.iso8601,
        end_at: end_at&.utc&.iso8601,
        enroll_identity: account_id ? get_enroll_identity(account_id) : {}
      }
    end

    private

    def get_enroll_identity(account_id)
      AccountCourse.where(account_id:, course_id: id).map { |ac| ac.role.name }
    end
  end
end
