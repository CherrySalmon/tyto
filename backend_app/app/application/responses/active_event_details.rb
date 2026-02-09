# frozen_string_literal: true

module Tyto
  module Response
    # DTO for enriched event data returned by FindActiveEvents
    # Includes user_attendance_status in addition to EventDetails fields
    ActiveEventDetails = Data.define(
      :id, :course_id, :location_id, :name,
      :start_at, :end_at, :longitude, :latitude,
      :course_name, :location_name, :user_attendance_status
    )
  end
end
