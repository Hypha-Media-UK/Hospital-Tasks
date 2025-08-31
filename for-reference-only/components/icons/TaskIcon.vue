<template>
  <svg 
    xmlns="http://www.w3.org/2000/svg" 
    width="18" 
    height="18" 
    viewBox="0 0 24 24" 
    :fill="filled ? 'currentColor' : 'none'" 
    stroke="currentColor" 
    stroke-width="2" 
    stroke-linecap="round" 
    stroke-linejoin="round" 
    :class="['task-icon', { 'task-icon--filled': filled }]"
  >
    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
    <polyline points="14 2 14 8 20 8"></polyline>
    <line x1="9" y1="15" x2="15" y2="15"></line>
    <line x1="9" y1="11" x2="15" y2="11"></line>
    <line x1="9" y1="19" x2="11" y2="19"></line>
  </svg>
</template>

<script setup>
defineProps({
  filled: {
    type: Boolean,
    default: false
  }
});
</script>

<style scoped>
.task-icon {
  display: inline-block;
  vertical-align: middle;
  width: 18px;
  height: 18px;
  min-width: 18px;
  min-height: 18px;
  color: #555;
}

.task-icon--filled {
  color: #4285F4;
}
</style>
