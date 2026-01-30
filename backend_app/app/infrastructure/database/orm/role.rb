# frozen_string_literal: true
# models/role.rb

require 'sequel'

module Todo
  class Role < Sequel::Model
    # You can also add validations for the model
    plugin :validation_helpers
    many_to_many :accounts, join_table: :account_roles

    def validate
      super
      validates_presence :name
      validates_unique :name
    end
  end
end
