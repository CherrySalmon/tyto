# frozen_string_literal: true

module Tyto
  module FileStorage
    # Submission-specific S3 key construction (R2). Used by
    # `IssueUploadUrls` to mint keys from authenticated context, and by
    # `CreateSubmission` to reconstruct keys for HEAD verification (R-P2) —
    # single source of truth so the reconstructed key is bit-identical to the
    # one issued at presign time.
    #
    # URL-type requirements never go through this mapper (Q3 un-unify); their
    # `content` stays as a raw URL string.
    module SubmissionMapper
      module_function

      def build_key(assignment_id:, requirement_id:, account_id:, filename:, submission_format:)
        validate_format!(submission_format)
        validate_id!(assignment_id, :assignment_id)
        validate_id!(requirement_id, :requirement_id)
        validate_id!(account_id, :account_id)
        ext = extract_extension(filename)

        "#{assignment_id}/#{requirement_id}/#{account_id}.#{ext}"
      end

      def validate_format!(submission_format)
        return if submission_format == 'file'

        raise ArgumentError,
              "submission_format must be 'file' (got #{submission_format.inspect})"
      end

      def validate_id!(value, name)
        raise ArgumentError, "#{name} must be a positive integer (got #{value.inspect})" \
          unless value.is_a?(Integer) && value.positive?
      end

      def extract_extension(filename)
        raise ArgumentError, 'filename cannot be blank' if filename.nil? || filename.to_s.empty?

        ext = File.extname(filename).delete_prefix('.').downcase
        raise ArgumentError, "filename must have an extension (got #{filename.inspect})" if ext.empty?

        ext
      end

      private_class_method :validate_format!, :validate_id!, :extract_extension
    end
  end
end
