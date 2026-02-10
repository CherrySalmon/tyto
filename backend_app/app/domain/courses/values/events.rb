# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'
require_relative '../entities/event'

module Tyto
  module Domain
    module Courses
      module Values
        # Value object wrapping a typed collection of Event entities.
        # Encapsulates query methods that previously lived on Course.
        class Events < Dry::Struct
          attribute :events, Types::Array.of(Entity::Event)

          include Enumerable

          def each(&block) = events.each(&block)

          # Find an event by ID
          def find(event_id)
            events.find { |e| e.id == event_id }
          end

          # Collection queries
          def any? = events.any?
          def empty? = events.empty?
          def count = events.size
          def length = events.length
          def size = events.size
          def to_a = events.dup

          # Convenience constructor from array
          def self.from(event_array)
            new(events: event_array || [])
          end
        end
      end
    end
  end
end
