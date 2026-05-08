# frozen_string_literal: true

module Tyto
  module FileStorage
    # Generic constraint encoder for presigned-POST policy documents.
    # Emits the AWS POST-policy `:conditions` array the Gateway hands to
    # `bucket.presigned_post`. Reusable for any future direct-to-S3 feature
    # (e.g. course materials) — submission-specific key construction lives
    # in SubmissionMapper, not here.
    #
    # Extension enforcement is delivered upstream of the policy doc, not in
    # it: IssueUploadGrants validates the filename's extension against the
    # requirement's allowed_types before this Mapper runs, and the `key`
    # equality condition below pins the *entire* upload key (including its
    # extension) — so a client cannot upload at a different extension via
    # the same presigned URL. The `allowed_extensions:` parameter is kept
    # for API symmetry with the rest of the upload-grants chain (and as an
    # audit/forward-compat hook); AWS POST policies don't support an
    # OR-of-extensions condition, so there's nothing meaningful to encode
    # here today.
    class Mapper
      def policy_conditions(key:, allowed_extensions: nil) # rubocop:disable Lint/UnusedMethodArgument
        {
          conditions: [
            ['content-length-range', 1, Tyto::FileStorage::MAX_SIZE_BYTES],
            { 'key' => key.to_s }
          ]
        }
      end
    end
  end
end
