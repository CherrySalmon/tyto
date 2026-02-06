# frozen_string_literal: true

require_relative '../spec_helper'
require 'dry/monads'

# Mock SSOAuth::Mapper for testing - allows setting mock response
module Tyto
  module SSOAuth
    class Mapper
      class << self
        attr_accessor :mock_response
      end

      # Only alias once to avoid errors
      unless method_defined?(:original_load_for_testing)
        alias original_load_for_testing load
      end

      def load(access_token)
        return self.class.mock_response if self.class.mock_response

        original_load_for_testing(access_token)
      end
    end
  end
end

describe 'Authentication Routes' do
  include Rack::Test::Methods
  include TestHelpers
  include Dry::Monads[:result]

  def app
    Tyto::Api
  end

  # Helper to stub SSOAuth::Mapper for a test
  def with_sso_auth_mock(return_value)
    Tyto::SSOAuth::Mapper.mock_response = return_value
    yield
  ensure
    Tyto::SSOAuth::Mapper.mock_response = nil
  end

  describe 'GET /api/auth/verify_google_token' do
    it 'returns API info' do
      get '/api/auth/verify_google_token'

      _(last_response.status).must_equal 200
      _(json_response['message']).must_equal 'Auth API'
    end
  end

  describe 'POST /api/auth/verify_google_token' do
    # Mapper returns domain-friendly hash with symbol keys
    let(:google_user_info) do
      {
        email: 'testuser@example.com',
        name: 'Test User',
        avatar: 'https://example.com/avatar.jpg',
        access_token: 'google_access_token_123'
      }
    end

    describe 'with existing account' do
      before do
        # Create account that matches Google email
        @account = create_test_account(
          name: 'Old Name',
          email: 'testuser@example.com',
          roles: ['creator']
        )
      end

      it 'returns success with JWT credential when account exists' do
        with_sso_auth_mock(Success(google_user_info)) do
          post '/api/auth/verify_google_token',
               { accessToken: 'valid_google_token' }.to_json,
               json_headers

          _(last_response.status).must_equal 200
          _(json_response['success']).must_equal true
          _(json_response['message']).must_equal 'Login successful'
          _(json_response['user_info']).wont_be_nil
          _(json_response['user_info']['credential']).wont_be_nil
          _(json_response['user_info']['email']).must_equal 'testuser@example.com'
          _(json_response['user_info']['roles']).must_be_kind_of Array
          _(json_response['user_info']['roles']).must_include 'creator'
        end
      end

      it 'updates account with Google profile data' do
        with_sso_auth_mock(Success(google_user_info)) do
          post '/api/auth/verify_google_token',
               { accessToken: 'valid_google_token' }.to_json,
               json_headers

          # Verify account was updated
          updated_account = Tyto::Account[@account.id]
          _(updated_account.name).must_equal 'Test User'
          _(updated_account.avatar).must_equal 'https://example.com/avatar.jpg'
        end
      end

      it 'returns valid JWT that can be used for authenticated requests' do
        with_sso_auth_mock(Success(google_user_info)) do
          post '/api/auth/verify_google_token',
               { accessToken: 'valid_google_token' }.to_json,
               json_headers

          credential = json_response['user_info']['credential']

          # Use the JWT for an authenticated request
          get '/api/course', nil, { 'HTTP_AUTHORIZATION' => "Bearer #{credential}" }

          _(last_response.status).must_equal 200
        end
      end
    end

    describe 'with non-existent account' do
      it 'returns 404 when account not found' do
        google_info = {
          email: 'nonexistent@example.com',
          name: 'Unknown User',
          avatar: nil
        }

        with_sso_auth_mock(Success(google_info)) do
          post '/api/auth/verify_google_token',
               { accessToken: 'valid_google_token' }.to_json,
               json_headers

          _(last_response.status).must_equal 404
          _(json_response['error']).must_equal 'Account Not Found'
        end
      end
    end

    describe 'error handling' do
      it 'returns 400 for invalid JSON body' do
        post '/api/auth/verify_google_token',
             'not valid json',
             json_headers

        _(last_response.status).must_equal 400
        _(json_response['error']).must_equal 'Invalid JSON'
      end

      it 'returns 500 when Google API fails' do
        with_sso_auth_mock(Failure('Google API error: connection refused')) do
          post '/api/auth/verify_google_token',
               { accessToken: 'invalid_token' }.to_json,
               json_headers

          _(last_response.status).must_equal 500
          _(json_response['error']).must_equal 'Internal error'
          _(json_response['details']).must_include 'Google API error'
        end
      end

      it 'returns 500 when Google returns invalid response' do
        with_sso_auth_mock(Failure('Invalid response from Google: unexpected token')) do
          post '/api/auth/verify_google_token',
               { accessToken: 'valid_token' }.to_json,
               json_headers

          _(last_response.status).must_equal 500
          _(json_response['error']).must_equal 'Internal error'
        end
      end
    end
  end
end
