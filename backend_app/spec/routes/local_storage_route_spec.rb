# frozen_string_literal: true

require_relative '../spec_helper'
require 'stringio'
require 'uri'

# Local-storage HTTP endpoints used by the LocalGateway in development and
# test. They mirror the S3 form-POST upload + signed-URL download contract
# so frontend code is identical across environments. The route branch is
# mounted only when the runtime environment is in {development, test} —
# production deploys must never expose them.
describe 'Local Storage Routes' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  let(:gateway) { Tyto::FileStorage.build_gateway }
  let(:upload_key)   { 'spec_uploads/sample.txt' }
  let(:download_key) { 'spec_downloads/sample.txt' }
  let(:body) { 'hello world' }

  def upload_grant_for(key)
    gateway.presign_upload(key:, allowed_extensions: nil).value!
  end

  def download_grant_for(key)
    gateway.presign_download(key:).value!
  end

  def token_from_download_url(url)
    URI.decode_www_form(URI.parse(url).query).to_h.fetch('token')
  end

  def upload_payload(key:, token:, body: 'hello world')
    fields = { 'key' => key }
    fields['token'] = token unless token.nil?
    fields['file'] = Rack::Test::UploadedFile.new(
      StringIO.new(body), 'application/octet-stream', original_filename: 'sample.bin'
    )
    fields
  end

  describe 'POST /api/_local_storage/upload' do
    after { gateway.delete(key: upload_key) }

    it 'writes the file to storage and returns 204 when the token is valid' do
      grant = upload_grant_for(upload_key)
      post '/api/_local_storage/upload',
           upload_payload(key: grant[:fields]['key'], token: grant[:fields]['token'], body: body)

      _(last_response.status).must_equal 204
      _(gateway.read(key: upload_key).value!).must_equal body
    end

    it 'returns 401 when the token is missing' do
      post '/api/_local_storage/upload', upload_payload(key: upload_key, token: nil)

      _(last_response.status).must_equal 401
    end

    it 'returns 401 when the token is malformed' do
      post '/api/_local_storage/upload',
           upload_payload(key: upload_key, token: 'not-a-real-token')

      _(last_response.status).must_equal 401
    end

    it 'returns 401 when the token was minted for a different key' do
      other_grant = upload_grant_for('a/different/key.txt')
      post '/api/_local_storage/upload',
           upload_payload(key: upload_key, token: other_grant[:fields]['token'])

      _(last_response.status).must_equal 401
    end

    it 'returns 401 when the same token is reused (single-use within its TTL)' do
      grant = upload_grant_for(upload_key)
      payload_for_first  = upload_payload(key: upload_key, token: grant[:fields]['token'], body: body)
      payload_for_replay = upload_payload(key: upload_key, token: grant[:fields]['token'], body: body)

      post '/api/_local_storage/upload', payload_for_first
      _(last_response.status).must_equal 204

      post '/api/_local_storage/upload', payload_for_replay
      _(last_response.status).must_equal 401
    end

    it 'returns 401 when the token was minted for a download (op mismatch)' do
      download_token = token_from_download_url(download_grant_for(upload_key)[:download_url])
      post '/api/_local_storage/upload',
           upload_payload(key: upload_key, token: download_token)

      _(last_response.status).must_equal 401
    end

    it 'rejects keys containing path-traversal segments even with a valid token' do
      # Mint a real token for the unsafe key so this exercises the route's
      # key validation, not its token verification.
      unsafe_key = '../etc/passwd'
      grant = gateway.presign_upload(key: unsafe_key, allowed_extensions: nil).value!
      post '/api/_local_storage/upload',
           upload_payload(key: unsafe_key, token: grant[:fields]['token'])

      _(last_response.status).must_equal 400
    end
  end

  describe 'GET /api/_local_storage/download/*key' do
    before { gateway.write(key: download_key, body: body) }
    after  { gateway.delete(key: download_key) }

    it 'returns 200 with the file bytes when the token is valid' do
      grant = download_grant_for(download_key)
      get URI(grant[:download_url]).request_uri

      _(last_response.status).must_equal 200
      _(last_response.body).must_equal body
    end

    it 'serves multi-segment keys via the splat (assignment/req/account.ext)' do
      multi_key = '42/7/3.pdf'
      gateway.write(key: multi_key, body: body)
      grant = download_grant_for(multi_key)
      begin
        get URI(grant[:download_url]).request_uri
        _(last_response.status).must_equal 200
        _(last_response.body).must_equal body
      ensure
        gateway.delete(key: multi_key)
      end
    end

    it 'returns 401 when the token query parameter is missing' do
      get "/api/_local_storage/download/#{download_key}"

      _(last_response.status).must_equal 401
    end

    it 'returns 401 when the token is malformed' do
      get "/api/_local_storage/download/#{download_key}?token=not-a-real-token"

      _(last_response.status).must_equal 401
    end

    it 'returns 401 when the token was minted for a different key' do
      other_token = token_from_download_url(
        download_grant_for('a/different/file.txt')[:download_url]
      )
      get "/api/_local_storage/download/#{download_key}?token=#{other_token}"

      _(last_response.status).must_equal 401
    end

    it 'returns 401 when the same token is reused (single-use within its TTL)' do
      grant = download_grant_for(download_key)
      uri = URI(grant[:download_url]).request_uri

      get uri
      _(last_response.status).must_equal 200

      get uri
      _(last_response.status).must_equal 401
    end

    it 'returns 401 when the token was minted for an upload (op mismatch)' do
      upload_token = upload_grant_for(download_key)[:fields]['token']
      get "/api/_local_storage/download/#{download_key}?token=#{upload_token}"

      _(last_response.status).must_equal 401
    end
  end

  describe 'environment guard (allowlist)' do
    it 'returns 404 from upload route when environment is :production' do
      Tyto::Api.stub :environment, :production do
        post '/api/_local_storage/upload', upload_payload(key: upload_key, token: 'whatever')
        _(last_response.status).must_equal 404
      end
    end

    it 'returns 404 from download route when environment is :production' do
      Tyto::Api.stub :environment, :production do
        get '/api/_local_storage/download/some/key.txt?token=whatever'
        _(last_response.status).must_equal 404
      end
    end

    it 'returns 404 from upload route for non-allowlisted environments like :staging' do
      Tyto::Api.stub :environment, :staging do
        post '/api/_local_storage/upload', upload_payload(key: upload_key, token: 'whatever')
        _(last_response.status).must_equal 404
      end
    end
  end
end
