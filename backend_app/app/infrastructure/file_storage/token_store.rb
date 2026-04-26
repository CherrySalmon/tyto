# frozen_string_literal: true

require 'json'
require 'base64'

module Tyto
  module FileStorage
    # HMAC-signed single-use token machinery used by LocalGateway (R-P8).
    # Tokens are signed and unforgeable; nonces are tracked in-process so a
    # token can be used at most once within its TTL. Bounded naturally by short
    # TTLs (15 min upload, 5 min download) — no eviction policy needed.
    #
    # Crypto delegated to Tyto::Security::Signer (keyed message authentication,
    # 32-byte tags, constant-time verification). Token nonces come from
    # Tyto::Security.unique_id.
    class TokenStore
      TAG_HEX_SIZE = Tyto::Security::Signer::TAG_SIZE * 2

      def initialize(signing_key:)
        @signer = Tyto::Security::Signer.new(key: signing_key)
        @consumed = {}
      end

      def mint(key:, operation:, ttl:)
        payload = {
          key:,
          op: operation,
          exp: Time.now.to_i + ttl,
          nonce: Tyto::Security.unique_id(8)
        }
        encode(payload)
      end

      # Returns :ok on success, or a Symbol describing why verification failed.
      def verify(token:, key:, expected_op:)
        cleanup_consumed
        payload = decode(token)
        reason = validation_failure(payload, key:, expected_op:)
        return reason if reason

        @consumed[payload[:nonce]] = payload[:exp]
        :ok
      end

      private

      def validation_failure(payload, key:, expected_op:)
        return :invalid_token if payload.nil?
        return :invalid_op    unless payload[:op]  == expected_op
        return :key_mismatch  unless payload[:key] == key
        return :expired       if payload[:exp] < Time.now.to_i
        return :replayed      if @consumed.key?(payload[:nonce])

        nil
      end

      def encode(payload)
        json = payload.to_json
        tag_hex = @signer.sign(json).unpack1('H*')
        Base64.urlsafe_encode64("#{tag_hex}.#{json}", padding: false)
      end

      def decode(token)
        decoded = Base64.urlsafe_decode64(token)
        tag_hex, json = decoded.split('.', 2)
        return nil unless tag_hex && json && tag_hex.bytesize == TAG_HEX_SIZE

        tag = [tag_hex].pack('H*')
        return nil unless @signer.valid?(json, tag)

        JSON.parse(json, symbolize_names: true)
      rescue ArgumentError, JSON::ParserError
        nil
      end

      def cleanup_consumed
        now = Time.now.to_i
        @consumed.delete_if { |_nonce, exp| exp < now }
      end
    end
  end
end
