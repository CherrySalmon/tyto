# db/seeds/account_seeds.rb

require_relative '../../app/infrastructure/database/orm/role'
require_relative '../../app/infrastructure/database/orm/account'

# Define the role descriptions
role_descriptions = ['admin', 'creator', 'member', 'owner', 'instructor', 'staff', 'student']

# Iterate over the descriptions and create roles if they don't exist
role_descriptions.each do |desc|
  Tyto::Role.find_or_create(name: desc)
end

admin_user_data = {
  "name": " ",
  "email": ENV['ADMIN_EMAIL'],
  "roles": [
    "admin", "creator"
    ]
}

# Add a new account with the provided data
Tyto::Account.add_account(admin_user_data)
