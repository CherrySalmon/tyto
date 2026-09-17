import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import ManagePeopleCard from './ManagePeopleCard.vue';

const stubs = {
  ElInput: {
    props: ['modelValue', 'placeholder'],
    emits: ['update:modelValue'],
    template: '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  },
  ElButton: { emits: ['click'], template: '<button @click="$emit(\'click\')"><slot /></button>' },
  ElSteps: { props: ['active'], template: '<div><slot /></div>' },
  ElStep: { props: ['title'], template: '<div></div>' },
  ElTable: { props: ['data'], template: '<div></div>' },
  ElDialog: { props: ['modelValue', 'title'], template: '<div></div>' },
};

function mountCard() {
  return mount(ManagePeopleCard, {
    props: { enrollments: [], attendanceEvents: {}, locations: [], currentRole: 'owner', assignableRoles: ['student'] },
    global: { components: stubs, config: { warnHandler: () => {} } },
  });
}

// A pasted list may contain tokens that are not emails. They must be shown
// on the review step rather than silently dropped, or the instructor may
// assume everyone was enrolled.
describe('ManagePeopleCard email review', () => {
  it('lists the parsed emails and calls out tokens that were skipped', async () => {
    const wrapper = mountCard();
    await wrapper.find('input').setValue('a@x.edu, not-an-email b@x.edu');
    await wrapper.findAll('button').find((b) => b.text() === 'Next step').trigger('click');

    const text = wrapper.text();
    expect(text).toContain('a@x.edu');
    expect(text).toContain('b@x.edu');
    expect(text).toMatch(/skipped/i);
    expect(text).toContain('not-an-email');
  });

  it('shows no skipped notice when every token is an email', async () => {
    const wrapper = mountCard();
    await wrapper.find('input').setValue('a@x.edu b@x.edu');
    await wrapper.findAll('button').find((b) => b.text() === 'Next step').trigger('click');

    expect(wrapper.text()).not.toMatch(/skipped/i);
  });
});
