# frozen_string_literal: true

require 'ostruct'
require 'roar/decorator'
require 'roar/json'

module Tyto
  module Representer
    # Serializes RequirementUpload entity to JSON.
    #
    # `download_url` is emitted only when the caller passes user_options carrying
    # `can_download: true`, a `requirements_by_id` lookup containing the matching
    # requirement, and `course_id` / `assignment_id`. The URL points at a backend
    # route that authorizes and 302-redirects to a freshly-minted presigned GET
    # — render-time presigned URLs would silently expire on long-open views.
    # URL-type entries (where `submission_format` is `url`) never get a
    # `download_url`; the raw URL in `content` is the link.
    #
    # `user_options` is captured in `to_hash` and re-used by the `download_url`
    # method. Roar/Representable does not pass user_options to plain decorator
    # methods, and its getter-lambda calling convention is awkward in this gem
    # version, so the override keeps the property method ordinary.
    class RequirementUploadRepr < Roar::Decorator
      include Roar::JSON

      property :id
      property :submission_id
      property :requirement_id
      property :content
      property :filename
      property :content_type
      property :file_size
      property :created_at, exec_context: :decorator
      property :updated_at, exec_context: :decorator
      property :download_url, exec_context: :decorator

      def to_hash(options = {})
        @user_options = options[:user_options] || {}
        super
      end

      def created_at
        represented.created_at&.utc&.iso8601
      end

      def updated_at
        represented.updated_at&.utc&.iso8601
      end

      def download_url
        opts = @user_options || {}
        return nil unless opts[:can_download]

        requirement = opts[:requirements_by_id]&.[](represented.requirement_id)
        return nil unless requirement&.submission_format == 'file'

        course_id     = opts[:course_id]
        assignment_id = opts[:assignment_id]
        return nil unless course_id && assignment_id

        "/api/course/#{course_id}/assignments/#{assignment_id}" \
          "/submissions/#{represented.submission_id}/uploads/#{represented.id}/download"
      end
    end

    # Serializes Submitter value object (student identity summary on a submission)
    class SubmitterRepr < Roar::Decorator
      include Roar::JSON

      property :account_id
      property :name
      property :email
    end

    # Serializes Submission domain entity to JSON
    class Submission < Roar::Decorator
      include Roar::JSON

      property :id
      property :assignment_id
      property :account_id
      property :submitted_at, exec_context: :decorator
      property :created_at, exec_context: :decorator
      property :updated_at, exec_context: :decorator
      collection :requirement_uploads, extend: RequirementUploadRepr,
                                       exec_context: :decorator
      property :submitter, extend: SubmitterRepr, exec_context: :decorator
      property :policies, exec_context: :decorator

      def submitted_at
        represented.submitted_at&.utc&.iso8601
      end

      def created_at
        represented.created_at&.utc&.iso8601
      end

      def updated_at
        represented.updated_at&.utc&.iso8601
      end

      def requirement_uploads
        return [] unless represented.uploads_loaded?

        represented.requirement_uploads.to_a
      end

      def submitter
        represented.submitter
      end

      def policies
        represented.respond_to?(:policies) ? represented.policies : nil
      end
    end

    # Serializes a collection of Submission entities to JSON array
    class SubmissionsList < Roar::Decorator
      include Roar::JSON

      collection :entries, extend: Representer::Submission, class: OpenStruct

      def self.from_entities(submissions)
        wrapper = OpenStruct.new(entries: submissions)
        new(wrapper)
      end

      def to_array(user_options: {})
        ::JSON.parse(to_json(user_options:))['entries']
      end
    end
  end
end
