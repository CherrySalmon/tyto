# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Tyto
  module Representer
    # Representer for Account entity to JSON
    class Account < Roar::Decorator
      include Roar::JSON

      property :id
      property :name
      property :email
      property :avatar
    end

    # Representer for Account with roles
    class AccountWithRoles < Roar::Decorator
      include Roar::JSON

      property :id
      property :name
      property :email
      property :avatar
      property :roles, exec_context: :decorator

      def roles
        return [] unless represented.respond_to?(:roles)

        represented.roles.respond_to?(:to_a) ? represented.roles.to_a : []
      end
    end

    # Representer for the outcome of a bulk add: created and existing accounts
    # (each with roles) plus the strings that were not valid emails.
    class BulkAccountsOutcome
      def initialize(outcome)
        @outcome = outcome
      end

      def to_hash
        {
          created: AccountsList.from_entities(@outcome.created).to_array,
          existing: AccountsList.from_entities(@outcome.existing).to_array,
          invalid: @outcome.invalid
        }
      end
    end

    # Representer for collection of Account entities
    class AccountsList
      def self.from_entities(entities)
        new(entities)
      end

      def initialize(entities)
        @entities = entities
      end

      def to_array
        @entities.map { |entity| AccountWithRoles.new(entity).to_hash }
      end
    end
  end
end
