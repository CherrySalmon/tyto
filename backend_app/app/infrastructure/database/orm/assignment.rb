# frozen_string_literal: true

module Tyto
  class Assignment < Sequel::Model # rubocop:disable Style/Documentation
    plugin :validation_helpers
    plugin :timestamps, update_on_create: true
    many_to_one :course
    many_to_one :event
    one_to_many :submission_requirements, class: 'Tyto::SubmissionRequirement'

    def validate
      super
      validates_presence %i[course_id title status]
    end
  end
end
