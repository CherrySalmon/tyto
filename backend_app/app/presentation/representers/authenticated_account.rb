# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Tyto
  module Representer
    # Representer for authenticated account response (login)
    # Includes account data plus JWT credential
    class AuthenticatedAccount < Roar::Decorator
      include Roar::JSON

      property :id, exec_context: :decorator
      property :name, exec_context: :decorator
      property :email, exec_context: :decorator
      property :avatar, exec_context: :decorator
      property :credential, exec_context: :decorator
      property :roles, exec_context: :decorator

      def id
        represented[:account].id
      end

      def name
        represented[:account].name
      end

      def email
        represented[:account].email
      end

      def avatar
        represented[:account].avatar
      end

      def credential
        represented[:credential]
      end

      def roles
        represented[:account].roles.to_a
      end
    end
  end
end
