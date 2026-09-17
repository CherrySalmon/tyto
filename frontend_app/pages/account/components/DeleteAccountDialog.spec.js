import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import DeleteAccountDialog from './DeleteAccountDialog.vue';

const stubs = {
  ElDialog: { props: ['modelValue', 'title'], template: '<div><slot /><slot name="footer" /></div>' },
  ElButton: {
    props: ['disabled', 'loading', 'type'],
    emits: ['click'],
    template: '<button :disabled="disabled || loading" @click="$emit(\'click\')"><slot /></button>',
  },
  ElInput: {
    props: ['modelValue', 'placeholder'],
    emits: ['update:modelValue'],
    template: '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  },
  ElAlert: { props: ['title', 'type', 'closable'], template: '<div class="stub-alert">{{ title }}<slot /></div>' },
};

const account = { id: 9, name: 'Lin Chen', email: 'lin.chen@example.edu', roles: ['creator', 'member'] };

function mountDialog(props = {}) {
  return mount(DeleteAccountDialog, {
    props: { modelValue: true, account, enrollmentCount: 5, ...props },
    global: { components: stubs, config: { warnHandler: () => {} } },
  });
}

const deleteButton = (wrapper) => wrapper.findAll('button').find((b) => b.text() === 'Delete account');

// Plan Q7: the confirm names what goes with the account and needs the email
// typed before Delete enables (GitHub-style destructive confirm).
describe('DeleteAccountDialog', () => {
  it('names the enrollment count and the account', () => {
    const text = mountDialog().text();
    expect(text).toContain('Lin Chen');
    expect(text).toMatch(/5 course enrollments/);
    expect(text).toContain('lin.chen@example.edu');
  });

  it('keeps Delete disabled until the typed email matches exactly', async () => {
    const wrapper = mountDialog();
    expect(deleteButton(wrapper).attributes('disabled')).toBeDefined();

    await wrapper.find('input').setValue('lin.chen@exam');
    expect(deleteButton(wrapper).attributes('disabled')).toBeDefined();

    await wrapper.find('input').setValue('lin.chen@example.edu');
    expect(deleteButton(wrapper).attributes('disabled')).toBeUndefined();
  });

  it('emits confirm with the account once Delete is clicked', async () => {
    const wrapper = mountDialog();
    await wrapper.find('input').setValue('lin.chen@example.edu');

    await deleteButton(wrapper).trigger('click');

    expect(wrapper.emitted('confirm')).toEqual([[account]]);
  });

  it('shows a neutral count while the enrollment count is still loading', () => {
    const text = mountDialog({ enrollmentCount: null }).text();
    expect(text).toMatch(/course enrollments/);
    expect(text).not.toMatch(/null/);
  });
});
