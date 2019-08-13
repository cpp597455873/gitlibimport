<script>
import { s__ } from '~/locale';
import { GlButton, GlFormGroup, GlFormInput, GlFormSelect } from '@gitlab/ui';

import LabelsSelector from './labels_selector.vue';

const EVENT_TYPE_LABEL = 'label';
const isStartEvent = ev => ev && ev.can_be_start_event;
const eventToOption = ({ name: text = '', identifier: value = null }) => ({
  text,
  value,
});

const getAllowedStopEvents = (events = [], targetIdentifier = null) => {
  if (!targetIdentifier || !events.length) return [];
  const st = events.find(({ identifier }) => identifier === targetIdentifier);
  return st.allowed_end_events;
};

const eventsByIdentifier = (events = [], targetIdentifier = []) => {
  if (!targetIdentifier.length || !events.length) return [];
  return events.filter(({ identifier }) => targetIdentifier.indexOf(identifier) > -1);
};

const isLabelEvent = (labelEvents = [], ev = null) =>
  ev && labelEvents.length && labelEvents.indexOf(ev) > 0;

const mockLabels = [
  {
    id: 26,
    title: 'Foo Label',
    description: 'Foobar',
    color: '#BADA55',
    text_color: '#FFFFFF',
  },
  {
    id: 27,
    title: 'Foo::Bar',
    description: 'Foobar',
    color: '#0033CC',
    text_color: '#FFFFFF',
  },
];

export default {
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    LabelsSelector,
  },
  props: {
    events: {
      type: Array,
      // required: true,
      required: false,
      default: () => [
        {
          name: 'Issue created',
          identifier: 'issue_created',
          type: 'simple',
          can_be_start_event: true,
          allowed_end_events: ['issue_stage_end'],
        },
        {
          name: 'Issue first mentioned in a commit',
          identifier: 'issue_first_mentioned_in_commit',
          type: 'simple',
          can_be_start_event: false,
          allowed_end_events: [],
        },
        {
          name: 'Merge request created',
          identifier: 'merge_request_created',
          type: 'simple',
          can_be_start_event: true,
          allowed_end_events: ['merge_request_merged'],
        },

        {
          name: 'Merge request first deployed to production',
          identifier: 'merge_request_first_deployed_to_production',
          type: 'simple',
          can_be_start_event: false,
          allowed_end_events: [],
        },
        {
          name: 'Merge request last build finish time',
          identifier: 'merge_request_last_build_finished',
          type: 'simple',
          can_be_start_event: false,
          allowed_end_events: [],
        },
        {
          name: 'Merge request last build start time',
          identifier: 'merge_request_last_build_started',
          type: 'simple',
          can_be_start_event: true,
          allowed_end_events: ['merge_request_last_build_finished'],
        },
        {
          name: 'Merge request merged',
          identifier: 'merge_request_merged',
          type: 'simple',
          can_be_start_event: true,
          allowed_end_events: ['merge_request_first_deployed_to_production'],
        },
        {
          name: 'Issue first mentioned in a commit',
          identifier: 'code_stage_start',
          type: 'simple',
          can_be_start_event: true,
          allowed_end_events: ['merge_request_created'],
        },
        {
          name: 'Issue first associated with a milestone or issue first added to a board',
          identifier: 'issue_stage_end',
          type: 'simple',
          can_be_start_event: false,
          allowed_end_events: [],
        },
        {
          name: 'Issue first associated with a milestone or issue first added to a board',
          identifier: 'plan_stage_start',
          type: 'simple',
          can_be_start_event: true,
          allowed_end_events: ['issue_first_mentioned_in_commit'],
        },
        {
          identifier: 'issue_label_added',
          name: 'Issue Label Added',
          type: 'label',
          can_be_start_event: true,
          allowed_end_events: ['issue_closed', 'issue_label_removed'],
        },
        {
          identifier: 'issue_label_removed',
          name: 'Issue Label Removed',
          type: 'label',
          can_be_start_event: false,
          allowed_end_events: [],
        },
      ],
    },
    labels: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      fields: {
        // objectType: null,
        name: '',
        startEvent: '',
        startEventLabel: '',
        stopEvent: '',
        stopEventLabel: '',
        labelEvents: [],
      },
      selectedLabel: null,
    };
  },
  computed: {
    stopEventOptions() {
      const stopEvents = getAllowedStopEvents(this.events, this.fields.startEvent);
      return [
        { value: null, text: s__('CustomCycleAnalytics|Select stop event') },
        ...eventsByIdentifier(this.events, stopEvents).map(eventToOption),
      ];
    },
    startEventOptions() {
      return [
        { value: null, text: s__('CustomCycleAnalytics|Select start event') },
        ...this.events.filter(isStartEvent).map(eventToOption),
      ];
    },
    hasStartEvent() {
      return this.fields.startEvent;
    },
    startEventRequiresLabel() {
      return isLabelEvent(this.fields.startEvent);
    },
    stopEventRequiresLabel() {
      return isLabelEvent(this.fields.stopEvent);
    },
    isComplete() {
      // TODO: need to factor in label field
      const requiredFields = [this.fields.startEvent, this.fields.stopEvent, this.fields.name];
      return requiredFields.every(fieldValue => fieldValue && fieldValue.length > 0);
    },
  },
  mounted() {
    this.labelEvents = this.events.filter(ev => ev.type === EVENT_TYPE_LABEL);

    // eslint-disable-next-line no-new
    // new LabelsSelect(this.$refs.labelSel);
  },
  methods: {
    handleSave() {
      this.$emit('submit', this.fields);
    },
    handleSelectLabel(label) {
      console.log('handleSelectLabel', label);
      this.selectedLabel = label;
    },
  },
};
</script>
<template>
  <form class="add-stage-form m-4">
    <div class="mb-1">
      <h4>{{ s__('CustomCycleAnalytics|New stage') }}</h4>
    </div>

    <gl-form-group :label="s__('CustomCycleAnalytics|Start event label')">
      <div class="row">
        <labels-selector
          :labels="labels"
          :selected-label-id="selectedLabel"
          @select-label="handleSelectLabel"
        />
      </div>
    </gl-form-group>
    <gl-form-group :label="s__('CustomCycleAnalytics|Name')">
      <gl-form-input
        v-model="fields.name"
        class="form-control"
        type="text"
        value=""
        name="add-stage-name"
        :placeholder="s__('CustomCycleAnalytics|Enter a name for the stage')"
        required
      />
    </gl-form-group>
    <gl-form-group :label="s__('CustomCycleAnalytics|Start event')">
      <gl-form-select
        v-model="fields.startEvent"
        name="add-stage-start-event"
        :required="true"
        :options="startEventOptions"
      />
    </gl-form-group>
    <gl-form-group
      :label="s__('CustomCycleAnalytics|Stop event')"
      :description="s__('CustomCycleAnalytics|Please select a start event first')"
    >
      <gl-form-select
        v-model="fields.stopEvent"
        name="add-stage-stop-event"
        :options="stopEventOptions"
        :required="true"
        :disabled="!hasStartEvent"
      />
    </gl-form-group>
    <div class="add-stage-form-actions">
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
        @click="handleSave"
      >
        {{ s__('CustomCycleAnalytics|Add stage') }}
      </button>
    </div>
  </form>
</template>
