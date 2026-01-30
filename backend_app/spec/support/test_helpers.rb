# frozen_string_literal: true

require 'securerandom'
require 'json'

module TestHelpers
  # Create a test account and return it
  def create_test_account(name: 'Test User', email: nil, roles: ['creator'])
    email ||= "test-#{SecureRandom.hex(4)}@example.com"
    Tyto::Account.add_account(
      name: name,
      email: email,
      roles: roles,
      access_token: 'test_token',
      avatar: nil
    )
  end

  # Generate auth header for a given account
  def auth_header_for(account)
    token = Tyto::AuthToken::Mapper.new.from_credentials(
      account.id,
      account.roles.map(&:name)
    )
    { 'HTTP_AUTHORIZATION' => "Bearer #{token}" }
  end

  # Shortcut: create account and return its auth header
  def authenticated_header(roles: ['creator'])
    account = create_test_account(roles: roles)
    [account, auth_header_for(account)]
  end

  # Parse JSON response body
  def json_response
    JSON.parse(last_response.body)
  end

  # Content-Type header for JSON requests
  def json_headers(auth_header = {})
    { 'CONTENT_TYPE' => 'application/json' }.merge(auth_header)
  end
end
