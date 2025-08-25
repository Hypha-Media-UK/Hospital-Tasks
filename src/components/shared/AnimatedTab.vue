<template>
  <motion.button 
    class="animated-tab"
    :class="{ 'animated-tab--active': isActive }"
    @click="$emit('click')"
    ref="tabRef"
    :animate="isActive ? activeStyle : inactiveStyle"
    :transition="{ 
      type: 'spring',
      stiffness: 300,
      damping: 30
    }"
  >
    <slot></slot>
  </motion.button>
</template>

<script setup>
import { ref } from 'vue';
import { motion } from 'motion-v';

const props = defineProps({
  isActive: {
    type: Boolean,
    default: false
  },
  activeColor: {
    type: String,
    default: '#4285F4'  // Google blue
  },
  inactiveColor: {
    type: String,
    default: '#666666'  // Medium grey
  },
  activeBackgroundColor: {
    type: String,
    default: 'rgba(66, 133, 244, 0.1)'  // Light blue
  },
  inactiveBackgroundColor: {
    type: String,
    default: 'rgba(0, 0, 0, 0)'  // Transparent
  }
});

// Define styles for active and inactive states
// Font weight is handled via CSS classes instead of animation
const activeStyle = {
  backgroundColor: props.activeBackgroundColor,
  color: props.activeColor
};

const inactiveStyle = {
  backgroundColor: props.inactiveBackgroundColor,
  color: props.inactiveColor
};

const tabRef = ref(null);

// Expose the element reference to the parent component
defineExpose({
  tabRef
});

defineEmits(['click']);
</script>

<!-- Styles are now handled by the global CSS layers -->