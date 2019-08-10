import { shallowMount } from '@vue/test-utils';
import CustomStageForm from '~/cycle_analytics/components/custom_stage_form.vue';

describe('CustomStageForm', () => {
  function createComponent(props) {
    return shallowMount(CustomStageForm, {
      propsData: {
        ...props,
      },
    });
  }

  const wrapper = null;

  describe('Empty form', () => {
    describe('Start event', () => {
      it('is disabled until a start event is selected', () => {});
      it('will display the start event label field if a label event is selected', () => {});
    });
    describe('Stop event', () => {
      it('is disabled until a start event is selected', () => {});
      it('will only display stop events for the selected start event', () => {});
      it('will display the stop event label field if a label event is selected', () => {});
    });
    describe('Add stage button', () => {
      it('is disabled by default', () => {});
      it('is enabled when all required fields are filled', () => {});
      it('emits a `submit` event when clicked', () => {});
    });
  });
  describe('Prepopulated form', () => {
    describe('Add stage button', () => {
      it('is disabled by default', () => {});
      it('is enabled when a field is changed and fields are valid', () => {});
      it('emits a `submit` event when clicked', () => {});
    });
  });
});
