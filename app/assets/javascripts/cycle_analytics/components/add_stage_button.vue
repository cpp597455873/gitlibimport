<script>
export default {
  props: {
    isActive: {
      type: Boolean,
      required: true,
    },
  },
};
</script>
<template>
  <li
    :class="{ active: isActive }"
    class="stage-nav-item stage-ghost rounded"
    @click="$emit('showform')"
  >
    {{ s__('CustomCycleAnalytics|Add a stage') }}
  </li>
</template>
