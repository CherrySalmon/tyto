# frozen_string_literal: true

class RolePolicy # rubocop:disable Style/Documentation
  attr_reader :requestor, :target_account

  def initialize(requestor, target_account, new_roles)
    @requestor = requestor
    @target_account = target_account
    @new_roles = new_roles # The role being assigned to the target_account
  end

  # Admins or the account owner can read the role information
  def can_view?
    requestor_is_admin? || requestor_is_owner?
  end

  # Admins or the account owner can update roles, but only admins can assign admin roles
  def can_update?
    (!include_admin_role? || requestor_is_owner?) || requestor_is_admin?
  end

  # Summary of permissions
  def summary
    {
      can_view: can_view?,
      can_update: can_update?
    }
  end

  private

  # Check if the requestor has an admin role
  def requestor_is_admin?
    requestor.roles.any? { |role| role.values[:name] == 'admin' }
  end

  # Check if the requestor is the owner of the account
  def requestor_is_owner?
    requestor == target_account
  end

  def include_admin_role?
    @new_role == 'Admin'
  end
end
