# frozen_string_literal: true

module Tyto
  module Response
    # Standardized API response object for service results
    # Used with dry-monads Success/Failure to carry response information
    ApiResult = Struct.new(:status, :message) do
      # HTTP status codes mapped to symbols
      HTTP_CODE = {
        ok: 200,
        created: 201,
        accepted: 202,
        no_content: 204,
        bad_request: 400,
        unauthorized: 401,
        forbidden: 403,
        not_found: 404,
        conflict: 409,
        unprocessable: 422,
        internal_error: 500
      }.freeze

      SUCCESS_STATUSES = %i[ok created accepted no_content].freeze
      FAILURE_STATUSES = %i[bad_request unauthorized forbidden not_found conflict unprocessable internal_error].freeze
      VALID_STATUSES = (SUCCESS_STATUSES + FAILURE_STATUSES).freeze

      def initialize(status:, message:)
        raise ArgumentError, "Invalid status: #{status}" unless VALID_STATUSES.include?(status)

        super(status, message)
      end

      def http_status_code
        HTTP_CODE[status]
      end

      def success?
        SUCCESS_STATUSES.include?(status)
      end

      def failure?
        !success?
      end

      def to_json(*_args)
        if success?
          { success: true, data: message }.to_json
        else
          { error: status.to_s.tr('_', ' ').capitalize, details: message }.to_json
        end
      end
    end
  end
end
