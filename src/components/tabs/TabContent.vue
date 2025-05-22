<template>
  <transition name="fade" mode="out-in">
    <div class="tab-content" :key="activeTab">
      <slot :name="activeTab"></slot>
    </div>
  </transition>
</template>

<script setup>
defineProps({
  activeTab: {
    type: String,
    required: true
  }
});
</script>

<style lang="scss" scoped>
.tab-content {
  padding: 16px 0;
  min-height: 200px;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(10px);
}
</style>
