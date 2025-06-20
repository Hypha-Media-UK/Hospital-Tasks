<template>
  <motion.button 
    class="tab-header"
    :class="{ 'tab-header--active': isActive }"
    @click="$emit('click')"
    ref="tabRef"
    :animate="isActive ? activeStyle : inactiveStyle"
    :transition="{ 
      type: 'spring',
      stiffness: 300,
      damping: 30
    }"
  >
    {{ label }}
    <span v-if="badgeCount > 0" class="tab-header__badge">
      {{ badgeCount }}
    </span>
  </motion.button>
</template>

<script setup>
import { ref } from 'vue';
import { motion } from 'motion-v';

const props = defineProps({
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

// Define styles for active and inactive states
// Using explicit rgba values for better animation
// Note: fontWeight is handled by CSS classes instead of animation
const activeStyle = {
  backgroundColor: 'rgba(66, 133, 244, 0.1)',
  color: 'rgba(66, 133, 244, 1)'
};

const inactiveStyle = {
  backgroundColor: 'rgba(0, 0, 0, 0)',
  color: 'rgba(51, 51, 51, 1)'  // Equivalent to #333
};

const tabRef = ref(null);

// Expose the element reference to the parent component
defineExpose({
  tabRef
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
  transition: color 0.3s ease, font-weight 0.01s; // Quick transition for font-weight
  
  &--active {
    font-weight: 600; // Set font-weight via CSS for active state
    // Other styles are handled by motion animation
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
