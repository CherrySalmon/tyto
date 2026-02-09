# frozen_string_literal: true

module Tyto
  module Response
    # DTO for enriched event data returned by ListEvents
    EventDetails = Data.define(
      :id, :course_id, :location_id, :name,
      :start_at, :end_at, :longitude, :latitude,
      :course_name, :location_name
    )
  end
end
