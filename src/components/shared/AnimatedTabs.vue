<template>
  <div class="animated-tabs" :class="`animated-tabs--${orientation}`">
    <div class="animated-tabs__header" ref="tabsHeaderRef">
      <!-- Tab buttons -->
      <AnimatedTab 
        v-for="tab in tabs" 
        :key="tab.id"
        :is-active="modelValue === tab.id"
        :active-color="activeColor"
        :inactive-color="inactiveColor"
        :active-background-color="activeBackgroundColor"
        :inactive-background-color="inactiveBackgroundColor"
        @click="updateActiveTab(tab.id)"
        ref="tabRefs"
      >
        {{ tab.label }}
        <span v-if="tab.count !== undefined" class="tab-badge">
          {{ tab.count }}
        </span>
      </AnimatedTab>
      
      <!-- Sliding active indicator -->
      <motion.div 
        class="animated-tabs__indicator"
        :animate="{ 
          [orientation === 'horizontal' ? 'x' : 'y']: indicatorPosition, 
          [orientation === 'horizontal' ? 'width' : 'height']: indicatorSize,
          opacity: 1
        }"
        :initial="{ opacity: 0 }"
        :transition="{ 
          type: 'spring', 
          stiffness: 500, 
          damping: 30 
        }"
        :style="{ backgroundColor: indicatorColor }"
      ></motion.div>
    </div>
    
    <!-- Tab content -->
    <div class="animated-tabs__content">
      <motion.div 
        class="animated-tabs__content-wrapper"
        :initial="{ opacity: 0, x: transitionDirection * 50 }"
        :animate="{ opacity: 1, x: 0 }"
        :exit="{ opacity: 0, x: -transitionDirection * 50 }"
        :transition="{ 
          type: 'spring', 
          stiffness: 300, 
          damping: 30,
          mass: 1.2
        }"
        :key="modelValue"
      >
        <slot :name="modelValue"></slot>
      </motion.div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onBeforeUnmount } from 'vue';
import { motion } from 'motion-v';
import AnimatedTab from './AnimatedTab.vue';

const props = defineProps({
  // v-model for the active tab id
  modelValue: {
    type: String,
    required: true
  },
  // Array of tab objects with {id, label, count} structure
  tabs: {
    type: Array,
    required: true
  },
  // Visual styling props
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
  },
  indicatorColor: {
    type: String,
    default: '#4285F4'  // Google blue
  },
  orientation: {
    type: String,
    default: 'horizontal',
    validator: (value) => ['horizontal', 'vertical'].includes(value)
  }
});

const emit = defineEmits(['update:modelValue', 'tab-change']);

// Refs for DOM elements
const tabsHeaderRef = ref(null);
const tabRefs = ref([]);

// Animation state
const indicatorPosition = ref(0);
const indicatorSize = ref(0);
const transitionDirection = ref(1); // 1 for right-to-left, -1 for left-to-right

// Update the active tab and emit events
function updateActiveTab(tabId) {
  // Calculate transition direction
  const oldIndex = props.tabs.findIndex(tab => tab.id === props.modelValue);
  const newIndex = props.tabs.findIndex(tab => tab.id === tabId);
  
  if (oldIndex !== -1 && newIndex !== -1) {
    transitionDirection.value = newIndex > oldIndex ? 1 : -1;
  } else {
    transitionDirection.value = 0;
  }
  
  // Emit events to update v-model and notify of tab change
  emit('update:modelValue', tabId);
  emit('tab-change', tabId);
}

// Calculate the indicator position based on the active tab
function updateIndicatorPosition() {
  nextTick(() => {
    if (!tabRefs.value || tabRefs.value.length === 0 || !tabsHeaderRef.value) return;
    
    const activeIndex = props.tabs.findIndex(tab => tab.id === props.modelValue);
    if (activeIndex === -1 || !tabRefs.value[activeIndex]) return;
    
    // The ref might be an object with a tabRef property, or it might be a direct DOM ref
    // Handle both cases safely
    const activeTabRef = tabRefs.value[activeIndex];
    if (!activeTabRef) return;
    
    // Get the actual DOM element, whether from tabRef property or direct ref
    const activeTabElement = activeTabRef.tabRef || activeTabRef.$el || activeTabRef;
    if (!activeTabElement || typeof activeTabElement.getBoundingClientRect !== 'function') return;
    
    // Make sure tabsHeaderRef exists and is a DOM element
    if (!tabsHeaderRef.value || typeof tabsHeaderRef.value.getBoundingClientRect !== 'function') return;
    
    const tabHeaderRect = tabsHeaderRef.value.getBoundingClientRect();
    const activeTabRect = activeTabElement.getBoundingClientRect();
    
    // Calculate position and size based on orientation
    if (props.orientation === 'horizontal') {
      indicatorPosition.value = activeTabRect.left - tabHeaderRect.left;
      indicatorSize.value = activeTabRect.width;
    } else {
      indicatorPosition.value = activeTabRect.top - tabHeaderRect.top;
      indicatorSize.value = activeTabRect.height;
    }
  });
}

// Update indicator position when active tab changes
watch(() => props.modelValue, () => {
  updateIndicatorPosition();
});

// Update indicator position when tabs array changes
watch(() => props.tabs, () => {
  updateIndicatorPosition();
}, { deep: true });

// Initialize indicator on mount
onMounted(() => {
  updateIndicatorPosition();
  
  // Update on window resize
  window.addEventListener('resize', updateIndicatorPosition);
});

// Clean up event listener
onBeforeUnmount(() => {
  window.removeEventListener('resize', updateIndicatorPosition);
});
</script>

<!-- Styles are now handled by the global CSS layers -->