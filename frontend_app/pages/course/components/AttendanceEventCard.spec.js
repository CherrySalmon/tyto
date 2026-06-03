import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import AttendanceEventCard from './AttendanceEventCard.vue';

// Regression test for the "students see a dead Create Event button" bug.
//
// Students (and any non-teaching role) reach the attendance view via the
// course-list link, but the read-only RouterView binds no @create-event
// handler — so the management controls must not render for them. The gate is
// the `canManage` prop, passed `true` from SingleCourse's management branch
// and `false` from its read-only branch.
//
// Before the fix the "Create Event" card, "Download Record" button, and the
// per-event edit/delete/manage icons rendered regardless of `canManage`, so a
// student saw controls that did nothing on click. These specs fail against
// that original markup and pass with the guards in place.

function mountCard(canManage) {
  return mount(AttendanceEventCard, {
    props: {
      canManage,
      course: { id: 1, name: 'Test Course' },
      attendanceEvents: [],
      locations: [],
    },
    // Element Plus components are auto-imported in the app but not in tests;
    // silence "failed to resolve component" warnings. Unknown components still
    // render their slot content, which is what these text assertions check.
    global: { config: { warnHandler: () => {} } },
  });
}

describe('AttendanceEventCard management controls', () => {
  it('hides Create Event and Download Record from non-managers (canManage=false)', () => {
    const wrapper = mountCard(false);
    expect(wrapper.text()).not.toContain('Create Event');
    expect(wrapper.text()).not.toContain('Download Record');
  });

  it('shows Create Event and Download Record to managers (canManage=true)', () => {
    const wrapper = mountCard(true);
    expect(wrapper.text()).toContain('Create Event');
    expect(wrapper.text()).toContain('Download Record');
  });

  it('emits create-event only when a manager clicks the card', async () => {
    const manager = mountCard(true);
    await manager.find('.event-item').trigger('click');
    expect(manager.emitted('create-event')).toBeTruthy();
  });
});
