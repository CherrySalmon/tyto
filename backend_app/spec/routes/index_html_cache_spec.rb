# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Index HTML caching' do
  include Rack::Test::Methods
  include TestHelpers

  def app
    Tyto::Api
  end

  it 'serves index.html with Cache-Control: no-cache on root' do
    File.stub :read, '<html></html>' do
      get '/'
    end
    _(last_response.status).must_equal 200
    _(last_response.headers['Cache-Control']).must_equal 'no-cache'
  end

  it 'serves index.html with Cache-Control: no-cache on SPA fallback' do
    File.stub :read, '<html></html>' do
      get '/some/deep/link'
    end
    _(last_response.status).must_equal 200
    _(last_response.headers['Cache-Control']).must_equal 'no-cache'
  end
end
