# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Tyto::AuthToken::Gateway do
  let(:gateway) { Tyto::AuthToken::Gateway.new }
  let(:payload) { '{"account_id":42,"roles":["admin","creator"]}' }

  describe '#encrypt and #decrypt' do
    it 'round-trips a payload' do
      token = gateway.encrypt(payload)
      decrypted = gateway.decrypt(token)

      _(decrypted).must_equal payload
    end

    it 'produces URL-safe base64 tokens' do
      token = gateway.encrypt(payload)

      _(token).must_be_kind_of String
      _(token).wont_be_empty
      _(token).wont_match(%r{[+/]}) # URL-safe base64 uses - and _ instead of + and /
    end

    it 'produces different tokens for same payload (nonce randomness)' do
      token1 = gateway.encrypt(payload)
      token2 = gateway.encrypt(payload)

      _(token1).wont_equal token2
    end
  end

  describe '#decrypt' do
    it 'raises EncryptionError for invalid token' do
      _(-> { gateway.decrypt('invalid_base64!@#') }).must_raise Tyto::AuthToken::Gateway::EncryptionError
    end

    it 'raises EncryptionError for tampered token' do
      token = gateway.encrypt(payload)
      tampered = token.reverse

      _(-> { gateway.decrypt(tampered) }).must_raise Tyto::AuthToken::Gateway::EncryptionError
    end
  end

  describe '.generate_key' do
    it 'returns a base64 encoded key' do
      key = Tyto::AuthToken::Gateway.generate_key

      _(key).must_be_kind_of String
      _(key).wont_be_empty
    end

    it 'produces valid 32-byte keys for RbNaCl SecretBox' do
      key = Tyto::AuthToken::Gateway.generate_key
      decoded = Base64.strict_decode64(key)

      _(decoded.length).must_equal 32
    end

    it 'produces unique keys' do
      key1 = Tyto::AuthToken::Gateway.generate_key
      key2 = Tyto::AuthToken::Gateway.generate_key

      _(key1).wont_equal key2
    end
  end
end
