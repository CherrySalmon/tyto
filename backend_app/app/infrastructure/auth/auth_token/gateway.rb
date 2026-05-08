# frozen_string_literal: true

require 'base64'

require_relative '../../../lib/security'

module Tyto
  module AuthToken
    # Gateway for encrypting and decrypting token payloads.
    # Wraps Tyto::Security::Secret with the URL-safe base64 token framing.
    #
    # The signing key is loaded once at boot via `Gateway.setup(key:)` (called
    # from `config/initializers/credentials.rb`) — this class never reads ENV
    # itself. Tests can call `Gateway.setup` directly with a fresh key.
    class Gateway
      class EncryptionError < StandardError; end
      class NotConfiguredError < StandardError; end

      class << self
        # Cache the signing key on the class. Accepts the Base64-encoded form
        # (matching how the key lives in secrets.yml / ENV) and decodes once.
        # `nil` is allowed so boot doesn't fail in environments where JWT_KEY
        # is genuinely absent — the first call to `new` will surface the
        # missing-config error instead.
        def setup(key:)
          @raw_key = key.nil? || key.empty? ? nil : Base64.strict_decode64(key)
        end

        def reset!
          @raw_key = nil
        end

        def shared_key
          @raw_key || raise(NotConfiguredError,
                            'AuthToken::Gateway has no signing key — call Gateway.setup(key:) at boot')
        end

        def generate_key
          Tyto::Security.generate_secret_key
        end
      end

      def initialize(key = nil)
        @secret = Tyto::Security::Secret.new(key: key || self.class.shared_key)
      end

      def encrypt(payload)
        Base64.urlsafe_encode64(@secret.encrypt(payload))
      end

      def decrypt(token)
        @secret.decrypt(Base64.urlsafe_decode64(token))
      rescue Tyto::Security::Secret::EncryptionError, ArgumentError => e
        raise EncryptionError, "Decryption failed: #{e.message}"
      end
    end
  end
end
