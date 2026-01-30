# frozen_string_literal: true

module Todo
  # Policy to determine if account can view a dramalist
  class CoursePolicy
    # Scope of dramalist policies
    class AccountScope
      def initialize(current_account, target_account = nil)
        target_account ||= current_account
        @full_scope = all_courses(target_account)
        @own_scope = owned_courses(current_account)
        @current_account = current_account
        @target_account = target_account
      end

      def viewable
        if @current_account == @target_account
          @full_scope
        else
          @full_scope.select do |course|
            creators_include_account?(course, @current_account) ||
              staffs_include_account?(course, @current_account)
          end
        end
      end

      def ownable
        @own_scope
      end

      private

      def owned_courses(account)
        account.owned_courses.map do |course|
          policy = CoursePolicy.new(account, course)
          course.to_h.merge(policies: policy.summary)
        end
      end

      def all_courses(account)
        account.owned_courses.map do |course|
          policy = DramalistPolicy.new(account, course)
          course.to_h.merge(policies: policy.summary)
        end
      end

      def creators_include_account?(course, account)
        course.creators.include? account
      end

      def staffs_include_account?(course, account)
        course.staffs.include? account
      end
    end
  end
end
