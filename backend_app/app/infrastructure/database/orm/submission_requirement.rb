# frozen_string_literal: true

module Tyto
  class SubmissionRequirement < Sequel::Model # rubocop:disable Style/Documentation
    plugin :validation_helpers
    plugin :timestamps, update_on_create: true
    many_to_one :assignment

    def validate
      super
      validates_presence %i[assignment_id submission_format description]
    end
  end
end
