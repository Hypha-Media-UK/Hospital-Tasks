<template>
  <div class="tab-content-wrapper">
    <motion.div
      :initial="{ opacity: 0, x: direction * 50, y: 0 }"
      :animate="{ opacity: 1, x: 0, y: 0 }"
      :exit="{ opacity: 0, x: -direction * 50, y: 0 }"
      :transition="{ 
        type: 'spring', 
        stiffness: 300, 
        damping: 30,
        mass: 1.2
      }"
      class="tab-content"
      :key="activeTab"
      layout
    >
      <motion.div
        :initial="{ opacity: 0 }"
        :animate="{ opacity: 1 }"
        :transition="{ 
          delay: 0.1, 
          duration: 0.3 
        }"
      >
        <slot :name="activeTab"></slot>
      </motion.div>
    </motion.div>
  </div>
</template>

<script setup>
import { motion } from 'motion-v';

defineProps({
  activeTab: {
    type: String,
    required: true
  },
  direction: {
    type: Number,
    default: 0 // 0: no direction, -1: left, 1: right
  }
});
</script>

<style lang="scss" scoped>
.tab-content-wrapper {
  position: relative;
  overflow: hidden;
}

.tab-content {
  padding: 16px 0;
  min-height: 200px;
}
</style>
