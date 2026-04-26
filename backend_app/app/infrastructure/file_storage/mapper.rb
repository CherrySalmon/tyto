# frozen_string_literal: true

module Tyto
  module FileStorage
    # Generic constraint encoder for presigned-POST policy documents (R-P1).
    # Emits the AWS POST policy `:conditions` the Gateway hands to
    # `bucket.presigned_post`. Reusable for any future direct-to-S3 feature
    # (e.g. course materials) — submission-specific key construction lives
    # in SubmissionMapper, not here.
    #
    # The `key` equality condition pins the exact upload destination, so
    # extension enforcement is primarily delivered by server-side key
    # reconstruction (R-P2) plus pre-presign extension validation. The
    # extension condition emitted here is defence-in-depth.
    class Mapper
      def policy_conditions(key:, allowed_extensions: nil)
        validate_key!(key)

        conditions = [
          ['content-length-range', 1, Tyto::FileStorage::MAX_SIZE_BYTES],
          { 'key' => key }
        ]

        ext_condition = extension_condition(key, allowed_extensions)
        conditions << ext_condition if ext_condition

        { conditions: }
      end

      private

      def validate_key!(key)
        raise ArgumentError, 'key cannot be nil or blank' if key.nil? || key.to_s.strip.empty?
      end

      def extension_condition(key, allowed_extensions)
        return nil if allowed_extensions.nil? || allowed_extensions.empty?

        # Normalise: accept 'rmd' or '.rmd' from callers.
        allowed_extensions.map { |ext| ext.start_with?('.') ? ext : ".#{ext}" }

        prefix = key.sub(/\.[^.]+\z/, '')
        ['starts-with', '$key', prefix]
      end
    end
  end
end
