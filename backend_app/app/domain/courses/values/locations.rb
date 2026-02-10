# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'
require_relative '../entities/location'

module Tyto
  module Domain
    module Courses
      module Values
        # Value object wrapping a typed collection of Location entities.
        # Encapsulates query methods that previously lived on Course.
        class Locations < Dry::Struct
          attribute :locations, Types::Array.of(Entity::Location)

          include Enumerable

          def each(&block) = locations.each(&block)

          # Find a location by ID
          def find(location_id)
            locations.find { |l| l.id == location_id }
          end

          # Collection queries
          def any? = locations.any?
          def empty? = locations.empty?
          def count = locations.size
          def length = locations.length
          def size = locations.size
          def to_a = locations.dup

          # Convenience constructor from array
          def self.from(location_array)
            new(locations: location_array || [])
          end
        end
      end
    end
  end
end
