# frozen_string_literal: true

module Tyto
  module Routes
    # Local-storage HTTP endpoints used by the LocalGateway in development and
    # test. Mounted under /api/_local_storage in app.rb. Mirror the S3
    # form-POST upload + signed-URL download contract so frontend code is
    # identical across environments. The route branch is guarded by an
    # environment allowlist — production deploys never reach the handlers.
    class LocalStorage < Roda
      plugin :all_verbs
      plugin :halt

      ALLOWED_ENVIRONMENTS = Tyto::FileStorage::LOCAL_ENVIRONMENTS

      route do |r|
        r.halt 404 unless ALLOWED_ENVIRONMENTS.include?(Tyto::Api.environment)

        # POST api/_local_storage/upload — multipart form-POST. Fields: key, token, file.
        r.post 'upload' do
          key  = Tyto::FileStorage::StorageKey.try_from(r.params['key'])
          file = r.params['file']
          r.halt 400 if key.nil?

          token = r.params['token'].to_s
          r.halt 401 unless Tyto::FileStorage.build_gateway.verify_upload_token(token:, key:).success?
          r.halt 400 unless multipart_file?(file)

          result = Tyto::FileStorage.build_gateway.write(key:, body: file[:tempfile].read)
          r.halt 500 unless result.success?

          response.status = 204
          ''
        end

        # GET api/_local_storage/download/<multi/segment/key> — token in `?token=` query string.
        r.on 'download' do
          r.get(/(.+)/) do |raw_key|
            key = Tyto::FileStorage::StorageKey.try_from(raw_key)
            r.halt 400 if key.nil?

            token = r.params['token'].to_s
            r.halt 401 unless Tyto::FileStorage.build_gateway.verify_download_token(token:, key:).success?

            result = Tyto::FileStorage.build_gateway.read(key:)
            r.halt 404 unless result.success?

            response['Content-Type'] = 'application/octet-stream'
            result.value!
          end
        end
      end

      # Did Rack's multipart parser produce a real file param (not a missing
      # field or a plain form value)?
      def multipart_file?(value)
        value.is_a?(Hash) && value[:tempfile] && value[:filename]
      end
    end
  end
end
