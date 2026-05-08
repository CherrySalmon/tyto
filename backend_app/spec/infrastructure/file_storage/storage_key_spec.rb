# frozen_string_literal: true

require_relative '../../spec_helper'

# StorageKey is the typed boundary between untrusted strings (HTTP params,
# token payloads) and storage operations. Holding one is a guarantee that
# the underlying string is non-blank, relative, and traversal-free.
describe Tyto::FileStorage::StorageKey do
  describe '.safe?' do
    it 'returns true for a simple relative key' do
      _(Tyto::FileStorage::StorageKey.safe?('a/b/c.txt')).must_equal true
    end

    it 'returns true for a single-segment key' do
      _(Tyto::FileStorage::StorageKey.safe?('foo.txt')).must_equal true
    end

    it 'returns false for nil' do
      _(Tyto::FileStorage::StorageKey.safe?(nil)).must_equal false
    end

    it 'returns false for the empty string' do
      _(Tyto::FileStorage::StorageKey.safe?('')).must_equal false
    end

    it 'returns false for whitespace-only strings' do
      _(Tyto::FileStorage::StorageKey.safe?("   \t\n")).must_equal false
    end

    it 'returns false for an absolute path' do
      _(Tyto::FileStorage::StorageKey.safe?('/etc/passwd')).must_equal false
    end

    it 'returns false for a key containing a .. segment' do
      _(Tyto::FileStorage::StorageKey.safe?('a/../b')).must_equal false
    end

    it 'returns false for a leading-.. key' do
      _(Tyto::FileStorage::StorageKey.safe?('../etc/passwd')).must_equal false
    end

    it 'allows segments that merely contain dots (e.g. file.tar.gz)' do
      _(Tyto::FileStorage::StorageKey.safe?('archive/file.tar.gz')).must_equal true
    end
  end

  describe '.from' do
    it 'returns a StorageKey for valid input' do
      key = Tyto::FileStorage::StorageKey.from('a/b/c.txt')
      _(key).must_be_kind_of Tyto::FileStorage::StorageKey
      _(key.value).must_equal 'a/b/c.txt'
    end

    it 'raises ArgumentError on blank input' do
      _ { Tyto::FileStorage::StorageKey.from('') }.must_raise ArgumentError
    end

    it 'raises ArgumentError on absolute paths' do
      _ { Tyto::FileStorage::StorageKey.from('/etc/passwd') }.must_raise ArgumentError
    end

    it 'raises ArgumentError on .. segments' do
      _ { Tyto::FileStorage::StorageKey.from('a/../b') }.must_raise ArgumentError
    end
  end

  describe '.try_from' do
    it 'returns a StorageKey for valid input' do
      key = Tyto::FileStorage::StorageKey.try_from('a/b/c.txt')
      _(key).must_be_kind_of Tyto::FileStorage::StorageKey
      _(key.value).must_equal 'a/b/c.txt'
    end

    it 'returns nil on blank input' do
      _(Tyto::FileStorage::StorageKey.try_from(nil)).must_be_nil
      _(Tyto::FileStorage::StorageKey.try_from('')).must_be_nil
    end

    it 'returns nil on unsafe input' do
      _(Tyto::FileStorage::StorageKey.try_from('/etc/passwd')).must_be_nil
      _(Tyto::FileStorage::StorageKey.try_from('a/../b')).must_be_nil
    end
  end

  describe '#to_s' do
    it 'returns the underlying string value' do
      _(Tyto::FileStorage::StorageKey.from('foo/bar.txt').to_s).must_equal 'foo/bar.txt'
    end
  end

  # StorageKey overrides == / eql? / hash on the StorageKey side only — we
  # can't change String#== / Hash#fetch semantics. So `key == 'string'` is
  # true but `'string' == key` is false (asymmetric). The asymmetry is fine
  # for the use cases that matter: recording-double doubles store
  # head_results keyed by string, then call `@head_results.fetch(key, ...)`
  # where key is a StorageKey — Ruby uses `key.hash` and `key.eql?(string)`,
  # both of which we control.
  describe 'equality' do
    let(:key) { Tyto::FileStorage::StorageKey.from('foo/bar.txt') }

    it 'equals another StorageKey wrapping the same string' do
      other = Tyto::FileStorage::StorageKey.from('foo/bar.txt')
      _(key).must_equal other
    end

    it 'compares equal to the underlying String value (StorageKey side)' do
      _(key == 'foo/bar.txt').must_equal true
      _(key.eql?('foo/bar.txt')).must_equal true
    end

    it 'is not equal to a different string' do
      _(key == 'something/else.txt').must_equal false
    end

    it 'is not equal to a non-string non-StorageKey value' do
      _(key == 42).must_equal false
      _(key == nil).must_equal false # rubocop:disable Style/NilComparison
    end

    it 'looks up correctly when the Hash is string-keyed and the lookup key is a StorageKey' do
      hash = { 'foo/bar.txt' => :hit }
      _(hash.fetch(key)).must_equal :hit
    end

    it 'looks up correctly when the Hash is StorageKey-keyed and the lookup is by another StorageKey' do
      hash = { key => :hit }
      _(hash.fetch(Tyto::FileStorage::StorageKey.from('foo/bar.txt'))).must_equal :hit
    end
  end
end
