# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Tyto::Types' do
  describe 'NonEmptyString' do
    it 'accepts non-empty strings' do
      _(Tyto::Types::NonEmptyString['hello']).must_equal 'hello'
    end

    it 'rejects empty strings' do
      _ { Tyto::Types::NonEmptyString[''] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'CourseName' do
    it 'accepts valid course names' do
      _(Tyto::Types::CourseName['Ruby Programming']).must_equal 'Ruby Programming'
    end

    it 'accepts single character names' do
      _(Tyto::Types::CourseName['X']).must_equal 'X'
    end

    it 'accepts names up to 200 characters' do
      long_name = 'A' * 200
      _(Tyto::Types::CourseName[long_name]).must_equal long_name
    end

    it 'rejects empty names' do
      _ { Tyto::Types::CourseName[''] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects names over 200 characters' do
      too_long = 'A' * 201
      _ { Tyto::Types::CourseName[too_long] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'Email' do
    it 'accepts valid email addresses' do
      _(Tyto::Types::Email['user@example.com']).must_equal 'user@example.com'
    end

    it 'accepts emails with dots in local part' do
      _(Tyto::Types::Email['first.last@example.com']).must_equal 'first.last@example.com'
    end

    it 'accepts emails with plus signs' do
      _(Tyto::Types::Email['user+tag@example.com']).must_equal 'user+tag@example.com'
    end

    it 'accepts emails with subdomains' do
      _(Tyto::Types::Email['user@mail.example.com']).must_equal 'user@mail.example.com'
    end

    it 'rejects emails without @' do
      _ { Tyto::Types::Email['userexample.com'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects emails without domain' do
      _ { Tyto::Types::Email['user@'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects emails without local part' do
      _ { Tyto::Types::Email['@example.com'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects plain strings' do
      _ { Tyto::Types::Email['not-an-email'] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'SystemRole' do
    it 'accepts admin role' do
      _(Tyto::Types::SystemRole['admin']).must_equal 'admin'
    end

    it 'accepts creator role' do
      _(Tyto::Types::SystemRole['creator']).must_equal 'creator'
    end

    it 'accepts member role' do
      _(Tyto::Types::SystemRole['member']).must_equal 'member'
    end

    it 'rejects course roles' do
      _ { Tyto::Types::SystemRole['owner'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects invalid roles' do
      _ { Tyto::Types::SystemRole['superuser'] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'CourseRole' do
    it 'accepts owner role' do
      _(Tyto::Types::CourseRole['owner']).must_equal 'owner'
    end

    it 'accepts instructor role' do
      _(Tyto::Types::CourseRole['instructor']).must_equal 'instructor'
    end

    it 'accepts staff role' do
      _(Tyto::Types::CourseRole['staff']).must_equal 'staff'
    end

    it 'accepts student role' do
      _(Tyto::Types::CourseRole['student']).must_equal 'student'
    end

    it 'rejects system roles' do
      _ { Tyto::Types::CourseRole['admin'] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects invalid roles' do
      _ { Tyto::Types::CourseRole['teacher'] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'Role (all roles)' do
    it 'accepts all system roles' do
      %w[admin creator member].each do |role|
        _(Tyto::Types::Role[role]).must_equal role
      end
    end

    it 'accepts all course roles' do
      %w[owner instructor staff student].each do |role|
        _(Tyto::Types::Role[role]).must_equal role
      end
    end

    it 'rejects invalid roles' do
      _ { Tyto::Types::Role['invalid'] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'EventName' do
    it 'accepts valid event names' do
      _(Tyto::Types::EventName['Lecture 1']).must_equal 'Lecture 1'
    end

    it 'accepts single character names' do
      _(Tyto::Types::EventName['X']).must_equal 'X'
    end

    it 'accepts names up to 200 characters' do
      long_name = 'A' * 200
      _(Tyto::Types::EventName[long_name]).must_equal long_name
    end

    it 'rejects empty names' do
      _ { Tyto::Types::EventName[''] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects names over 200 characters' do
      too_long = 'A' * 201
      _ { Tyto::Types::EventName[too_long] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'LocationName' do
    it 'accepts valid location names' do
      _(Tyto::Types::LocationName['Room 101']).must_equal 'Room 101'
    end

    it 'rejects empty names' do
      _ { Tyto::Types::LocationName[''] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects names over 200 characters' do
      too_long = 'A' * 201
      _ { Tyto::Types::LocationName[too_long] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'Longitude' do
    it 'accepts valid longitude values' do
      _(Tyto::Types::Longitude[121.5654]).must_equal 121.5654
    end

    it 'accepts nil (optional)' do
      _(Tyto::Types::Longitude[nil]).must_be_nil
    end

    it 'accepts boundary values' do
      _(Tyto::Types::Longitude[-180.0]).must_equal(-180.0)
      _(Tyto::Types::Longitude[180.0]).must_equal 180.0
    end

    it 'rejects values below -180' do
      _ { Tyto::Types::Longitude[-180.1] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects values above 180' do
      _ { Tyto::Types::Longitude[180.1] }.must_raise Dry::Types::ConstraintError
    end
  end

  describe 'Latitude' do
    it 'accepts valid latitude values' do
      _(Tyto::Types::Latitude[25.0330]).must_equal 25.0330
    end

    it 'accepts nil (optional)' do
      _(Tyto::Types::Latitude[nil]).must_be_nil
    end

    it 'accepts boundary values' do
      _(Tyto::Types::Latitude[-90.0]).must_equal(-90.0)
      _(Tyto::Types::Latitude[90.0]).must_equal 90.0
    end

    it 'rejects values below -90' do
      _ { Tyto::Types::Latitude[-90.1] }.must_raise Dry::Types::ConstraintError
    end

    it 'rejects values above 90' do
      _ { Tyto::Types::Latitude[90.1] }.must_raise Dry::Types::ConstraintError
    end
  end
end
