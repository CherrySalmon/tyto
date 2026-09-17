# frozen_string_literal: true

module Tyto
  module Policy
    # Authorization for account operations
    class Account
      def initialize(requestor, account = nil)
        @requestor = requestor
        @this_account = account
      end

      # Admin can view any account;
      def can_view_all?
        requestor_is_admin?
      end

      # Only admins can create accounts
      def can_create?
        requestor_is_admin?
      end

      # Only admins can change system roles, even on their own account
      def can_change_system_roles?
        requestor_is_admin?
      end

      # Admin can view any account; account owners can view their own account
      def can_view_single?
        requestor_is_admin? || self_request?
      end

      # The full detail (roles + course memberships) is for the admin panel only
      def can_view_details?
        requestor_is_admin?
      end

      # Admin can update any account; account owners can update their own account
      def can_update?
        requestor_is_admin? || self_request?
      end

      # Only admins can delete accounts, and never their own: deleting an
      # account cascades its enrollments and attendance records, so it is an
      # admin act on someone else, not a self-service one.
      def can_delete?
        requestor_is_admin? && !self_request?
      end

      # Summary of permissions
      def summary
        {
          can_view_all: can_view_all?,
          can_view_single: can_view_single?,
          can_view_details: can_view_details?,
          can_create: can_create?,
          can_update: can_update?,
          can_change_system_roles: can_change_system_roles?,
          can_delete: can_delete?
        }
      end

      private

      # Check if the requestor is the owner of the account
      def self_request?
        @requestor.account_id == @this_account.to_i
      end

      # Check if the requestor has an admin role
      def requestor_is_admin?
        @requestor.admin?
      end
    end
  end
end
