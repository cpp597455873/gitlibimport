import Vue from 'vue';
import urlComponent from '~/serverless/components/url.vue';
import { shallowMount } from '@vue/test-utils';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

const createComponent = uri =>
  shallowMount(Vue.extend(urlComponent), {
    propsData: {
      uri,
    },
    sync: false,
  });

describe('urlComponent', () => {
  it('should render correctly', () => {
    const uri = 'http://testfunc.apps.example.com';
    const wrapper = createComponent(uri);
    const { vm } = wrapper;

    expect(vm.$el.classList.contains('clipboard-group')).toBe(true);
    expect(wrapper.find(ClipboardButton).attributes('text')).toEqual(uri);

    expect(vm.$el.querySelector('.url-text-field').innerHTML).toEqual(uri);

    vm.$destroy();
  });
});
