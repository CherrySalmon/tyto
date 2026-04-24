# frozen_string_literal: true

module Tyto
  module Response
    # Lightweight wrapper that delegates to any entity while adding a policies hash.
    # Used by services to attach policy summaries for frontend consumption.
    #
    # Example:
    #   PolicyWrapper.new(assignment, policies: policy.summary)
    #   # => responds to all Assignment methods plus #policies
    class PolicyWrapper < SimpleDelegator
      attr_reader :policies

      def initialize(entity, policies:)
        super(entity)
        @policies = policies
      end
    end
  end
end
