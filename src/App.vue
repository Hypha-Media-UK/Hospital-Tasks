<script setup>
import AppHeader from './components/AppHeader.vue';
import { onMounted } from 'vue';
import { useAreaCoverStore } from './stores/areaCoverStore';

// Initialize stores that contain app-wide data
onMounted(async () => {
  // Pre-load area cover assignments to ensure they're available for new shifts
  const areaCoverStore = useAreaCoverStore();
  await areaCoverStore.initialize();
  console.log('App-level area cover store initialization complete');
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
