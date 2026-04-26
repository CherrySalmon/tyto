# frozen_string_literal: true

require 'aws-sdk-s3'
require 'dry/monads'

module Tyto
  module FileStorage
    # AWS S3 adapter. Mirrors LocalGateway's interface so callers don't branch
    # on environment. Upload uses presigned **POST** (R-P1) so S3 enforces the
    # size cap server-side via the signed policy doc; download uses presigned
    # GET; head/delete go through the client directly.
    class Gateway
      include Dry::Monads[:result]

      PRESIGN_TTL_SECONDS = 15 * 60

      def initialize(client:, bucket:)
        @client = client
        @bucket = bucket
      end

      def presign_upload(key:, allowed_extensions: nil) # rubocop:disable Lint/UnusedMethodArgument
        post = Aws::S3::PresignedPost.new(
          @client.config.credentials, @client.config.region, @bucket,
          key: key.to_s,
          content_length_range: 1..Tyto::FileStorage::MAX_SIZE_BYTES,
          signature_expiration: Time.now + PRESIGN_TTL_SECONDS
        )
        Success(upload_url: post.url.to_s, fields: post.fields)
      rescue Aws::Errors::ServiceError, Aws::S3::Errors::ServiceError => e
        Failure("S3 presign upload failed: #{e.message}")
      end

      def presign_download(key:)
        url = presigner.presigned_url(
          :get_object, bucket: @bucket, key: key.to_s, expires_in: PRESIGN_TTL_SECONDS
        )
        Success(download_url: url)
      rescue Aws::Errors::ServiceError => e
        Failure("S3 presign download failed: #{e.message}")
      end

      def head(key:)
        @client.head_object(bucket: @bucket, key: key.to_s)
        Success(true)
      rescue Aws::S3::Errors::NotFound
        Failure(:not_found)
      rescue Aws::S3::Errors::ServiceError => e
        Failure("S3 head failed: #{e.message}")
      end

      def delete(key:)
        @client.delete_object(bucket: @bucket, key: key.to_s)
        Success(true)
      rescue Aws::S3::Errors::ServiceError => e
        Failure("S3 delete failed: #{e.message}")
      end

      private

      def presigner
        @presigner ||= Aws::S3::Presigner.new(client: @client)
      end
    end
  end
end
