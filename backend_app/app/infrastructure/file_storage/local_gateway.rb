# frozen_string_literal: true

require 'fileutils'
require 'dry/monads'

module Tyto
  module FileStorage
    # Filesystem adapter that mirrors the AWS Gateway interface so frontend code
    # is identical across environments (Q4 / R-P1). Used in development and test
    # only — production gateway selection (3.6) routes to the AWS Gateway.
    #
    # HMAC-signed single-use tokens (R-P8) are delegated to TokenStore.
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
        token = @tokens.mint(key:, operation: 'upload', ttl: UPLOAD_TTL_SECONDS)
        Success(
          upload_url: "#{@base_url}/api/_local_storage/upload",
          fields: { 'key' => key, 'token' => token }
        )
      end

      def presign_download(key:)
        token = @tokens.mint(key:, operation: 'download', ttl: DOWNLOAD_TTL_SECONDS)
        Success(
          download_url: "#{@base_url}/api/_local_storage/download/#{key}?token=#{token}"
        )
      end

      def write(key:, body:)
        validate_key!(key)
        path = absolute_path(key)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, body)
        Success(true)
      end

      def read(key:)
        validate_key!(key)
        path = absolute_path(key)
        return Failure(:not_found) unless File.exist?(path)

        Success(File.binread(path))
      end

      def head(key:)
        validate_key!(key)
        File.exist?(absolute_path(key)) ? Success(true) : Failure(:not_found)
      end

      def delete(key:)
        validate_key!(key)
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
        reason = @tokens.verify(token:, key:, expected_op:)
        reason == :ok ? Success(true) : Failure(reason)
      end

      def validate_key!(key)
        raise ArgumentError, 'key cannot be blank'    if key.nil? || key.to_s.strip.empty?
        raise ArgumentError, 'key cannot be absolute' if key.start_with?('/')
        raise ArgumentError, 'key cannot contain ..'  if key.split('/').include?('..')
      end

      def absolute_path(key)
        File.join(@root, key)
      end
    end
  end
end
