# frozen_string_literal: true

require 'json'
require 'dry/monads'

module Todo
  module Routes
    # Account routes for user management
    class Accounts < Roda
      include Dry::Monads[:result]

      plugin :all_verbs
      plugin :request_headers

      route do |r|
        r.on do
          auth_header = r.headers['Authorization']
          requestor = JWTCredential.decode_jwt(auth_header)

          r.on String do |account_id|
            # PUT api/account/:id
            r.put do
              request_body = JSON.parse(r.body.read)

              case Service::Accounts::UpdateAccount.new.call(
                requestor:, account_id:, account_data: request_body
              )
              in Success(api_result)
                response.status = api_result.http_status_code
                { success: true, message: api_result.message }.to_json
              in Failure(api_result)
                response.status = api_result.http_status_code
                api_result.to_json
              end
            rescue JSON::ParserError => e
              response.status = 400
              { error: 'Invalid JSON', details: e.message }.to_json
            end

            # DELETE api/account/:id
            r.delete do
              case Service::Accounts::DeleteAccount.new.call(requestor:, account_id:)
              in Success(api_result)
                response.status = api_result.http_status_code
                { success: true, message: api_result.message }.to_json
              in Failure(api_result)
                response.status = api_result.http_status_code
                api_result.to_json
              end
            end
          end

          # GET api/account
          r.get do
            case Service::Accounts::ListAllAccounts.new.call(requestor:)
            in Success(api_result)
              response.status = api_result.http_status_code
              { success: true, data: Representer::AccountsList.from_entities(api_result.message).to_array }.to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              api_result.to_json
            end
          end

          # POST api/account
          r.post do
            request_body = JSON.parse(r.body.read)

            case Service::Accounts::CreateAccount.new.call(requestor:, account_data: request_body)
            in Success(api_result)
              response.status = api_result.http_status_code
              { success: true, message: 'Account created',
                user_info: Representer::Account.new(api_result.message).to_hash }.to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              api_result.to_json
            end
          rescue JSON::ParserError => e
            response.status = 400
            { error: 'Invalid JSON', details: e.message }.to_json
          end
        rescue JWTCredential::ArgumentError => e
          response.status = 400
          response.write({ error: 'Token error', details: e.message }.to_json)
          r.halt
        rescue StandardError => e
          response.status = 500
          response.write({ error: 'Internal server error', details: e.message }.to_json)
          r.halt
        end
      end
    end
  end
end
