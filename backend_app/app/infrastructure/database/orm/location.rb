# frozen_string_literal: true
# models/location.rb

require 'sequel'

module Tyto
  class Location < Sequel::Model
    # validation for the model
    plugin :validation_helpers
    plugin :timestamps, update_on_create: true

    many_to_one :course
    one_to_many :events

    def validate
      super
      validates_presence %i[name course_id]
    end
  end
end
