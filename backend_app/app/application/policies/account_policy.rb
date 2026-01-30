# frozen_string_literal: true

class AccountPolicy # rubocop:disable Style/Documentation
  # attr_reader :requestor, :this_account

  def initialize(requestor, account = nil)
    @requestor = requestor
    @this_account = account
  end

  # Admin can view any account;
  def can_view_all?
    requestor_is_admin?
  end

  def can_create?
    @requestor!= nil
  end

  # Admin can view any account; account owners can view their own account
  def can_view_single?
    requestor_is_admin? || self_request?
  end

  # Admin can update any account; account owners can update their own account
  def can_update?
    requestor_is_admin? || self_request?
  end

  # Admin can delete any account; account owners can delete their own account
  def can_delete?
    requestor_is_admin? || self_request?
  end

  # Summary of permissions
  def summary
    {
      can_view_all: can_view_all?,
      can_view_single: can_view_single?,
      can_update: can_update?,
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
