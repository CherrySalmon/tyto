import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import AccountDetailDialog from './AccountDetailDialog.vue';
import api from '@/lib/tytoApi';

vi.mock('@/lib/tytoApi', () => ({ default: { get: vi.fn() } }));

const stubs = {
  ElDialog: { props: ['modelValue', 'title'], template: '<div><slot /><slot name="footer" /></div>' },
  ElButton: { props: ['disabled', 'type'], emits: ['click'], template: '<button @click="$emit(\'click\')"><slot /></button>' },
  ElTag: { props: ['type', 'size'], template: '<span class="stub-tag"><slot /></span>' },
  ElAvatar: { props: ['src', 'size', 'shape'], template: '<span class="stub-avatar"></span>' },
  ElAlert: { props: ['title', 'type', 'closable'], template: '<div class="stub-alert">{{ title }}</div>' },
};

const detail = {
  id: 9,
  name: 'Lin Chen',
  email: 'lin.chen@example.edu',
  avatar: null,
  roles: ['creator', 'member'],
  created_at: '2026-09-15T08:30:00Z',
  enrollments: [
    { course_id: 1, course_name: 'Service Design', roles: ['owner'] },
    { course_id: 2, course_name: 'Research Methods', roles: ['staff', 'student'] },
  ],
};

function mountDialog(props = {}) {
  return mount(AccountDetailDialog, {
    props: { modelValue: true, accountId: 9, ...props },
    global: { components: stubs, config: { warnHandler: () => {} } },
  });
}

beforeEach(() => api.get.mockReset());

// Plan Q3: a separate detail view with the account's info and a scrollable,
// read-only list of its course enrollments, loaded from GET /account/:id.
describe('AccountDetailDialog', () => {
  it('loads the account detail when opened', async () => {
    api.get.mockResolvedValue({ status: 200, data: { data: detail } });
    mountDialog();
    await flushPromises();

    expect(api.get).toHaveBeenCalledWith('/account/9');
  });

  it('shows identity, system roles, added-on date, and each enrollment with its course roles', async () => {
    api.get.mockResolvedValue({ status: 200, data: { data: detail } });
    const wrapper = mountDialog();
    await flushPromises();
    const text = wrapper.text();

    expect(text).toContain('Lin Chen');
    expect(text).toContain('lin.chen@example.edu');
    expect(text).toContain('Creator');
    expect(text).toContain('Member');
    expect(text).toContain('2026-09-15');
    expect(text).toMatch(/2 courses/);
    expect(text).toContain('Service Design');
    expect(text).toContain('owner');
    expect(text).toContain('Research Methods');
    expect(text).toContain('staff');
    expect(text).toContain('student');
  });

  it('says so when the account has no enrollments', async () => {
    api.get.mockResolvedValue({ status: 200, data: { data: { ...detail, enrollments: [] } } });
    const wrapper = mountDialog();
    await flushPromises();

    expect(wrapper.text()).toMatch(/not enrolled in any course/i);
  });

  it('reloads when pointed at another account while open', async () => {
    api.get.mockResolvedValue({ status: 200, data: { data: detail } });
    const wrapper = mountDialog();
    await flushPromises();

    await wrapper.setProps({ accountId: 12 });
    await flushPromises();

    expect(api.get).toHaveBeenLastCalledWith('/account/12');
  });
});
