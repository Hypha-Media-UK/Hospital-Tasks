<template>
  <header class="header">
    <nav class="header__nav">
      <router-link to="/" aria-label="Home">
        <IconComponent name="home" />
      </router-link>
      <router-link to="/archive" aria-label="Archive">
        <IconComponent name="archive" />
      </router-link>
      <router-link to="/default-support" aria-label="Default Support">
        <IconComponent name="defaults" />
      </router-link>
      <router-link to="/settings" aria-label="Settings">
        <IconComponent name="settings" />
      </router-link>
    </nav>
  </header>
</template>

<script setup>
import IconComponent from './IconComponent.vue';
</script>
