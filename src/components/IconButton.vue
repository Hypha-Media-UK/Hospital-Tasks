<template>
  <button 
    class="icon-button" 
    :class="{ 'icon-button--active': active }"
    @click="$emit('click')"
    :title="title"
    :aria-label="title"
    type="button"
  >
    <slot></slot>
  </button>
</template>

<script setup>
defineProps({
  title: {
    type: String,
    default: ''
  },
  active: {
    type: Boolean,
    default: false
  }
});

defineEmits(['click']);
</script>

<!-- Styles are now handled by the global CSS layers -->
