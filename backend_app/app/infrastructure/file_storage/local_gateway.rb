# frozen_string_literal: true

require 'fileutils'
require 'dry/monads'

module Tyto
  module FileStorage
    # Filesystem adapter that mirrors the AWS Gateway interface so frontend
    # code is identical across environments. Used in development and test
    # only — production routes to the AWS Gateway.
    #
    # All methods that take a `key:` accept a Tyto::FileStorage::StorageKey;
    # callers are expected to construct one (raising on invalid input) at
    # the trust boundary. The gateway calls `key.to_s` internally for the
    # filesystem and the token payload.
    #
    # HMAC-signed single-use tokens are delegated to TokenStore.
    class LocalGateway
      include Dry::Monads[:result]

      UPLOAD_TTL_SECONDS   = 15 * 60
      DOWNLOAD_TTL_SECONDS =  5 * 60

      def initialize(root:, signing_key:, base_url:)
        @root = root
        @base_url = base_url
        @tokens = TokenStore.new(signing_key:)
      end

      def presign_upload(key:, allowed_extensions: nil) # rubocop:disable Lint/UnusedMethodArgument
        token = @tokens.mint(key: key.to_s, operation: 'upload', ttl: UPLOAD_TTL_SECONDS)
        Success(
          upload_url: "#{@base_url}/api/_local_storage/upload",
          fields: { 'key' => key.to_s, 'token' => token }
        )
      end

      def presign_download(key:)
        token = @tokens.mint(key: key.to_s, operation: 'download', ttl: DOWNLOAD_TTL_SECONDS)
        Success(
          download_url: "#{@base_url}/api/_local_storage/download/#{key}?token=#{token}"
        )
      end

      def write(key:, body:)
        path = absolute_path(key)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, body)
        Success(true)
      end

      def read(key:)
        path = absolute_path(key)
        return Failure(:not_found) unless File.exist?(path)

        Success(File.binread(path))
      end

      def head(key:)
        File.exist?(absolute_path(key)) ? Success(true) : Failure(:not_found)
      end

      def delete(key:)
        path = absolute_path(key)
        return Failure(:not_found) unless File.exist?(path)

        File.delete(path)
        Success(true)
      end

      def verify_upload_token(token:, key:)
        verify_token(token:, key:, expected_op: 'upload')
      end

      def verify_download_token(token:, key:)
        verify_token(token:, key:, expected_op: 'download')
      end

      private

      def verify_token(token:, key:, expected_op:)
        reason = @tokens.verify(token:, key: key.to_s, expected_op:)
        reason == :ok ? Success(true) : Failure(reason)
      end

      def absolute_path(key)
        File.join(@root, key.to_s)
      end
    end
  end
end
