# frozen_string_literal: true

require 'dry/operation'

require_relative '../responses/api_result'

module Tyto
  module Service
    # Base class for all service operations
    # Provides common response helpers to reduce duplication across services
    #
    # Usage:
    #   class CreateEvent < Service::ApplicationOperation
    #     def call(...)
    #       # Can use bad_request, not_found, forbidden, internal_error helpers
    #     end
    #   end
    class ApplicationOperation < Dry::Operation
      private

      # Response helpers - wrap messages in ApiResult for consistent error handling
      def ok(message) = Response::ApiResult.new(status: :ok, message:)
      def created(message) = Response::ApiResult.new(status: :created, message:)
      def bad_request(message) = Response::ApiResult.new(status: :bad_request, message:)
      def not_found(message) = Response::ApiResult.new(status: :not_found, message:)
      def forbidden(message) = Response::ApiResult.new(status: :forbidden, message:)
      def internal_error(message) = Response::ApiResult.new(status: :internal_error, message:)
    end
  end
end
