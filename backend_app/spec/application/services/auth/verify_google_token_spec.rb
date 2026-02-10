# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'dry/monads'

describe Tyto::Service::Auth::VerifyGoogleToken do
  include Dry::Monads[:result]
  include TestHelpers

  let(:accounts_repo) { Tyto::Repository::Accounts.new }
  let(:mock_sso_mapper) { Minitest::Mock.new }
  let(:service) { Tyto::Service::Auth::VerifyGoogleToken.new(accounts_repo:, sso_mapper: mock_sso_mapper) }

  describe '#call' do
    describe 'with valid access token and existing account' do
      # Mapper returns domain-friendly hash with symbol keys
      let(:google_user_info) do
        {
          email: 'test@example.com',
          name: 'Test User',
          avatar: 'https://example.com/avatar.jpg'
        }
      end

      before do
        @account = create_test_account(
          name: 'Old Name',
          email: 'test@example.com',
          roles: ['creator']
        )
      end

      it 'returns Success with account and credential' do
        mock_sso_mapper.expect :load, Success(google_user_info), ['valid_token']

        result = service.call(access_token: 'valid_token')

        mock_sso_mapper.verify
        _(result).must_be_kind_of Dry::Monads::Result::Success
        _(result.value!.message[:account]).must_be_kind_of Tyto::Domain::Accounts::Entities::Account
        _(result.value!.message[:credential]).wont_be_nil
      end

      it 'updates account with Google profile data' do
        mock_sso_mapper.expect :load, Success(google_user_info), ['valid_token']

        result = service.call(access_token: 'valid_token')

        mock_sso_mapper.verify
        account = result.value!.message[:account]
        _(account.name).must_equal 'Test User'
        _(account.avatar).must_equal 'https://example.com/avatar.jpg'
      end

      it 'preserves existing roles' do
        mock_sso_mapper.expect :load, Success(google_user_info), ['valid_token']

        result = service.call(access_token: 'valid_token')

        mock_sso_mapper.verify
        account = result.value!.message[:account]
        _(account.roles).must_include 'creator'
      end
    end

    describe 'with missing access token' do
      it 'returns Failure for nil token' do
        result = service.call(access_token: nil)

        _(result).must_be_kind_of Dry::Monads::Result::Failure
        _(result.failure.status).must_equal :bad_request
        _(result.failure.message).must_equal 'Access token is required'
      end

      it 'returns Failure for empty token' do
        result = service.call(access_token: '')

        _(result).must_be_kind_of Dry::Monads::Result::Failure
        _(result.failure.status).must_equal :bad_request
      end
    end

    describe 'with non-existent account' do
      it 'returns Failure with not_found' do
        google_user_info = {
          email: 'nonexistent@example.com',
          name: 'Unknown User'
        }
        mock_sso_mapper.expect :load, Success(google_user_info), ['valid_token']

        result = service.call(access_token: 'valid_token')

        mock_sso_mapper.verify
        _(result).must_be_kind_of Dry::Monads::Result::Failure
        _(result.failure.status).must_equal :not_found
        _(result.failure.message).must_equal 'Account Not Found'
      end
    end

    describe 'when Google API fails' do
      it 'returns Failure with internal_error' do
        mock_sso_mapper.expect :load, Failure('Connection refused'), ['invalid_token']

        result = service.call(access_token: 'invalid_token')

        mock_sso_mapper.verify
        _(result).must_be_kind_of Dry::Monads::Result::Failure
        _(result.failure.status).must_equal :internal_error
        _(result.failure.message).must_include 'Connection refused'
      end
    end
  end
end
