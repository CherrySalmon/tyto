# frozen_string_literal: true

require 'json'
require 'dry/monads'

module Tyto
  module Routes
    # Authentication routes for OAuth login
    class Authentication < Roda
      include Dry::Monads[:result]

      plugin :request_headers

      # JSON bodies arrive parsed in r.POST. A malformed body re-raises the
      # JSON::ParserError so Tyto::Api's error_handler answers with 400.
      plugin :json_parser, error_handler: ->(_request) { raise }

      route do |r|
        # GET api/auth/session - the logged-in account as the server sees it now
        r.get 'session' do
          requestor = AuthToken::Mapper.new.from_auth_header(r.headers['Authorization'])

          case Service::Accounts::GetOwnAccount.new.call(requestor:)
          in Success(api_result)
            response.status = api_result.http_status_code
            { success: true, data: Representer::AccountWithRoles.new(api_result.message).to_hash }.to_json
          in Failure(api_result)
            response.status = api_result.http_status_code
            api_result.to_json
          end
        end

        r.on 'verify_google_token' do
          # GET api/auth/verify_google_token - API info
          r.get do
            { message: 'Auth API' }.to_json
          end

          # POST api/auth/verify_google_token - Verify Google OAuth token
          r.post do
            request_body = r.POST
            access_token = request_body['accessToken']

            case Service::Auth::VerifyGoogleToken.new.call(access_token:)
            in Success(api_result)
              response.status = api_result.http_status_code
              user_info = Representer::AuthenticatedAccount.new(api_result.message).to_hash
              { success: true, message: 'Login successful', user_info: }.to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              # Match legacy response format for 404
              if api_result.http_status_code == 404
                { error: api_result.message }.to_json
              else
                api_result.to_json
              end
            end
          end
        end
      end
    end
  end
end
