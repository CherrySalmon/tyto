# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'
require 'json'
require_relative 'event'

module Todo
  module Representer
    # Serializes a collection of Event entities to JSON array
    class EventsList < Roar::Decorator
      include Roar::JSON

      collection :entries, extend: Representer::Event, class: OpenStruct

      # Wrap array in object with entries key for Roar collection handling
      def self.from_entities(events)
        wrapper = OpenStruct.new(entries: events)
        new(wrapper)
      end

      # Return just the array for API compatibility
      def to_array
        ::JSON.parse(to_json)['entries']
      end
    end
  end
end
