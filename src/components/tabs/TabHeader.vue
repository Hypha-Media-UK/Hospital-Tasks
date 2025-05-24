<template>
  <button 
    class="tab-header"
    :class="{ 'tab-header--active': isActive }"
    @click="$emit('click')"
  >
    {{ label }}
    <span v-if="badgeCount > 0" class="tab-header__badge">
      {{ badgeCount }}
    </span>
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
  },
  badgeCount: {
    type: Number,
    default: 0
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
  
  &__badge {
    position: absolute;
    top: 4px;
    right: 4px;
    min-width: 18px;
    height: 18px;
    border-radius: 9px;
    background-color: #EA4335;
    color: white;
    font-size: 0.7rem;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 4px;
    font-weight: bold;
  }
}
</style>
