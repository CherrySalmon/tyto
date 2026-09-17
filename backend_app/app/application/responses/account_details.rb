# frozen_string_literal: true

module Tyto
  module Response
    # DTO for the admin account detail: the account (roles loaded) plus its
    # course memberships.
    AccountDetails = Data.define(:account, :enrollments)
  end
end
