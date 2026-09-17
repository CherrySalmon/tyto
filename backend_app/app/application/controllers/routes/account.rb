# frozen_string_literal: true

require 'json'
require 'dry/monads'

module Tyto
  module Routes
    # Account routes for user management
    class Accounts < Roda
      include Dry::Monads[:result]

      plugin :all_verbs
      plugin :request_headers
      # JSON bodies arrive parsed in r.POST. A malformed body re-raises the
      # JSON::ParserError so Tyto::Api's error_handler answers with 400.
      plugin :json_parser, error_handler: ->(_request) { raise }

      route do |r|
        r.on do
          auth_header = r.headers['Authorization']
          requestor = AuthToken::Mapper.new.from_auth_header(auth_header)

          # POST api/account/bulk — { emails: [...] }
          r.post 'bulk' do
            case Service::Accounts::BulkCreateAccounts.new.call(requestor:, emails: r.POST['emails'])
            in Success(api_result)
              response.status = api_result.http_status_code
              { success: true, message: 'Accounts added' }
                .merge(Representer::BulkAccountsOutcome.new(api_result.message).to_hash).to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              api_result.to_json
            end
          end

          r.on String do |account_id|
            # PUT api/account/:id
            r.put do
              request_body = r.POST

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
            request_body = r.POST

            case Service::Accounts::CreateAccount.new.call(requestor:, account_data: request_body)
            in Success(api_result)
              response.status = api_result.http_status_code
              { success: true, message: 'Account created',
                user_info: Representer::AccountWithRoles.new(api_result.message).to_hash }.to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              api_result.to_json
            end
          end
        end
      end
    end
  end
end
