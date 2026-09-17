# frozen_string_literal: true

require_relative '../../../spec_helper'

# The credential carries only the account id and an expiry. Roles are read
# from the database on every request, so a role change (or a deleted account)
# takes effect on the next request rather than at the next login.
describe Tyto::AuthToken::Mapper do
  let(:mapper) { Tyto::AuthToken::Mapper.new }
  let(:account) do
    orm = Tyto::Account.create(email: 'token@example.com', name: 'Token User')
    orm.add_role(Tyto::Role.first(name: 'member'))
    orm
  end
  let(:day) { 24 * 60 * 60 }

  def decoded(token)
    JSON.parse(Tyto::AuthToken::Gateway.new.decrypt(token), symbolize_names: true)
  end

  describe '#to_token' do
    it 'carries the account id and an expiry, never roles' do
      payload = decoded(mapper.to_token(account.id))

      _(payload[:account_id]).must_equal account.id
      _(payload[:exp]).must_be_kind_of Integer
      _(payload).wont_include :roles
    end

    it 'expires about a semester after issue' do
      exp = decoded(mapper.to_token(account.id))[:exp]

      _(exp - Time.now.to_i).must_be :>=, 179 * day
      _(exp - Time.now.to_i).must_be :<=, 181 * day
    end

    it 'raises MappingError with a blank account id' do
      _(-> { mapper.to_token(nil) }).must_raise Tyto::AuthToken::Mapper::MappingError
      _(-> { mapper.to_token('') }).must_raise Tyto::AuthToken::Mapper::MappingError
    end
  end

  describe '#from_auth_header' do
    it 'returns an AuthCapability whose roles come from the database' do
      token = mapper.to_token(account.id)

      result = mapper.from_auth_header("Bearer #{token}")

      _(result).must_be_kind_of Tyto::Domain::Accounts::Values::AuthCapability
      _(result.account_id).must_equal account.id
      _(result.roles.to_a).must_equal ['member']
    end

    it 'reflects a role change made after the token was issued' do
      token = mapper.to_token(account.id)
      account.add_role(Tyto::Role.first(name: 'admin'))

      _(mapper.from_auth_header("Bearer #{token}").admin?).must_equal true

      account.remove_all_roles
      _(mapper.from_auth_header("Bearer #{token}").roles.to_a).must_equal []
    end

    it 'rejects a token whose account no longer exists' do
      token = mapper.to_token(account.id)
      account.destroy

      _(-> { mapper.from_auth_header("Bearer #{token}") }).must_raise Tyto::AuthToken::Mapper::RejectedError
    end

    it 'rejects an expired token' do
      token = mapper.to_token(account.id)
      later = Tyto::AuthToken::Mapper.new(clock: -> { Time.now + (200 * day) })

      _(-> { later.from_auth_header("Bearer #{token}") }).must_raise Tyto::AuthToken::Mapper::RejectedError
    end

    it 'rejects a legacy token that has no expiry' do
      legacy = Tyto::AuthToken::Gateway.new.encrypt({ account_id: account.id, roles: ['admin'] }.to_json)

      _(-> { mapper.from_auth_header("Bearer #{legacy}") }).must_raise Tyto::AuthToken::Mapper::RejectedError
    end

    it 'raises MappingError for an unreadable token' do
      _(-> { mapper.from_auth_header('Bearer invalid_token') }).must_raise Tyto::AuthToken::Mapper::MappingError
    end

    it 'raises MappingError without the Bearer prefix or without a header' do
      token = mapper.to_token(account.id)

      _(-> { mapper.from_auth_header(token) }).must_raise Tyto::AuthToken::Mapper::MappingError
      _(-> { mapper.from_auth_header(nil) }).must_raise Tyto::AuthToken::Mapper::MappingError
    end
  end
end
