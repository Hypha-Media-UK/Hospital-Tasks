<template>
  <div class="app-layout">
    <AppHeader />
    <main class="main-content">
      <div class="card">
        <div class="card-header">
          <h1 class="text-xl font-semibold">Activity Sheet</h1>
        </div>
        <div class="card-body">
          <p>Activity sheet functionality will be implemented here.</p>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import AppHeader from '../components/AppHeader.vue'
</script>

<style scoped>
.app-layout {
  container-type: inline-size;
}
</style>
