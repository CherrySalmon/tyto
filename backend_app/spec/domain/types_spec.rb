# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Todo::Types' do
  describe 'NonEmptyString' do
    it 'accepts non-empty strings' do
      _(Todo::Types::NonEmptyString['hello']).must_equal 'hello'
    end

    it 'rejects empty strings' do
      _ { Todo::Types::NonEmptyString[''] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'CourseName' do
    it 'accepts valid course names' do
      _(Todo::Types::CourseName['Ruby Programming']).must_equal 'Ruby Programming'
    end

    it 'accepts single character names' do
      _(Todo::Types::CourseName['X']).must_equal 'X'
    end

    it 'accepts names up to 200 characters' do
      long_name = 'A' * 200
      _(Todo::Types::CourseName[long_name]).must_equal long_name
    end

    it 'rejects empty names' do
      _ { Todo::Types::CourseName[''] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects names over 200 characters' do
      too_long = 'A' * 201
      _ { Todo::Types::CourseName[too_long] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'Email' do
    it 'accepts valid email addresses' do
      _(Todo::Types::Email['user@example.com']).must_equal 'user@example.com'
    end

    it 'accepts emails with dots in local part' do
      _(Todo::Types::Email['first.last@example.com']).must_equal 'first.last@example.com'
    end

    it 'accepts emails with plus signs' do
      _(Todo::Types::Email['user+tag@example.com']).must_equal 'user+tag@example.com'
    end

    it 'accepts emails with subdomains' do
      _(Todo::Types::Email['user@mail.example.com']).must_equal 'user@mail.example.com'
    end

    it 'rejects emails without @' do
      _ { Todo::Types::Email['userexample.com'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects emails without domain' do
      _ { Todo::Types::Email['user@'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects emails without local part' do
      _ { Todo::Types::Email['@example.com'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects plain strings' do
      _ { Todo::Types::Email['not-an-email'] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'SystemRole' do
    it 'accepts admin role' do
      _(Todo::Types::SystemRole['admin']).must_equal 'admin'
    end

    it 'accepts creator role' do
      _(Todo::Types::SystemRole['creator']).must_equal 'creator'
    end

    it 'accepts member role' do
      _(Todo::Types::SystemRole['member']).must_equal 'member'
    end

    it 'rejects course roles' do
      _ { Todo::Types::SystemRole['owner'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects invalid roles' do
      _ { Todo::Types::SystemRole['superuser'] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'CourseRole' do
    it 'accepts owner role' do
      _(Todo::Types::CourseRole['owner']).must_equal 'owner'
    end

    it 'accepts instructor role' do
      _(Todo::Types::CourseRole['instructor']).must_equal 'instructor'
    end

    it 'accepts staff role' do
      _(Todo::Types::CourseRole['staff']).must_equal 'staff'
    end

    it 'accepts student role' do
      _(Todo::Types::CourseRole['student']).must_equal 'student'
    end

    it 'rejects system roles' do
      _ { Todo::Types::CourseRole['admin'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects invalid roles' do
      _ { Todo::Types::CourseRole['teacher'] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'Role (all roles)' do
    it 'accepts all system roles' do
      %w[admin creator member].each do |role|
        _(Todo::Types::Role[role]).must_equal role
      end
    end

    it 'accepts all course roles' do
      %w[owner instructor staff student].each do |role|
        _(Todo::Types::Role[role]).must_equal role
      end
    end

    it 'rejects invalid roles' do
      _ { Todo::Types::Role['invalid'] }.must_raise Dry::Types::ConstraintError
    end
  end
end
