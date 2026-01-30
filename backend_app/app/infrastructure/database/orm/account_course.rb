# models/account_course.rb

require 'sequel'

module Todo
  class AccountCourse < Sequel::Model(:account_course_roles)
    many_to_one :account
    many_to_one :course
    many_to_one :role

    plugin :validation_helpers
    
    def validate
      super
      validates_presence [:account_id, :course_id, :role]
    end

    def attributes()
      {
        id: id,
        account: account,
        course: course,
        role: role
      }
    end
  end
end
