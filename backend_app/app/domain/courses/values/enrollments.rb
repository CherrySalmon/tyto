# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'
require_relative '../entities/enrollment'

module Tyto
  module Domain
    module Courses
      module Values
        # Value object wrapping a typed collection of Enrollment entities.
        # Encapsulates query methods that previously lived on Course.
        class Enrollments < Dry::Struct
          attribute :enrollments, Types::Array.of(Entities::Enrollment)

          include Enumerable

          def each(&block) = enrollments.each(&block)

          # Find an enrollment by account ID
          def find_by_account(account_id)
            enrollments.find { |e| e.account_id == account_id }
          end

          # Get all enrollments with a specific role
          def with_role(role_name)
            enrollments.select { |e| e.has_role?(role_name) }
          end

          # Get all teaching staff (owners, instructors, staff)
          def teaching_staff
            enrollments.select(&:teaching?)
          end

          # Get all students
          def students
            enrollments.select(&:student?)
          end

          # Collection queries
          def any? = enrollments.any?
          def empty? = enrollments.empty?
          def count = enrollments.size
          def length = enrollments.length
          def size = enrollments.size
          def to_a = enrollments.dup

          # Convenience constructor from array
          def self.from(enrollment_array)
            new(enrollments: enrollment_array || [])
          end
        end
      end
    end
  end
end
