# frozen_string_literal: true
# models/account.rb

require 'sequel'

module Todo
  class Account < Sequel::Model
    plugin :validation_helpers
    # many_to_many :roles, join_table: :account_roles
    # one_to_many :account_roles
    many_to_many :attendances
    many_to_many :course
    many_to_many :roles, join_table: :account_roles

    def validate
      super
      validates_presence [:email]
      validates_unique :email
    end

    # Add a new account with the specified data
    def self.add_account(user_data)
      data = user_data.transform_keys(&:to_sym)
      account = Account.create(
        name: data[:name],
        email: data[:email],
        access_token: data[:access_token],
        avatar: data[:avatar]
      )
      data[:roles].each do |role_name|
        role = Role.find(name: role_name)
        account.add_role(role) if role
      end
      account
    end

    def update_account(user_data)
      # Update account attributes directly
      self.name = user_data['name'] if user_data['name']
      self.email = user_data['email'] if user_data['email']
      self.avatar = user_data['avatar'] if user_data['avatar']
      self.access_token = user_data['access_token'] if user_data['access_token']

      save_changes

      # Clear existing roles and associate new roles
      remove_all_roles
      user_data['roles'].each do |role_name|
        role = Role.first(name: role_name)
        add_role(role) if role
      end
      true
    end

    def attributes
      {
        id:,
        name:,
        email:,
        avatar:,
        roles: roles.map{|role| role.name}
      }
    end
  end
end
