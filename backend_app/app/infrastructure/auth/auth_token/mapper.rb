# frozen_string_literal: true

require 'json'
require_relative '../../../domain/accounts/values/system_roles'

module Tyto
  module AuthToken
    # Maps between AuthCapability domain objects and encrypted tokens.
    # Handles JSON serialization and Authorization header parsing.
    class Mapper
      class MappingError < StandardError; end

      def initialize(gateway: Gateway.new)
        @gateway = gateway
      end

      # Converts an AuthCapability into an encrypted token string
      def to_token(capability)
        raise MappingError, 'AuthCapability cannot be nil' if capability.nil?

        payload = { account_id: capability.account_id, roles: capability.roles.to_a }.to_json
        @gateway.encrypt(payload)
      end

      # Convenience method to create token from raw credentials
      def from_credentials(account_id, roles)
        raise MappingError, 'Account ID cannot be nil or empty' if account_id.to_s.strip.empty?
        raise MappingError, 'Roles cannot be nil or empty' if roles.nil? || roles.empty?

        capability = Domain::Accounts::Values::AuthCapability.new(
          account_id: account_id.to_i,
          roles: Domain::Accounts::Values::SystemRoles.from(roles)
        )
        to_token(capability)
      end

      # Extracts AuthCapability from an Authorization header (Bearer token)
      def from_auth_header(auth_header)
        unless auth_header&.start_with?('Bearer ')
          raise MappingError, 'Invalid or missing Authorization header'
        end

        token = auth_header.split(' ').last
        payload = @gateway.decrypt(token)
        parsed = JSON.parse(payload, symbolize_names: true)

        Domain::Accounts::Values::AuthCapability.new(
          account_id: parsed[:account_id],
          roles: Domain::Accounts::Values::SystemRoles.from(parsed[:roles])
        )
      rescue Gateway::EncryptionError, JSON::ParserError => e
        raise MappingError, "Token parsing failed: #{e.message}"
      end
    end
  end
end
