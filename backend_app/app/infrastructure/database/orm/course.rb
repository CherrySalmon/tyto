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
  end
end
