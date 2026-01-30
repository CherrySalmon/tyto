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
  end
end
