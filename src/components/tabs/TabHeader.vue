<template>
  <button 
    class="tab-header"
    :class="{ 'tab-header--active': isActive }"
    @click="$emit('click')"
  >
    {{ label }}
  </button>
</template>

<script setup>
defineProps({
  label: {
    type: String,
    required: true
  },
  isActive: {
    type: Boolean,
    default: false
  }
});

defineEmits(['click']);
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.tab-header {
  padding: 12px 8px;
  position: relative;
  background: transparent;
  border: none;
  font-weight: 500;
  cursor: pointer;
  color: mix.color('text');
  transition: color 0.2s ease;
  
  &--active {
    color: mix.color('primary');
    
    &::after {
      content: '';
      position: absolute;
      bottom: -1px;
      left: 0;
      right: 0;
      height: 2px;
      background-color: mix.color('primary');
    }
  }
  
  &:hover:not(.tab-header--active) {
    color: color.adjust(mix.color('text'), $lightness: -15%);
  }
}
</style>
