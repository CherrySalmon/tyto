# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Todo
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
        represented.respond_to?(:roles) ? represented.roles : []
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
        @entities.map { |entity| Account.new(entity).to_hash }
      end
    end
  end
end
