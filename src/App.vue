<script setup>
import AppHeader from './components/AppHeader.vue';
</script>

<template>
  <div class="app">
    <AppHeader />
    <main class="content">
      <router-view />
    </main>
  </div>
</template>
