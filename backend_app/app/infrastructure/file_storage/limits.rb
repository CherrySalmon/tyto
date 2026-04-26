# frozen_string_literal: true

module Tyto
  module FileStorage
    # Single source of truth for the per-file upload cap (R-P7, Q8).
    # Referenced by the Mapper's presigned-POST policy doc, by
    # CreateSubmission's file-size validator, and (via 3.18) by the frontend.
    MAX_SIZE_BYTES = 10 * 1024 * 1024
  end
end
