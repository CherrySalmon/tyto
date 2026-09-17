import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import AddAccountsDialog from './AddAccountsDialog.vue';
import api from '@/lib/tytoApi';

vi.mock('@/lib/tytoApi', () => ({ default: { post: vi.fn(), put: vi.fn() } }));

// Element Plus is auto-imported in the app but not in tests. These stubs keep
// the accessible shape the specs rely on: a dialog that renders its footer, a
// button that honours :disabled, a textarea bound to v-model, and a select
// that emits update:modelValue + change like el-select does.
const stubs = {
  ElDialog: { props: ['modelValue', 'title'], template: '<div class="stub-dialog"><slot /><slot name="footer" /></div>' },
  ElButton: {
    props: ['disabled', 'loading', 'type'],
    emits: ['click'],
    template: '<button :disabled="disabled || loading" @click="$emit(\'click\')"><slot /></button>',
  },
  ElInput: {
    props: ['modelValue', 'type', 'rows', 'placeholder'],
    emits: ['update:modelValue'],
    template: '<textarea :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)"></textarea>',
  },
  ElSelect: {
    name: 'ElSelectStub',
    props: ['modelValue', 'multiple', 'placeholder'],
    emits: ['update:modelValue', 'change'],
    template: '<div class="stub-select">{{ (modelValue || []).join(",") }}<slot /></div>',
  },
  ElOption: { props: ['label', 'value'], template: '<span></span>' },
  ElSteps: { props: ['active'], template: '<div><slot /></div>' },
  ElStep: { props: ['title'], template: '<div>{{ title }}</div>' },
  ElTag: { props: ['type', 'size'], template: '<span class="stub-tag"><slot /></span>' },
  ElAlert: { props: ['title', 'type', 'closable'], template: '<div class="stub-alert">{{ title }}<slot /></div>' },
};

const outcome = {
  created: [
    { id: 7, email: 'ali@e2e.test', name: null, roles: ['member'] },
    { id: 8, email: 'nora@e2e.test', name: null, roles: ['member'] },
  ],
  existing: [{ id: 3, email: 'mei@e2e.test', name: 'Mei', roles: ['creator', 'member'] }],
  invalid: ['not-an-email'],
};

function mountDialog() {
  return mount(AddAccountsDialog, {
    props: { modelValue: true },
    global: { components: stubs, config: { warnHandler: () => {} } },
  });
}

const submitButton = (wrapper) => wrapper.findAll('button').find((b) => /^Add \d+ accounts?$/.test(b.text()));

beforeEach(() => {
  api.post.mockReset();
  api.put.mockReset();
});

describe('AddAccountsDialog step 1 (paste emails)', () => {
  it('shows the Google-only hint', () => {
    const wrapper = mountDialog();
    expect(wrapper.text()).toContain('Google-based emails only');
  });

  it('disables Submit until at least one email parses, then counts them', async () => {
    const wrapper = mountDialog();
    expect(submitButton(wrapper).attributes('disabled')).toBeDefined();

    await wrapper.find('textarea').setValue('a@x.com, b@x.com c@x.com\nd@x.com\nnot-an-email');

    expect(submitButton(wrapper).attributes('disabled')).toBeUndefined();
    expect(submitButton(wrapper).text()).toBe('Add 4 accounts');
    expect(wrapper.text()).toContain('4 emails found, 1 skipped');
  });

  it('posts the parsed list to /account/bulk', async () => {
    api.post.mockResolvedValue({ status: 201, data: outcome });
    const wrapper = mountDialog();
    await wrapper.find('textarea').setValue('ali@e2e.test nora@e2e.test, mei@e2e.test not-an-email');

    await submitButton(wrapper).trigger('click');
    await flushPromises();

    expect(api.post).toHaveBeenCalledWith('/account/bulk', {
      emails: ['ali@e2e.test', 'nora@e2e.test', 'mei@e2e.test', 'not-an-email'],
    });
  });
});

describe('AddAccountsDialog step 2 (results and roles)', () => {
  async function mountAtResults() {
    api.post.mockResolvedValue({ status: 201, data: outcome });
    const wrapper = mountDialog();
    await wrapper.find('textarea').setValue('ali@e2e.test nora@e2e.test mei@e2e.test not-an-email');
    await submitButton(wrapper).trigger('click');
    await flushPromises();
    return wrapper;
  }

  it('lists created, existing, and invalid entries with their status', async () => {
    const wrapper = await mountAtResults();
    const text = wrapper.text();

    expect(text).toContain('ali@e2e.test');
    expect(text).toContain('nora@e2e.test');
    expect(text).toContain('mei@e2e.test');
    expect(text).toContain('not-an-email');
    expect(text).toMatch(/2 accounts added/);
    expect(text).toMatch(/1 already existed/);
    expect(text).toMatch(/1 (was not|not) a valid email/);
  });

  it('offers a role editor for created and existing rows only', async () => {
    const wrapper = await mountAtResults();
    const selects = wrapper.findAllComponents({ name: 'ElSelectStub' });

    expect(selects).toHaveLength(3);
    expect(selects[0].props('modelValue')).toEqual(['member']);
    expect(selects[2].props('modelValue')).toEqual(['creator', 'member']);
  });

  it('saves a role change for that row right away via PUT /account/:id', async () => {
    api.put.mockResolvedValue({ status: 200 });
    const wrapper = await mountAtResults();
    const first = wrapper.findAllComponents({ name: 'ElSelectStub' })[0];

    first.vm.$emit('update:modelValue', ['creator', 'member']);
    first.vm.$emit('change', ['creator', 'member']);
    await flushPromises();

    expect(api.put).toHaveBeenCalledWith('/account/7', { roles: ['creator', 'member'] });
  });

  it('keeps Done and Add more disabled while a role save is in flight, then re-enables them', async () => {
    let settle;
    api.put.mockReturnValue(new Promise((resolve) => { settle = resolve; }));
    const wrapper = await mountAtResults();
    const first = wrapper.findAllComponents({ name: 'ElSelectStub' })[0];
    const button = (label) => wrapper.findAll('button').find((b) => b.text() === label);

    first.vm.$emit('update:modelValue', ['creator', 'member']);
    first.vm.$emit('change', ['creator', 'member']);
    await flushPromises();

    expect(button('Done').attributes('disabled')).toBeDefined();
    expect(button('Add more').attributes('disabled')).toBeDefined();

    settle({ status: 200 });
    await flushPromises();

    expect(button('Done').attributes('disabled')).toBeUndefined();
    expect(button('Add more').attributes('disabled')).toBeUndefined();
  });

  it('Done closes the dialog and tells the parent to refresh', async () => {
    const wrapper = await mountAtResults();

    await wrapper.findAll('button').find((b) => b.text() === 'Done').trigger('click');

    expect(wrapper.emitted('done')).toHaveLength(1);
    expect(wrapper.emitted('update:modelValue')).toEqual([[false]]);
  });
});
