# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'

module Tyto
  module Domain
    module Assignments
      module Values
        # Summary view of an Event attached to an Assignment.
        # Lives in the Assignments context to avoid the aggregate crossing
        # bounded-context boundaries with a full Courses::Entities::Event.
        # Carries just what the detail view needs.
        class LinkedEvent < Dry::Struct
          attribute :id, Types::Integer
          attribute :name, Types::String
          attribute :start_at, Types::Time.optional
          attribute :end_at, Types::Time.optional
        end
      end
    end
  end
end
