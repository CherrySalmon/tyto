# frozen_string_literal: true

module Tyto
  class SubmissionEntry < Sequel::Model # rubocop:disable Style/Documentation
    plugin :validation_helpers
    plugin :timestamps, update_on_create: true
    many_to_one :submission
    many_to_one :submission_requirement, key: :requirement_id

    def validate
      super
      validates_presence %i[submission_id requirement_id content]
    end
  end
end
