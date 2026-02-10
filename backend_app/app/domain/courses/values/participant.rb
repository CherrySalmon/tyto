# frozen_string_literal: true

require_relative '../../types'

module Tyto
  module Domain
    module Courses
      module Values
        # Value object representing the enrolled person within the Courses context.
        # The Courses context's own view of account data — not the Account entity itself.
        # Immutable, defined by its attributes (no identity).
        class Participant < Dry::Struct
          attribute :email, Types::Email.optional
          attribute :name, Types::String.optional
          attribute? :avatar, Types::String.optional

          # Returns name if available, falls back to email
          def display_name
            name || email
          end
        end
      end
    end
  end
end
