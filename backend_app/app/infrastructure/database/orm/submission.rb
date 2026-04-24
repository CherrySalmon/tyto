# frozen_string_literal: true

module Tyto
  class Submission < Sequel::Model # rubocop:disable Style/Documentation
    plugin :validation_helpers
    plugin :timestamps, update_on_create: true
    many_to_one :assignment
    many_to_one :account
    one_to_many :submission_entries, class: 'Tyto::SubmissionEntry'

    def validate
      super
      validates_presence %i[assignment_id account_id submitted_at]
    end
  end
end
