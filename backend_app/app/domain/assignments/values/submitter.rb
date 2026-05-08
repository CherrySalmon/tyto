# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'

module Tyto
  module Domain
    module Assignments
      module Values
        # Summary view of the account that authored a Submission.
        # Lives in the Assignments context (not Accounts) to avoid the
        # aggregate crossing bounded-context boundaries with a full
        # Accounts entity. Carries just what the staff view needs.
        class Submitter < Dry::Struct
          attribute :account_id, Types::Integer
          attribute :name, Types::String.optional
          attribute :email, Types::String
        end
      end
    end
  end
end
