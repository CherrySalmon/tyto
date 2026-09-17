# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Account Routes' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  describe 'GET /api/account' do
    it 'returns all accounts for admin' do
      _, auth = authenticated_header(roles: ['admin'])

      get '/api/account', nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['data']).must_be_kind_of Array
      _(json_response['data'].length).must_be :>, 0

      account_data = json_response['data'].first
      _(account_data).must_include 'id'
      _(account_data).must_include 'name'
      _(account_data).must_include 'email'
      _(account_data['id']).must_be_kind_of Integer
      _(account_data['name']).must_be_kind_of String
      _(account_data['email']).must_be_kind_of String
    end

    it 'includes each account system roles as an array of strings' do
      _, auth = authenticated_header(roles: ['admin'])
      target = create_test_account(name: 'Roles User', roles: %w[creator member])

      get '/api/account', nil, auth

      _(last_response.status).must_equal 200
      row = json_response['data'].find { |a| a['id'] == target.id }
      _(row).wont_be_nil
      _(row['roles']).must_be_kind_of Array
      _(row['roles'].sort).must_equal %w[creator member]
    end

    it 'returns forbidden for non-admin' do
      _, auth = authenticated_header(roles: ['creator'])

      get '/api/account', nil, auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'error handling (root error_handler)' do
    it 'returns 400 Invalid JSON for a malformed body' do
      _, auth = authenticated_header(roles: ['admin'])

      post '/api/account', '{"email": ', json_headers(auth)

      _(last_response.status).must_equal 400
      _(json_response['error']).must_equal 'Invalid JSON'
    end

    it 'returns 400 Token error for a missing Authorization header' do
      get '/api/account', nil, {}

      _(last_response.status).must_equal 400
      _(json_response['error']).must_equal 'Token error'
    end

    it 'returns 500 Internal Server Error when a service raises unexpectedly' do
      _, auth = authenticated_header(roles: ['admin'])
      boom = ->(*) { raise 'unexpected failure' }

      Tyto::Service::Accounts::ListAllAccounts.stub(:new, boom) do
        get '/api/account', nil, auth
      end

      _(last_response.status).must_equal 500
      _(json_response['error']).must_equal 'Internal Server Error'
      _(json_response['details']).must_equal 'unexpected failure'
    end
  end

  describe 'POST /api/account' do
    it 'creates account with valid data when requested by an admin' do
      _, auth = authenticated_header(roles: ['admin'])
      payload = { name: 'New User', email: 'new@test.com', roles: ['creator'] }

      post '/api/account', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
      _(json_response['message']).must_equal 'Account created'
      _(json_response['user_info']).wont_be_nil
      _(json_response['user_info']['id']).must_be_kind_of Integer
      _(json_response['user_info']['name']).must_equal 'New User'
      _(json_response['user_info']['email']).must_equal 'new@test.com'
      _(json_response['user_info']['roles']).must_equal ['creator']
    end

    it 'returns forbidden for a non-admin requestor' do
      _, auth = authenticated_header(roles: ['creator'])
      payload = { name: 'Sneaky', email: 'sneaky@test.com', roles: ['admin'] }

      post '/api/account', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 403
      _(Tyto::Account.first(email: 'sneaky@test.com')).must_be_nil
    end

    it 'returns bad request when a role is not a system role' do
      _, auth = authenticated_header(roles: ['admin'])
      payload = { name: 'Bad Role', email: 'badrole@test.com', roles: ['owner'] }

      post '/api/account', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 400
      _(Tyto::Account.first(email: 'badrole@test.com')).must_be_nil
    end

    it 'returns bad request when the email is malformed' do
      _, auth = authenticated_header(roles: ['admin'])
      payload = { name: 'No At Sign', email: 'not-an-email' }

      post '/api/account', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 400
    end

    it 'defaults roles to member when none are given' do
      _, auth = authenticated_header(roles: ['admin'])
      payload = { name: 'Default Role', email: 'default@test.com' }

      post '/api/account', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 201
      _(json_response['user_info']['roles']).must_equal ['member']
    end

    it 'returns conflict when the email already exists' do
      _, auth = authenticated_header(roles: ['admin'])
      create_test_account(name: 'Existing', email: 'dupe@test.com')
      payload = { name: 'Duplicate', email: 'dupe@test.com' }

      post '/api/account', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 409
    end

    it 'returns bad request without auth header' do
      payload = { name: 'No Auth User', email: 'noauth@test.com', roles: ['creator'] }

      post '/api/account', payload.to_json, json_headers

      _(last_response.status).must_equal 400
      _(json_response['error']).must_equal 'Token error'
    end
  end

  describe 'PUT /api/account/:id' do
    it 'updates own name successfully' do
      account, auth = authenticated_header(roles: ['creator'])
      payload = { 'name' => 'Updated Name' }

      put "/api/account/#{account.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(json_response['message']).must_be_kind_of String
      _(Tyto::Account[account.id].name).must_equal 'Updated Name'
    end

    it 'forbids a non-admin from changing their own roles' do
      account, auth = authenticated_header(roles: ['creator'])
      payload = { 'name' => 'Still Me', 'roles' => %w[creator admin] }

      put "/api/account/#{account.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 403
      _(Tyto::Account[account.id].roles.map(&:name)).must_equal ['creator']
      _(Tyto::Account[account.id].name).wont_equal 'Still Me'
    end

    it 'lets an admin change another account roles' do
      _, auth = authenticated_header(roles: ['admin'])
      target = create_test_account(name: 'Promote Me', roles: ['member'])
      payload = { 'roles' => %w[creator member] }

      put "/api/account/#{target.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 200
      _(Tyto::Account[target.id].roles.map(&:name).sort).must_equal %w[creator member]
    end

    it 'rejects a role that is not a system role' do
      _, auth = authenticated_header(roles: ['admin'])
      target = create_test_account(name: 'Bad Role', roles: ['member'])
      payload = { 'roles' => ['owner'] }

      put "/api/account/#{target.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 400
      _(Tyto::Account[target.id].roles.map(&:name)).must_equal ['member']
    end

    it 'forbids updating other accounts without admin role' do
      account, auth = authenticated_header(roles: ['creator'])
      other_account = create_test_account(name: 'Other User', roles: ['creator'])
      payload = { 'name' => 'Hacked Name', 'roles' => ['creator'] }

      put "/api/account/#{other_account.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 403
    end
  end

  describe 'DELETE /api/account/:id' do
    it 'lets an admin delete another account' do
      _, auth = authenticated_header(roles: ['admin'])
      target = create_test_account(name: 'Target User', roles: ['member'])

      delete "/api/account/#{target.id}", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
      _(Tyto::Account[target.id]).must_be_nil
    end

    it 'forbids deleting own account' do
      account, auth = authenticated_header(roles: ['creator'])

      delete "/api/account/#{account.id}", nil, auth

      _(last_response.status).must_equal 403
      _(Tyto::Account[account.id]).wont_be_nil
    end

    it 'forbids an admin deleting their own account' do
      account, auth = authenticated_header(roles: ['admin'])

      delete "/api/account/#{account.id}", nil, auth

      _(last_response.status).must_equal 403
      _(Tyto::Account[account.id]).wont_be_nil
    end

    it 'forbids deleting other accounts without admin role' do
      account, auth = authenticated_header(roles: ['creator'])
      other_account = create_test_account(name: 'Target User', roles: ['creator'])

      delete "/api/account/#{other_account.id}", nil, auth

      _(last_response.status).must_equal 403
    end
  end
end
