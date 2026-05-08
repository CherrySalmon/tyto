# frozen_string_literal: true

require 'dry-struct'
require_relative '../../domain/types'

module Tyto
  module FileStorage
    # Value object representing a validated storage key. Holding one is a
    # type-level guarantee that the key is non-blank, relative (no leading
    # slash), and free of `..` segments — so any code that accepts a
    # StorageKey can hand it to filesystem or S3 operations without further
    # validation.
    #
    # Strings live at the boundaries (HTTP request params, JSON token
    # payloads, filesystem paths). Internally, code passes StorageKey
    # instances around. Use `to_s` when handing the underlying string back
    # out to a stringly-typed API.
    class StorageKey < Dry::Struct
      attribute :value, Types::String

      class << self
        # Construct a StorageKey from an untrusted string. Raises on invalid.
        def from(string)
          raise ArgumentError, "Invalid storage key: #{string.inspect}" unless safe?(string)

          new(value: string)
        end

        # Construct a StorageKey from an untrusted string. Returns nil on
        # invalid — convenient at HTTP boundaries where invalid input maps
        # to a 4xx response instead of an exception.
        def try_from(string)
          safe?(string) ? new(value: string) : nil
        end

        def safe?(string)
          return false if string.nil? || string.to_s.strip.empty?
          return false if string.start_with?('/')
          return false if string.split('/').include?('..')

          true
        end
      end

      def to_s = value
      def inspect = "#<StorageKey #{value.inspect}>"

      # Compare equal both to other StorageKey instances and to the
      # underlying String value. Lets Hash lookups keyed on either form
      # find the same bucket — useful for test recording-doubles whose
      # `head_results` map is keyed by string but receives StorageKey at
      # call time (or vice versa).
      def ==(other)
        case other
        when StorageKey then value == other.value
        when String     then value == other
        else                 false
        end
      end
      alias eql? ==

      def hash = value.hash
    end
  end
end
