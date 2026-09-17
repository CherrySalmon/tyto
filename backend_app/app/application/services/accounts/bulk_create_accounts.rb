# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Accounts
      # Service: Create accounts for a pasted list of emails (admin only).
      #
      # Every email that has no account yet is created with the 'member' role,
      # in one transaction, so a failed insert leaves nothing behind. Emails
      # that already have an account and strings that are not emails are
      # reported back rather than treated as errors, so the caller can show
      # one result list for the whole paste.
      #
      # Returns Success(ApiResult) with an Outcome, or Failure(ApiResult).
      class BulkCreateAccounts < ApplicationOperation
        MAX_BATCH_SIZE = 200
        DEFAULT_ROLES = ['member'].freeze

        Outcome = Struct.new(:created, :existing, :invalid, keyword_init: true)

        def initialize(accounts_repo: Repository::Accounts.new)
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:, emails:)
          step authorize(requestor)
          candidates = step validate_shape(emails)
          valid, invalid = partition_by_format(candidates)
          existing, missing = partition_by_presence(valid)
          created = step persist_all(missing)

          created(Outcome.new(created:, existing:, invalid:))
        end

        private

        def authorize(requestor)
          policy = Policy::Account.new(requestor, nil)
          return Failure(forbidden('You have no access to create accounts')) unless policy.can_create?

          Success(true)
        end

        def validate_shape(emails)
          cleaned = emails.is_a?(Array) ? clean(emails) : []
          return Failure(bad_request('Emails payload must be a non-empty array')) if cleaned.empty?
          return Failure(bad_request("Batch too large: #{MAX_BATCH_SIZE} emails max")) if cleaned.size > MAX_BATCH_SIZE

          Success(cleaned)
        end

        def clean(emails)
          emails.map { |email| email.to_s.strip }.reject(&:empty?).uniq
        end

        def partition_by_format(emails)
          emails.partition { |email| Types::Email.valid?(email) }
        end

        # Existing accounts come back with their roles so the caller can show them
        def partition_by_presence(emails)
          existing = []
          missing = []
          emails.each do |email|
            account = @accounts_repo.find_by_email_with_roles(email)
            account ? existing << account : missing << email
          end
          [existing, missing]
        end

        def persist_all(emails)
          entities = emails.map { |email| build_entity(email) }
          Success(@accounts_repo.create_many(entities, role_names: DEFAULT_ROLES))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end

        def build_entity(email)
          Domain::Accounts::Entities::Account.new(
            id: nil, name: nil, email:, access_token: nil, refresh_token: nil, avatar: nil,
            roles: Domain::Accounts::Values::NullSystemRoles.new
          )
        end
      end
    end
  end
end
