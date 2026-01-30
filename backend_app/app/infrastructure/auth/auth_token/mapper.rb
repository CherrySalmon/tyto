# frozen_string_literal: true

require 'json'

module Tyto
  module AuthToken
    # Maps between Requestor domain objects and encrypted tokens.
    # Handles JSON serialization and Authorization header parsing.
    class Mapper
      class MappingError < StandardError; end

      def initialize(gateway: Gateway.new)
        @gateway = gateway
      end

      # Converts a Requestor into an encrypted token string
      def to_token(requestor)
        raise MappingError, 'Requestor cannot be nil' if requestor.nil?

        payload = { account_id: requestor.account_id, roles: requestor.roles }.to_json
        @gateway.encrypt(payload)
      end

      # Convenience method to create token from raw credentials
      def from_credentials(account_id, roles)
        raise MappingError, 'Account ID cannot be nil or empty' if account_id.to_s.strip.empty?
        raise MappingError, 'Roles cannot be nil or empty' if roles.nil? || roles.empty?

        requestor = Domain::Accounts::Values::Requestor.new(
          account_id: account_id.to_i,
          roles:
        )
        to_token(requestor)
      end

      # Extracts Requestor from an Authorization header (Bearer token)
      def from_auth_header(auth_header)
        unless auth_header&.start_with?('Bearer ')
          raise MappingError, 'Invalid or missing Authorization header'
        end

        token = auth_header.split(' ').last
        payload = @gateway.decrypt(token)
        parsed = JSON.parse(payload, symbolize_names: true)

        Domain::Accounts::Values::Requestor.new(
          account_id: parsed[:account_id],
          roles: parsed[:roles]
        )
      rescue Gateway::EncryptionError, JSON::ParserError => e
        raise MappingError, "Token parsing failed: #{e.message}"
      end
    end
  end
end
