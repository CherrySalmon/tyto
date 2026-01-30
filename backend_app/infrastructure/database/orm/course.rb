# frozen_string_literal: true

# models/course.rb

require 'sequel'

module Todo
  class Course < Sequel::Model
    plugin :validation_helpers
    many_to_many :events
    one_to_many :locations

    many_to_many :attendances, join_table: :account_course_roles
    many_to_many :roles, join_table: :account_course_roles
    many_to_many :accounts, join_table: :account_course_roles

    plugin :timestamps, update_on_create: true

    def validate
      super
      validates_presence %i[name]
    end

    def self.listByAccountID(account_id)
      # Fetching courses associated with the given account_id
      account_courses = AccountCourse.where(account_id: account_id).all

      # Prepare a structure to hold the final aggregated results
      aggregated_courses = {}

      account_courses.each do |ac|
        course = ac.course
        role = ac.role.name if ac.role # Assuming the role object exists and has a 'name' method

        # Initialize the course in the aggregated_courses hash if it hasn't been added yet
        unless aggregated_courses[course.id]
          aggregated_courses[course.id] = course.attributes.merge(enroll_identity: [])
        end

        # Add the role to the course's enroll_identity array
        aggregated_courses[course.id][:enroll_identity] << role if role
      end

      # Remove duplicate roles and return the values of the aggregated_courses hash
      aggregated_courses.values.each { |course| course[:enroll_identity].uniq! }

      aggregated_courses.values
    end

    def self.create_course(account_id, course_data)
      course = Course.create(course_data)
      owner_role = Role.first(name: 'owner')
      account = Account.first(id: account_id)

      if course && owner_role
        account_course = AccountCourse.create(role: owner_role, account: account, course: course)
      else
        raise Sequel::Rollback, "Course or owner role not found"
      end
      course
    end

    def attributes(account_id = nil)
      {
        id: id,
        name: name,
        created_at: created_at&.utc&.iso8601,
        updated_at: updated_at&.utc&.iso8601,
        logo: logo,
        start_at: start_at&.utc&.iso8601,
        end_at: end_at&.utc&.iso8601,
        enroll_identity: account_id ? get_enroll_identity(account_id) : {}
      }
    end

    def add_or_update_enrollments(enrolled_data)
      enrolled_data.each do |enrollment|
        account = add_or_find_account(enrollment['email'])
        update_course_account_roles(account, enrollment['roles'])
      end
    end

    def update_single_enrollment(account_id, enrolled_data)
      account_course = AccountCourse.first(account_id: account_id, course_id: self.id)

      return unless account_course

      account = account_course.account

      # Only update email if provided
      if enrolled_data['email']
        account_email_exist = Account.first(email: enrolled_data['email'])

        if (account_email_exist != account) && account_email_exist && account_email_exist.id != account_id
          raise "Email already exists with a different account. Operation aborted."
        else
          account.update(email: enrolled_data['email'])
        end
      end

      update_course_account_roles(account, enrolled_data['roles'])
    end

    def get_enrollments
      # Fetch all enrollments for the course
      enrollments = AccountCourse.where(course_id: self.id).all

      # Fetch all unique accounts associated with these enrollments
      account_ids = enrollments.map(&:account_id).uniq
      accounts = Account.where(id: account_ids).all

      # Manually build a hash to map account IDs to account objects for quick lookup
      accounts_hash = {}
      accounts.each { |account| accounts_hash[account.id] = account }

      # Group enrollments by account_id and process each group
      grouped_enrollments = enrollments.group_by(&:account_id)
      account_roles = grouped_enrollments.map do |account_id, account_courses|
        roles = account_courses.map do |ac|
          ac.role.name
        end.uniq

        account = accounts_hash[account_id]
        {
          account: account.values,
          enroll_identity: roles
        }
      end

      account_roles
    end


    private

    def get_enroll_identity(account_id)
      account_course_role = AccountCourse.where(account_id: account_id, course_id: self.id).map do |role|
        role.role.name
      end
      account_course_role
    end

    def add_or_find_account(email)
      account = Account.first(email: email)
      unless account
        account = Account.create(email: email)
        role = Role.first(name: 'member')
        account.add_role(role)
      end
      account
    end

    def update_course_account_roles(account, roles_string)
      role_names = roles_string.split(',')

      # Find existing roles for the account in the context of the course
      existing_roles = AccountCourse.where(account_id: account.id, course_id: self.id).map(&:role)

      # Delete any roles not included in the new list
      existing_roles.each do |existing_role|
        unless role_names.include?(existing_role.name)
          AccountCourse.where(account_id: account.id, course_id: self.id, role_id: existing_role.id).delete
        end
      end

      # Add or update roles from the roles_string
      role_names.each do |role_name|
        role_id = Role.first(name: role_name).id
        next unless AccountCourse.where(account_id: account.id, course_id: self.id, role_id: role_id)

        account_course_entry = AccountCourse.find_or_create(account_id: account.id, course_id: self.id, role_id: role_id)

      end
    end
  end
end
