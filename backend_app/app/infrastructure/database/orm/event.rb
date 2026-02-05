# frozen_string_literal: true

# models/event.rb

require 'sequel'

module Tyto
  class Event < Sequel::Model # rubocop:disable Style/Documentation
    plugin :validation_helpers

    many_to_one :course
    many_to_one :location
    one_to_many :attendances

    plugin :timestamps, update_on_create: true

    def validate
      super
      validates_presence %i[name location_id]
    end
  end
end
