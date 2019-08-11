import { mount, shallowMount } from '@vue/test-utils';
import CustomStageForm from '~/cycle_analytics/components/custom_stage_form.vue';

describe('CustomStageForm', () => {
  function createComponent(props, shallow = true) {
    const func = shallow ? shallowMount : mount;
    return func(CustomStageForm, {
      propsData: {
        ...props,
      },
    });
  }

  let wrapper = null;

  const sel = {
    name: '[name="add-stage-name"]',
    startEvent: '[name="add-stage-start-event"]',
    stopEvent: '[name="add-stage-stop-event"]',
    submit: '.js-add-stage',
  };

  describe('Empty form', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    describe.each([
      [sel.name, true],
      [sel.startEvent, true],
      [sel.stopEvent, false],
      [sel.submit, false],
    ])('by default', ($sel, enabled) => {
      it(`field ${$sel} is ${enabled ? 'enabled' : 'disabled'}`, () => {
        const el = wrapper.find($sel);
        expect(el.exists()).toBe(true);
      });
    });

    describe('Start event', () => {
      describe('start event label', () => {
        it('is hidden by default', () => {});
        it('will display the start event label field if a label event is selected', () => {});
      });
    });
    describe('Stop event', () => {
      it('is enabled when a start event is selected', () => {});
      it('will only display stop events for the selected start event', () => {});
      describe('Stop event label', () => {
        it('is hidden by default', () => {});
        it('will display the stop event label field if a label event is selected', () => {});
      });
    });
    describe.skip('Add stage button', () => {
      it('is enabled when all required fields are filled', () => {});
      it('emits a `submit` event when clicked', () => {
        const btn = wrapper.find(sel.submit);
        expect(wrapper.emitted().submit).toBeUndefined();
        btn.trigger('click');
        expect(wrapper.emitted().submit).toBeTruthy();
        expect(wrapper.emitted().submit.length).toBe(1);
      });
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
