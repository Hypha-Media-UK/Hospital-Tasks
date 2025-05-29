<template>
  <header class="header">
    <nav class="header__nav">
      <router-link to="/" aria-label="Home">
        <HomeIcon />
      </router-link>
      <router-link to="/archive" aria-label="Archive">
        <ArchiveIcon />
      </router-link>
      <router-link to="/settings" aria-label="Settings">
        <SettingsIcon />
      </router-link>
    </nav>
  </header>
</template>

<script setup>
import HomeIcon from './icons/HomeIcon.vue';
import ArchiveIcon from './icons/ArchiveIcon.vue';
import SettingsIcon from './icons/SettingsIcon.vue';
</script>
