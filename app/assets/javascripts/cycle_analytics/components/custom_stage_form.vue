<script>
import { __ } from '~/locale';
import { GlButton, GlFormGroup, GlFormInput, GlFormSelect } from '@gitlab/ui';

export default {
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
  },
  props: {
    name: {
      type: String,
      default: null,
    },
    objectType: {
      type: String,
      default: null,
    },
    startEvent: {
      type: String,
      default: null,
    },
    stopEvent: {
      type: String,
      default: null,
    },
    isComplete: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    startEventOptions() {
      return [{ value: null, text: __('Select start event') }];
    },
    stopEventOptions() {
      return [{ value: null, text: __('Select stop event') }];
    },
    objectTypeOptions() {
      return [{ value: null, text: __('Select one or more objects') }];
    },
  },
};
</script>
<template>
  <form class="add-stage-form m-4">
    <div class="mb-1">
      <h4>{{ s__('CustomCycleAnalytics|New stage') }}</h4>
    </div>
    <gl-form-group>
      <gl-form-input
        v-model="name"
        class="form-control"
        type="text"
        value=""
        name="add-stage-name"
        :label="__('Name')"
        :placeholder="__('Enter a name for the stage')"
        required
      />
    </gl-form-group>
    <!-- 
        TODO: Double check if we need this 
        - Does this filter the list of start / stop events.... 🤔
      -->
    <gl-form-group>
      <gl-form-select
        v-model="objectType"
        :label="__('CustomCycleAnalytics|Object type')"
        name="add-stage-object-type"
        :required="true"
        :options="objectTypeOptions"
      />

      <p class="form-text text-muted">
        {{ __('Choose which object types will trigger this stage') }}
      </p>
    </gl-form-group>
    <gl-form-group>
      <gl-form-select
        v-model="startEvent"
        :label="__('Start event')"
        name="add-stage-start-event"
        :required="true"
        :options="startEventOptions"
      />
    </gl-form-group>
    <gl-form-group>
      <gl-form-select
        v-model="stopEvent"
        :label="__('Stop event')"
        name="add-stage-stop-event"
        :options="stopEventOptions"
        :required="true"
      />
      <p class="form-text text-muted">{{ __('Please select a start event first') }}</p>
    </gl-form-group>
    <div class="add-stage-form-actions clearfix">
      <!-- 
          TODO: what does the cancel button do?
          - Just hide the form?
          - clear entered data?
        -->
      <button class="btn btn-cancel add-stage-cancel" type="button" @click="cancelHandler()">
        {{ __('Cancel') }}
      </button>
      <button
        :disabled="!isComplete"
        type="button"
        class="js-add-stage btn btn-success"
        @click="handleSave()"
      >
        {{ __('Add stage') }}
      </button>
    </div>
  </form>
</template>
