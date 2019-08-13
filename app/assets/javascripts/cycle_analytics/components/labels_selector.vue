<script>
import { GlDropdown, GlDropdownItem } from '@gitlab/ui';

// Currently relying on fetching the labels manually
// We could wrap this with is own service and mini store, but probably overkill
export default {
  name: 'LabelsSelector',
  components: {
    GlDropdown,
    GlDropdownItem,
  },
  props: {
    labels: {
      type: Array,
      required: true,
    },
    selectedLabelId: {
      type: Number,
      required: false,
      default: 26,
    },
  },
  methods: {
    isSelectedLabel(id) {
      return this.selectedLabelId && id === this.selectedLabelId;
    },
  },
};
</script>
<template>
  <div>
    <gl-dropdown text="Some dropdown">
      <template slot="button-content">
        <span class="str-truncated-100 mr-2">
          <h2>
            {{ 'YEAH-BOI' }}
          </h2>
        </span>
        <icon name="chevron-down" class="ml-auto" />
      </template>
      <gl-dropdown-item
        v-for="label in labels"
        :key="label.id"
        @click.prevent="$emit('select-label', label.id)"
        :active="isSelectedLabel(label.id)"
      >
        {{ label.title }}</gl-dropdown-item
      >
    </gl-dropdown>
  </div>
</template>
