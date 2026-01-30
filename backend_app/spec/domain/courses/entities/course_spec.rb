# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Tyto::Entity::Course' do
  let(:now) { Time.now }
  let(:one_hour) { 3600 }
  let(:one_day) { 24 * 60 * 60 }

  let(:valid_attributes) do
    {
      id: 1,
      name: 'Ruby Programming',
      logo: 'ruby.png',
      start_at: now,
      end_at: now + 30 * one_day,
      created_at: now - one_day,
      updated_at: now
    }
  end

  describe 'creation' do
    it 'creates a valid course' do
      course = Tyto::Entity::Course.new(valid_attributes)

      _(course.id).must_equal 1
      _(course.name).must_equal 'Ruby Programming'
      _(course.logo).must_equal 'ruby.png'
    end

    it 'creates a course with minimal attributes' do
      course = Tyto::Entity::Course.new(
        id: nil,
        name: 'Minimal Course',
        logo: nil,
        start_at: nil,
        end_at: nil,
        created_at: nil,
        updated_at: nil
      )

      _(course.name).must_equal 'Minimal Course'
      _(course.id).must_be_nil
    end

    it 'rejects empty course name' do
      _ { Tyto::Entity::Course.new(valid_attributes.merge(name: '')) }
        .must_raise Dry::Struct::Error
    end

    it 'rejects course name over 200 characters' do
      _ { Tyto::Entity::Course.new(valid_attributes.merge(name: 'A' * 201)) }
        .must_raise Dry::Struct::Error
    end
  end

  describe 'immutability and constraint enforcement' do
    it 'enforces name constraint on updates via new()' do
      course = Tyto::Entity::Course.new(valid_attributes)

      # Valid update
      updated = course.new(name: 'Advanced Ruby')
      _(updated.name).must_equal 'Advanced Ruby'
      _(updated.id).must_equal course.id # Other attributes preserved

      # Invalid update - empty name (dry-struct wraps constraint errors)
      _ { course.new(name: '') }.must_raise Dry::Struct::Error
    end

    it 'preserves other attributes on partial update' do
      course = Tyto::Entity::Course.new(valid_attributes)
      updated = course.new(logo: 'new_logo.png')

      _(updated.logo).must_equal 'new_logo.png'
      _(updated.name).must_equal course.name
      _(updated.id).must_equal course.id
      _(updated.start_at).must_equal course.start_at
    end
  end

  describe '#time_range' do
    it 'returns TimeRange when start and end times exist' do
      course = Tyto::Entity::Course.new(valid_attributes)

      _(course.time_range).must_be_instance_of Tyto::Value::TimeRange
      _(course.time_range.start_at).must_equal course.start_at
      _(course.time_range.end_at).must_equal course.end_at
      _(course.time_range.present?).must_equal true
    end

    it 'returns NullTimeRange when start_at is missing' do
      course = Tyto::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.time_range).must_be_instance_of Tyto::Value::NullTimeRange
      _(course.time_range.null?).must_equal true
    end

    it 'returns NullTimeRange when end_at is missing' do
      course = Tyto::Entity::Course.new(valid_attributes.merge(end_at: nil))

      _(course.time_range).must_be_instance_of Tyto::Value::NullTimeRange
      _(course.time_range.null?).must_equal true
    end
  end

  describe '#duration' do
    it 'returns duration in seconds' do
      course = Tyto::Entity::Course.new(valid_attributes)

      _(course.duration).must_equal 30 * one_day
    end

    it 'returns 0 when dates are missing (via NullTimeRange)' do
      course = Tyto::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.duration).must_equal 0
    end
  end

  describe '#active?' do
    it 'returns true for currently running course' do
      course = Tyto::Entity::Course.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(course.active?).must_equal true
    end

    it 'returns false for future course' do
      course = Tyto::Entity::Course.new(
        valid_attributes.merge(
          start_at: now + one_hour,
          end_at: now + 2 * one_hour
        )
      )

      _(course.active?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      course = Tyto::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.active?).must_equal false
    end
  end

  describe '#upcoming?' do
    it 'returns true for future course' do
      course = Tyto::Entity::Course.new(
        valid_attributes.merge(
          start_at: now + one_hour,
          end_at: now + 2 * one_hour
        )
      )

      _(course.upcoming?).must_equal true
    end

    it 'returns false for current course' do
      course = Tyto::Entity::Course.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(course.upcoming?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      course = Tyto::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.upcoming?).must_equal false
    end
  end

  describe '#ended?' do
    it 'returns true for past course' do
      course = Tyto::Entity::Course.new(
        valid_attributes.merge(
          start_at: now - 2 * one_hour,
          end_at: now - one_hour
        )
      )

      _(course.ended?).must_equal true
    end

    it 'returns false for current course' do
      course = Tyto::Entity::Course.new(
        valid_attributes.merge(
          start_at: now - one_hour,
          end_at: now + one_hour
        )
      )

      _(course.ended?).must_equal false
    end

    it 'returns false when dates are missing (via NullTimeRange)' do
      course = Tyto::Entity::Course.new(valid_attributes.merge(start_at: nil))

      _(course.ended?).must_equal false
    end
  end

  describe 'child collections' do
    let(:event1) do
      Tyto::Entity::Event.new(
        id: 1, course_id: 1, location_id: 1, name: 'Event 1',
        start_at: now, end_at: now + one_hour,
        created_at: now, updated_at: now
      )
    end

    let(:event2) do
      Tyto::Entity::Event.new(
        id: 2, course_id: 1, location_id: 1, name: 'Event 2',
        start_at: now + one_hour, end_at: now + 2 * one_hour,
        created_at: now, updated_at: now
      )
    end

    let(:location1) do
      Tyto::Entity::Location.new(
        id: 1, course_id: 1, name: 'Room A',
        longitude: 121.5654, latitude: 25.0330,
        created_at: now, updated_at: now
      )
    end

    describe 'default state (not loaded)' do
      it 'has nil events by default' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _(course.events).must_be_nil
        _(course.events_loaded?).must_equal false
      end

      it 'has nil locations by default' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _(course.locations).must_be_nil
        _(course.locations_loaded?).must_equal false
      end
    end

    describe 'loaded state' do
      it 'can have events loaded (empty)' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(events: []))

        _(course.events).must_equal []
        _(course.events_loaded?).must_equal true
      end

      it 'can have events loaded (with data)' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(events: [event1, event2]))

        _(course.events.length).must_equal 2
        _(course.events_loaded?).must_equal true
      end

      it 'can have locations loaded (empty)' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(locations: []))

        _(course.locations).must_equal []
        _(course.locations_loaded?).must_equal true
      end

      it 'can have locations loaded (with data)' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(locations: [location1]))

        _(course.locations.length).must_equal 1
        _(course.locations_loaded?).must_equal true
      end
    end

    describe '#find_event' do
      it 'finds event by ID when events are loaded' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(events: [event1, event2]))

        found = course.find_event(2)
        _(found.name).must_equal 'Event 2'
      end

      it 'returns nil when event not found' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(events: [event1]))

        _(course.find_event(999)).must_be_nil
      end

      it 'raises ChildrenNotLoadedError when events not loaded' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _ { course.find_event(1) }
          .must_raise Tyto::Entity::Course::ChildrenNotLoadedError
      end
    end

    describe '#find_location' do
      it 'finds location by ID when locations are loaded' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(locations: [location1]))

        found = course.find_location(1)
        _(found.name).must_equal 'Room A'
      end

      it 'returns nil when location not found' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(locations: [location1]))

        _(course.find_location(999)).must_be_nil
      end

      it 'raises ChildrenNotLoadedError when locations not loaded' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _ { course.find_location(1) }
          .must_raise Tyto::Entity::Course::ChildrenNotLoadedError
      end
    end

    describe '#event_count' do
      it 'returns count when events are loaded' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(events: [event1, event2]))

        _(course.event_count).must_equal 2
      end

      it 'returns 0 for empty events' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(events: []))

        _(course.event_count).must_equal 0
      end

      it 'raises ChildrenNotLoadedError when events not loaded' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _ { course.event_count }
          .must_raise Tyto::Entity::Course::ChildrenNotLoadedError
      end
    end

    describe '#location_count' do
      it 'returns count when locations are loaded' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(locations: [location1]))

        _(course.location_count).must_equal 1
      end

      it 'returns 0 for empty locations' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(locations: []))

        _(course.location_count).must_equal 0
      end

      it 'raises ChildrenNotLoadedError when locations not loaded' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _ { course.location_count }
          .must_raise Tyto::Entity::Course::ChildrenNotLoadedError
      end
    end
  end

  describe 'enrollment collection' do
    # Helper to create CourseRoles
    let(:course_roles) { ->(arr) { Tyto::Domain::Courses::Values::CourseRoles.from(arr) } }

    let(:owner_enrollment) do
      Tyto::Entity::Enrollment.new(
        id: 1, account_id: 10, course_id: 1,
        account_email: 'owner@example.com', account_name: 'Owner',
        roles: course_roles.call(['owner']),
        created_at: now, updated_at: now
      )
    end

    let(:instructor_enrollment) do
      Tyto::Entity::Enrollment.new(
        id: 2, account_id: 20, course_id: 1,
        account_email: 'instructor@example.com', account_name: 'Instructor',
        roles: course_roles.call(['instructor']),
        created_at: now, updated_at: now
      )
    end

    let(:student_enrollment) do
      Tyto::Entity::Enrollment.new(
        id: 3, account_id: 30, course_id: 1,
        account_email: 'student@example.com', account_name: 'Student',
        roles: course_roles.call(['student']),
        created_at: now, updated_at: now
      )
    end

    let(:multi_role_enrollment) do
      Tyto::Entity::Enrollment.new(
        id: 4, account_id: 40, course_id: 1,
        account_email: 'ta@example.com', account_name: 'TA',
        roles: course_roles.call(%w[staff student]),
        created_at: now, updated_at: now
      )
    end

    describe 'default state (not loaded)' do
      it 'has nil enrollments by default' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _(course.enrollments).must_be_nil
        _(course.enrollments_loaded?).must_equal false
      end
    end

    describe 'loaded state' do
      it 'can have enrollments loaded (empty)' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments: []))

        _(course.enrollments).must_equal []
        _(course.enrollments_loaded?).must_equal true
      end

      it 'can have enrollments loaded (with data)' do
        enrollments = [owner_enrollment, instructor_enrollment, student_enrollment]
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments:))

        _(course.enrollments.length).must_equal 3
        _(course.enrollments_loaded?).must_equal true
      end
    end

    describe '#find_enrollment' do
      it 'finds enrollment by account ID when loaded' do
        enrollments = [owner_enrollment, student_enrollment]
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments:))

        found = course.find_enrollment(30)
        _(found.account_email).must_equal 'student@example.com'
      end

      it 'returns nil when enrollment not found' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments: [owner_enrollment]))

        _(course.find_enrollment(999)).must_be_nil
      end

      it 'raises ChildrenNotLoadedError when not loaded' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _ { course.find_enrollment(10) }
          .must_raise Tyto::Entity::Course::ChildrenNotLoadedError
      end
    end

    describe '#enrollment_count' do
      it 'returns count when loaded' do
        enrollments = [owner_enrollment, student_enrollment]
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments:))

        _(course.enrollment_count).must_equal 2
      end

      it 'returns 0 for empty enrollments' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments: []))

        _(course.enrollment_count).must_equal 0
      end

      it 'raises ChildrenNotLoadedError when not loaded' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _ { course.enrollment_count }
          .must_raise Tyto::Entity::Course::ChildrenNotLoadedError
      end
    end

    describe '#enrollments_with_role' do
      it 'returns enrollments with specific role' do
        enrollments = [owner_enrollment, instructor_enrollment, student_enrollment, multi_role_enrollment]
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments:))

        students = course.enrollments_with_role('student')
        _(students.length).must_equal 2 # student + multi_role (has student)
      end

      it 'returns empty array when no match' do
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments: [student_enrollment]))

        _(course.enrollments_with_role('owner')).must_equal []
      end

      it 'raises ChildrenNotLoadedError when not loaded' do
        course = Tyto::Entity::Course.new(valid_attributes)

        _ { course.enrollments_with_role('student') }
          .must_raise Tyto::Entity::Course::ChildrenNotLoadedError
      end
    end

    describe '#teaching_staff' do
      it 'returns all teaching enrollments' do
        enrollments = [owner_enrollment, instructor_enrollment, student_enrollment, multi_role_enrollment]
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments:))

        staff = course.teaching_staff
        _(staff.length).must_equal 3 # owner, instructor, multi_role (has staff)
      end

      it 'excludes student-only enrollments' do
        enrollments = [student_enrollment]
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments:))

        _(course.teaching_staff).must_equal []
      end
    end

    describe '#students' do
      it 'returns all student enrollments' do
        enrollments = [owner_enrollment, instructor_enrollment, student_enrollment, multi_role_enrollment]
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments:))

        students = course.students
        _(students.length).must_equal 2 # student + multi_role (has student)
      end

      it 'excludes non-student enrollments' do
        enrollments = [owner_enrollment, instructor_enrollment]
        course = Tyto::Entity::Course.new(valid_attributes.merge(enrollments:))

        _(course.students).must_equal []
      end
    end
  end
end
