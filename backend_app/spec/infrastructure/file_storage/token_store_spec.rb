# frozen_string_literal: true

require_relative '../../spec_helper'

# Regression cover for the single-use guarantee under concurrency. The
# replay-check + consume sequence in `verify` must be atomic — Puma is
# multi-threaded, so without the mutex two concurrent verifies of the same
# token can both pass the replay check before either marks the nonce
# consumed, defeating the single-use design.

describe 'Tyto::FileStorage::TokenStore concurrent verify' do
  let(:store) { Tyto::FileStorage::TokenStore.new(signing_key: 'test-key-for-token-store-spec') }
  let(:token) { store.mint(key: '1/2/3.pdf', operation: 'upload', ttl: 60) }

  it 'returns :ok exactly once across N concurrent verifies of the same token' do
    threads = 50.times.map do
      Thread.new { store.verify(token:, key: '1/2/3.pdf', expected_op: 'upload') }
    end
    results = threads.map(&:value)

    _(results.count(:ok)).must_equal 1
    _(results.count(:replayed)).must_equal 49
  end
end
