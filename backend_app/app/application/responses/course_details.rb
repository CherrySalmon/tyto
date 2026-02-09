# frozen_string_literal: true

module Tyto
  module Response
    # DTO for course data with enrollment and policy summary
    CourseDetails = Data.define(
      :id, :name, :logo, :start_at, :end_at,
      :created_at, :updated_at, :enroll_identity, :policies
    )
  end
end
