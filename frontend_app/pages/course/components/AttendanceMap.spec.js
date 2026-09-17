import { describe, it, expect, vi, afterEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';

vi.mock('@/lib/googleMaps.js', () => ({
  loadGoogleMaps: vi.fn(() => Promise.reject(new Error('Google Maps failed to load'))),
}));

import AttendanceMap from './AttendanceMap.vue';

afterEach(() => {
  vi.restoreAllMocks();
});

describe('AttendanceMap', () => {
  it('logs a failed Maps load instead of leaving the rejection unhandled', async () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const wrapper = mount(AttendanceMap, {
      props: { eventAttendances: [], event: { latitude: 1, longitude: 2 } },
    });
    await flushPromises();
    expect(errorSpy).toHaveBeenCalledWith(expect.objectContaining({ message: 'Google Maps failed to load' }));
    wrapper.unmount();
  });
});
