import { shallowMount } from '@vue/test-utils';
import AddStageButton from '~/cycle_analytics/components/add_stage_button.vue';

describe('AddStageButton', () => {
  const isActive = false;

  function createComponent(props) {
    return shallowMount(AddStageButton, {
      propsData: {
        isActive,
        ...props,
      },
    });
  }

  let wrapper = null;

  describe('is not active', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    afterEach(() => {
      wrapper.destroy();
    });
    it('emits the `showform` event when clicked', () => {
      expect(wrapper.emitted().showform).toBeUndefined();
      wrapper.trigger('click');
      expect(wrapper.emitted().showform.length).toBe(1);
    });
  });
});
