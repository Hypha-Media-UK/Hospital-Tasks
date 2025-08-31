<template>
  <header class="header">
    <nav class="header__nav">
      <div class="header__nav-left">
        <router-link to="/" aria-label="Home">
          <HomeIcon />
        </router-link>
      </div>
      
      <div class="header__nav-right">
        <router-link to="/archive" aria-label="Archive">
          <ArchiveIcon />
        </router-link>
        <router-link to="/settings" aria-label="Settings">
          <SettingsIcon />
        </router-link>
      </div>
    </nav>
  </header>
</template>

<script setup>
import HomeIcon from './icons/HomeIcon.vue';
import ArchiveIcon from './icons/ArchiveIcon.vue';
import SettingsIcon from './icons/SettingsIcon.vue';
</script>

<style lang="scss" scoped>
.header__nav {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 1rem;
}

.header__nav-left,
.header__nav-right {
  display: flex;
  align-items: center;
  gap: 1rem;
}
</style>
