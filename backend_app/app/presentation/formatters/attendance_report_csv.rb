# frozen_string_literal: true

require 'csv'

module Tyto
  module Presentation
    module Formatters
      # Formats an AttendanceReport entity as CSV
      # Columns: Student Email, attend_sum, attend_percent, ...event_names
      class AttendanceReportCsv
        def self.to_csv(report)
          events = report.events
          event_names = events.map(&:name)

          CSV.generate do |csv|
            csv << ['Student Email', 'attend_sum', 'attend_percent', *event_names]

            report.student_records.each do |record|
              event_values = events.map { |e| record.event_attendance[e.id] }
              csv << [record.email, record.attend_sum, record.attend_percent, *event_values]
            end
          end
        end
      end
    end
  end
end
