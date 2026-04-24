# frozen_string_literal: true

# Loaded automatically by `rake console` (pry).
# Auto-formats Sequel model arrays as readable tables via table_print.
# Dev/ops convenience; has no effect on the app or tests.

begin
  require 'table_print'

  if defined?(Tyto::Course)
    tp.set Tyto::Course,       :id, :name
    tp.set Tyto::Event,        :id, :course_id, :location_id, :name, :start_at, :end_at
    tp.set Tyto::Location,     :id, :course_id, :name, :latitude, :longitude
    tp.set Tyto::Account,      :id, :email, :name
    tp.set Tyto::Attendance,   :id, :event_id, :account_id, :role_id, :name
    tp.set Tyto::Role,         :id, :name
    tp.set Tyto::AccountRole,  :account_id, :role_id
    tp.set Tyto::AccountCourse, :account_id, :course_id, :role_id
  end

  # Render bare Sequel model arrays as tables (mimics the old Hirb UX).
  # TablePrint::Printer.table_print returns a String — we write it ourselves
  # from inside the Pry print hook.
  old_print = Pry.config.print
  Pry.config.print = proc do |output, value, *rest|
    if value.is_a?(Array) && value.first.is_a?(Sequel::Model)
      output.puts TablePrint::Printer.table_print(value)
    else
      old_print.call(output, value, *rest)
    end
  end

  puts 'table_print enabled — Sequel model arrays auto-render as tables.'
rescue LoadError
  # table_print not installed (e.g. in a slim prod image). Silently skip.
end
