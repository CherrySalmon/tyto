# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Tyto
  module Representer
    # Representer for Course entity to JSON
    class Course < Roar::Decorator
      include Roar::JSON

      property :id
      property :name
      property :logo
      property :start_at, exec_context: :decorator
      property :end_at, exec_context: :decorator
      property :created_at, exec_context: :decorator
      property :updated_at, exec_context: :decorator

      def start_at
        represented.start_at&.utc&.iso8601
      end

      def end_at
        represented.end_at&.utc&.iso8601
      end

      def created_at
        represented.created_at&.utc&.iso8601
      end

      def updated_at
        represented.updated_at&.utc&.iso8601
      end
    end

    # Representer for Course with enrollment identity
    class CourseWithEnrollment < Roar::Decorator
      include Roar::JSON

      property :id
      property :name
      property :logo
      property :start_at, exec_context: :decorator
      property :end_at, exec_context: :decorator
      property :created_at, exec_context: :decorator
      property :updated_at, exec_context: :decorator
      property :enroll_identity, exec_context: :decorator

      def start_at
        represented.start_at&.utc&.iso8601
      end

      def end_at
        represented.end_at&.utc&.iso8601
      end

      def created_at
        represented.created_at&.utc&.iso8601
      end

      def updated_at
        represented.updated_at&.utc&.iso8601
      end

      def enroll_identity
        roles = represented.respond_to?(:enroll_identity) ? represented.enroll_identity : nil
        roles.respond_to?(:to_a) ? roles.to_a : []
      end
    end

    # Representer for collection of Course entities
    class CoursesList
      def self.from_entities(entities)
        new(entities)
      end

      def initialize(entities)
        @entities = entities
      end

      def to_array
        @entities.map { |entity| Course.new(entity).to_hash }
      end
    end

    # Representer for collection of Course entities with enrollment info
    class CoursesWithEnrollmentList
      def self.from_entities(entities)
        new(entities)
      end

      def initialize(entities)
        @entities = entities
      end

      def to_array
        @entities.map { |entity| CourseWithEnrollment.new(entity).to_hash }
      end
    end

    # Representer for Enrollment entity
    class Enrollment < Roar::Decorator
      include Roar::JSON

      property :account, exec_context: :decorator
      property :enroll_identity, exec_context: :decorator

      def account
        {
          id: represented.account_id,
          email: represented.account_email,
          name: represented.account_name
        }
      end

      def enroll_identity
        represented.roles.to_a
      end
    end

    # Representer for collection of Enrollment entities
    class EnrollmentsList
      def self.from_entities(entities)
        new(entities)
      end

      def initialize(entities)
        @entities = entities
      end

      def to_array
        @entities.map { |entity| Enrollment.new(entity).to_hash }
      end
    end
  end
end
