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

<style lang="scss" scoped>
@use '../assets/scss/mixins' as mix;

.icon-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  border-radius: mix.radius('full');
  padding: 6px;
  cursor: pointer;
  color: mix.color('text');
  transition: all 0.2s ease;
  
  &:hover, &:focus {
    background-color: rgba(0, 0, 0, 0.05);
    color: mix.color('primary');
  }
  
  &:active {
    transform: scale(0.95);
  }
  
  &--active {
    color: mix.color('primary');
  }
}
</style>
