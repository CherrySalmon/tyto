# frozen_string_literal: true

require 'dry/monads'

module Tyto
  module SSOAuth
    # Data Mapper: Google OAuth response -> domain-friendly user info
    # Isolates Google-specific field names from the rest of the application.
    class Mapper
      include Dry::Monads[:result]

      def initialize(gateway: Gateway.new)
        @gateway = gateway
      end

      # Fetch and transform Google user info
      # @param access_token [String] Google OAuth access token
      # @return [Dry::Monads::Result] Success(Hash) with domain fields or Failure(String)
      def load(access_token)
        result = @gateway.fetch_user_info(access_token)

        case result
        in Success(google_data)
          Success(DataMapper.new(google_data).to_hash)
        in Failure(error)
          Failure(error)
        end
      end

      # Extracts domain-specific fields from Google data structure
      class DataMapper
        def initialize(data)
          @data = data
        end

        def to_hash
          {
            email:,
            name:,
            avatar:,
            access_token:
          }
        end

        private

        def email
          @data['email']
        end

        def name
          # Handle frozen strings from test mocks
          @data['name']&.dup&.force_encoding('UTF-8')
        end

        def avatar
          @data['picture'] # Google calls it 'picture', we call it 'avatar'
        end

        def access_token
          @data['access_token']
        end
      end
    end
  end
end
