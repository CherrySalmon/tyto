# frozen_string_literal: true

require_relative '../../../domain/assignments/entities/submission'
require_relative '../../../domain/assignments/entities/requirement_upload'
require_relative '../../../domain/assignments/values/requirement_uploads'
require_relative '../../../domain/assignments/values/submitter'

module Tyto
  module Repository
    # Repository for Submission aggregate root.
    # Maps between ORM records and domain entities.
    #
    # Loading conventions:
    #   find_id                                  - Submission only (entries = nil)
    #   find_with_entries                        - Submission + RequirementUploads loaded
    #   find_by_account_assignment               - Single student's submission (entries = nil)
    #   find_by_account_assignment_with_entries   - Single student's submission + entries
    #   find_by_assignment                       - All submissions for assignment (entries = nil)
    #   find_by_assignment_with_entries           - All submissions + entries
    #   find_by_assignment_full                   - All submissions + entries + submitter summaries
    #   find_by_account_assignment_full           - Single student's submission + entries + submitter
    class Submissions
      # Find a submission by ID (entries not loaded)
      def find_id(id)
        orm_record = Tyto::Submission[id]
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find a submission by ID with entries loaded
      def find_with_entries(id)
        orm_record = Tyto::Submission[id]
        return nil unless orm_record

        rebuild_entity(orm_record, load_entries: true)
      end

      # Find a student's submission for an assignment (entries not loaded)
      def find_by_account_assignment(account_id, assignment_id)
        orm_record = Tyto::Submission.first(account_id:, assignment_id:)
        return nil unless orm_record

        rebuild_entity(orm_record)
      end

      # Find a student's submission for an assignment with entries loaded
      def find_by_account_assignment_with_entries(account_id, assignment_id)
        orm_record = Tyto::Submission.first(account_id:, assignment_id:)
        return nil unless orm_record

        rebuild_entity(orm_record, load_entries: true)
      end

      # Find all submissions for an assignment (entries not loaded)
      def find_by_assignment(assignment_id)
        Tyto::Submission
          .where(assignment_id:)
          .order(:submitted_at)
          .all
          .map { |record| rebuild_entity(record) }
      end

      # Find all submissions for an assignment with entries loaded
      def find_by_assignment_with_entries(assignment_id)
        Tyto::Submission
          .where(assignment_id:)
          .order(:submitted_at)
          .all
          .map { |record| rebuild_entity(record, load_entries: true) }
      end

      # Find all submissions for an assignment with entries AND submitter summaries
      # loaded. Submitters are fetched in a single batched query to avoid N+1.
      def find_by_assignment_full(assignment_id)
        records = Tyto::Submission
                  .where(assignment_id:)
                  .order(:submitted_at)
                  .all
        submitter_by_account = submitters_by_account_id(records.map(&:account_id))
        records.map do |record|
          rebuild_entity(record,
                         load_entries: true,
                         submitter: submitter_by_account[record.account_id])
        end
      end

      # Find a student's submission with entries AND submitter loaded.
      def find_by_account_assignment_full(account_id, assignment_id)
        orm_record = Tyto::Submission.first(account_id:, assignment_id:)
        return nil unless orm_record

        submitter = submitters_by_account_id([account_id])[account_id]
        rebuild_entity(orm_record, load_entries: true, submitter:)
      end

      # Create a new submission from a domain entity
      def create(entity)
        orm_record = Tyto::Submission.create(
          assignment_id: entity.assignment_id,
          account_id: entity.account_id,
          submitted_at: entity.submitted_at.utc
        )

        rebuild_entity(orm_record)
      end

      # Create a submission with its entries
      def create_with_entries(entity, entries)
        orm_record = Tyto::Submission.create(
          assignment_id: entity.assignment_id,
          account_id: entity.account_id,
          submitted_at: entity.submitted_at.utc
        )

        entries.each do |entry|
          Tyto::SubmissionEntry.create(
            submission_id: orm_record.id,
            requirement_id: entry.requirement_id,
            content: entry.content,
            filename: entry.filename,
            content_type: entry.content_type,
            file_size: entry.file_size
          )
        end

        rebuild_entity(orm_record, load_entries: true)
      end

      # Update an existing submission (metadata only)
      def update(entity)
        orm_record = Tyto::Submission[entity.id]
        raise "Submission not found: #{entity.id}" unless orm_record

        orm_record.update(submitted_at: entity.submitted_at.utc)

        rebuild_entity(orm_record.refresh)
      end

      # Upsert entries for a submission (per-requirement match)
      def upsert_entries(submission_id, entries)
        orm_record = Tyto::Submission[submission_id]
        raise "Submission not found: #{submission_id}" unless orm_record

        entries.each do |entry|
          existing = Tyto::SubmissionEntry.first(
            submission_id:,
            requirement_id: entry.requirement_id
          )

          if existing
            existing.update(
              content: entry.content,
              filename: entry.filename,
              content_type: entry.content_type,
              file_size: entry.file_size
            )
          else
            Tyto::SubmissionEntry.create(
              submission_id:,
              requirement_id: entry.requirement_id,
              content: entry.content,
              filename: entry.filename,
              content_type: entry.content_type,
              file_size: entry.file_size
            )
          end
        end

        rebuild_entity(orm_record.refresh, load_entries: true)
      end

      # Delete a submission by ID
      def delete(id)
        orm_record = Tyto::Submission[id]
        return false unless orm_record

        orm_record.destroy
        true
      end

      # Whether any submission exists for the given assignment.
      # Cheap existence check used by authorization logic
      # (teaching staff can delete/unpublish only when no submissions exist).
      def any_for_assignment?(assignment_id)
        !Tyto::Submission.first(assignment_id:).nil?
      end

      # The subset of the given assignment IDs that have at least one submission.
      # Returns an array of integer IDs — order is not guaranteed.
      # Used by ListAssignments to build per-assignment policy summaries
      # in a single query rather than N+1.
      def assignment_ids_with_submissions(assignment_ids)
        return [] if assignment_ids.empty?

        Tyto::Submission
          .where(assignment_id: assignment_ids)
          .distinct
          .select_map(:assignment_id)
      end

      private

      def rebuild_entity(orm_record, load_entries: false, submitter: nil)
        Domain::Assignments::Entities::Submission.new(
          id: orm_record.id,
          assignment_id: orm_record.assignment_id,
          account_id: orm_record.account_id,
          submitted_at: orm_record.submitted_at,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at,
          requirement_uploads: load_entries ? build_uploads(orm_record) : nil,
          submitter:
        )
      end

      def build_uploads(orm_record)
        Domain::Assignments::Values::RequirementUploads.from(rebuild_entries(orm_record))
      end

      # Batched lookup: given a list of account IDs, return a Hash mapping each id → Submitter.
      def submitters_by_account_id(account_ids)
        return {} if account_ids.empty?

        Tyto::Account
          .where(id: account_ids.uniq)
          .all
          .each_with_object({}) do |acct, hash|
            hash[acct.id] = Domain::Assignments::Values::Submitter.new(
              account_id: acct.id, name: acct.name, email: acct.email
            )
          end
      end

      def rebuild_entries(orm_submission)
        Tyto::SubmissionEntry
          .where(submission_id: orm_submission.id)
          .order(:requirement_id)
          .all
          .map { |e| rebuild_entry(e) }
      end

      def rebuild_entry(orm_record)
        Domain::Assignments::Entities::RequirementUpload.new(
          id: orm_record.id,
          submission_id: orm_record.submission_id,
          requirement_id: orm_record.requirement_id,
          content: orm_record.content,
          filename: orm_record.filename,
          content_type: orm_record.content_type,
          file_size: orm_record.file_size,
          created_at: orm_record.created_at,
          updated_at: orm_record.updated_at
        )
      end
    end
  end
end
