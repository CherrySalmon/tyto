# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Tyto
  module Representer
    # Representer for Location entity to JSON
    class Location < Roar::Decorator
      include Roar::JSON

      property :id
      property :course_id
      property :name
      property :longitude
      property :latitude
    end

    # Representer for collection of Location entities
    class LocationsList
      def self.from_entities(entities)
        new(entities)
      end

      def initialize(entities)
        @entities = entities
      end

      def to_array
        @entities.map { |entity| Location.new(entity).to_hash }
      end
    end
  end
end
