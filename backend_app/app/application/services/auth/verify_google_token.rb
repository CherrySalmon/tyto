# frozen_string_literal: true

require_relative '../../../infrastructure/database/repositories/accounts'
require_relative '../application_operation'

module Tyto
  module Service
    module Auth
      # Service: Verify Google OAuth token and authenticate user
      # Returns Success(ApiResult) with account + credential or Failure(ApiResult)
      class VerifyGoogleToken < ApplicationOperation
        def initialize(accounts_repo: Repository::Accounts.new, sso_mapper: SSOAuth::Mapper.new)
          @accounts_repo = accounts_repo
          @sso_mapper = sso_mapper
          super()
        end

        def call(access_token:)
          step validate_access_token(access_token)
          google_user = step fetch_google_user_info(access_token)
          account = step find_account_by_email(google_user[:email])
          updated_account = step update_account_from_google(account, google_user)
          credential = step generate_credential(updated_account)

          ok(account: updated_account, credential:)
        end

        private

        def validate_access_token(access_token)
          return Failure(bad_request('Access token is required')) if access_token.nil? || access_token.to_s.strip.empty?

          Success(access_token)
        end

        def fetch_google_user_info(access_token)
          result = @sso_mapper.load(access_token)

          case result
          in Success(user_data)
            Success(user_data)
          in Failure(error_message)
            Failure(internal_error(error_message))
          end
        end

        def find_account_by_email(email)
          account = @accounts_repo.find_by_email_with_roles(email)
          return Failure(not_found('Account Not Found')) unless account

          Success(account)
        end

        def update_account_from_google(account, google_user)
          # Mapper returns domain-friendly hash with symbol keys
          updated_entity = account.new(
            name: google_user[:name] || account.name,
            avatar: google_user[:avatar] || account.avatar,
            access_token: google_user[:access_token] || account.access_token
          )

          # Preserve existing roles when updating
          updated_account = @accounts_repo.update(updated_entity, role_names: account.roles)
          Success(updated_account)
        rescue StandardError => e
          Failure(internal_error("Failed to update account: #{e.message}"))
        end

        def generate_credential(account)
          credential = AuthToken::Mapper.new.from_credentials(account.id, account.roles)
          Success(credential)
        rescue StandardError => e
          Failure(internal_error("Failed to generate credential: #{e.message}"))
        end
      end
    end
  end
end
