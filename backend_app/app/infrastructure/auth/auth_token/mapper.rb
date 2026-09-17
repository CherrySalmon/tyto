# frozen_string_literal: true

require 'json'
require_relative '../../../domain/accounts/values/system_roles'
require_relative '../../database/repositories/accounts'

module Tyto
  module AuthToken
    # Maps between the encrypted credential and the request's AuthCapability.
    #
    # The credential carries only the account id and an expiry. Roles are read
    # from the database on every request, so a role change or a deleted
    # account takes effect on the next request, not at the next login.
    class Mapper
      # Unreadable header or token -> 400
      class MappingError < StandardError; end
      # Readable but no longer valid (expired, account gone) -> 401
      class RejectedError < StandardError; end

      # About one semester. Login mints a fresh credential each time.
      TOKEN_TTL = 180 * 24 * 60 * 60

      def initialize(gateway: Gateway.new, accounts_repo: Repository::Accounts.new, clock: -> { Time.now })
        @gateway = gateway
        @accounts_repo = accounts_repo
        @clock = clock
      end

      # Mints a credential for an account
      def to_token(account_id)
        raise MappingError, 'Account ID cannot be nil or empty' if account_id.to_s.strip.empty?

        @gateway.encrypt({ account_id: account_id.to_i, exp: @clock.call.to_i + TOKEN_TTL }.to_json)
      end

      # Turns an Authorization header (Bearer token) into the requester's
      # current capability
      def from_auth_header(auth_header)
        payload = parse(auth_header)
        reject('Credential has expired') unless fresh?(payload)

        account = @accounts_repo.find_with_roles(payload[:account_id])
        reject('Account no longer exists') unless account

        Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: account.roles)
      end

      private

      def parse(auth_header)
        raise MappingError, 'Invalid or missing Authorization header' unless auth_header&.start_with?('Bearer ')

        JSON.parse(@gateway.decrypt(auth_header.split.last), symbolize_names: true)
      rescue Gateway::EncryptionError, JSON::ParserError => e
        raise MappingError, "Token parsing failed: #{e.message}"
      end

      # A credential without an expiry predates this rule and is treated as
      # expired, so every session re-logs in once and drops its baked-in roles.
      def fresh?(payload)
        payload[:exp].is_a?(Integer) && payload[:exp] > @clock.call.to_i
      end

      def reject(reason)
        raise RejectedError, reason
      end
    end
  end
end
