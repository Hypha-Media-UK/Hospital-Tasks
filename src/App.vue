<script setup>
import AppHeader from './components/AppHeader.vue';
import { onMounted } from 'vue';
import { useAreaCoverStore } from './stores/areaCoverStore';
import { useSettingsStore } from './stores/settingsStore';

// Initialize stores that contain app-wide data
onMounted(async () => {
  // Initialize settings store first (needed for timezone functions)
  const settingsStore = useSettingsStore();
  await settingsStore.initialize();
  
  // Pre-load area cover assignments to ensure they're available for new shifts
  const areaCoverStore = useAreaCoverStore();
  await areaCoverStore.initialize();
});
</script>

<template>
  <div class="app">
    <AppHeader />
    <main class="content">
      <router-view />
    </main>
  </div>
</template>
