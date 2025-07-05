<template>
  <div class="locations-tab-content">
    <LocationsManagement />
  </div>
</template>

<script setup lang="ts">
import LocationsManagement from '../../locations/LocationsManagement.vue'
</script>

<style scoped>
.locations-tab-content {
  padding: var(--spacing-lg);
}
</style>
