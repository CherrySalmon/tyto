# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Accounts
      # Service: Create accounts for a pasted list of emails (admin only).
      #
      # Every email that has no account yet is created (as a member, the
      # repository's rule) in one transaction, so a failed insert leaves nothing
      # behind. Emails that already have an account and strings that are not
      # emails are reported back rather than treated as errors, so the caller
      # can show one result list for the whole paste.
      #
      # Returns Success(ApiResult) with an Outcome, or Failure(ApiResult).
      class BulkCreateAccounts < ApplicationOperation
        MAX_BATCH_SIZE = 200

        Outcome = Struct.new(:created, :existing, :invalid, keyword_init: true)

        def initialize(accounts_repo: Repository::Accounts.new)
          @accounts_repo = accounts_repo
          super()
        end

        def call(requestor:, emails:)
          step authorize(requestor)
          candidates = step validate_shape(emails)
          valid, invalid = partition_by_format(candidates)
          result = step find_or_create(valid)

          created(Outcome.new(created: result.created, existing: result.found, invalid:))
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

        # The repository owns the "new accounts start as member" rule and the
        # transaction; this service adds admin-only access, validation, and the report.
        def find_or_create(emails)
          Success(@accounts_repo.find_or_create_many_by_email(emails))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
