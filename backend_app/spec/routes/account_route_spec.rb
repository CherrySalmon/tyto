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
    end

    it 'returns forbidden for non-admin' do
      _, auth = authenticated_header(roles: ['creator'])

      get '/api/account', nil, auth

      _(last_response.status).must_equal 403
    end
  end

  describe 'POST /api/account' do
    it 'creates account with valid data when authenticated' do
      _, auth = authenticated_header(roles: ['creator'])
      payload = { name: 'New User', email: 'new@test.com', roles: ['creator'] }

      post '/api/account', payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 201
      _(json_response['success']).must_equal true
    end

    it 'returns bad request without auth header' do
      payload = { name: 'No Auth User', email: 'noauth@test.com', roles: ['creator'] }

      post '/api/account', payload.to_json, json_headers

      _(last_response.status).must_equal 400
      _(json_response['error']).must_equal 'Token error'
    end
  end

  describe 'PUT /api/account/:id' do
    it 'updates own account successfully' do
      account, auth = authenticated_header(roles: ['creator'])
      payload = { 'name' => 'Updated Name', 'roles' => ['creator'] }

      put "/api/account/#{account.id}", payload.to_json, json_headers(auth)

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
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
    it 'allows deleting own account' do
      account, auth = authenticated_header(roles: ['creator'])

      delete "/api/account/#{account.id}", nil, auth

      _(last_response.status).must_equal 200
      _(json_response['success']).must_equal true
    end

    it 'forbids deleting other accounts without admin role' do
      account, auth = authenticated_header(roles: ['creator'])
      other_account = create_test_account(name: 'Target User', roles: ['creator'])

      delete "/api/account/#{other_account.id}", nil, auth

      _(last_response.status).must_equal 403
    end
  end
end
