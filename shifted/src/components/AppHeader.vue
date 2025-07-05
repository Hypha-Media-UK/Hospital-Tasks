<template>
  <header class="app-header">
    <div class="header-content">
      <div class="header-brand">
        <h1 class="brand-title">Shifted</h1>
        <span class="brand-subtitle">Hospital Task Management</span>
      </div>

      <nav class="header-nav">
        <RouterLink
          v-for="link in navLinks"
          :key="link.path"
          :to="link.path"
          class="nav-link"
          :class="{ active: $route.path === link.path }"
        >
          <component :is="link.icon" class="nav-icon" />
          <span class="nav-label">{{ link.label }}</span>
        </RouterLink>
      </nav>
    </div>
  </header>
</template>

<script setup>
import { RouterLink, useRoute } from 'vue-router'
import HomeIcon from './icons/HomeIcon.vue'
import TaskIcon from './icons/TaskIcon.vue'
import ArchiveIcon from './icons/ArchiveIcon.vue'
import SettingsIcon from './icons/SettingsIcon.vue'

const route = useRoute()

const navLinks = [
  { path: '/', label: 'Home', icon: HomeIcon },
  { path: '/shift-management', label: 'Shifts', icon: TaskIcon },
  { path: '/archive', label: 'Archive', icon: ArchiveIcon },
  { path: '/defaults', label: 'Defaults', icon: SettingsIcon }
]
</script>

<style scoped>
.app-header {
  background: var(--color-background);
  border-bottom: 1px solid var(--color-border);
  box-shadow: var(--shadow-sm);
}

.header-content {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: var(--spacing-xl);
  padding: var(--spacing) var(--spacing-lg);
  max-width: 1400px;
  margin: 0 auto;
}

.header-brand {
  display: flex;
  flex-direction: column;
}

.brand-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--color-primary);
  margin: 0;
  line-height: 1.2;
}

.brand-subtitle {
  font-size: 0.75rem;
  color: var(--color-text-light);
  font-weight: 500;
}

.header-nav {
  display: flex;
  gap: var(--spacing-sm);
  justify-self: end;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  padding: var(--spacing-sm) var(--spacing);
  border-radius: var(--radius);
  text-decoration: none;
  color: var(--color-text-light);
  font-weight: 500;
  font-size: 0.875rem;
  transition: all 0.15s ease-in-out;
}

.nav-link:hover {
  background: var(--color-background-alt);
  color: var(--color-text);
}

.nav-link.active {
  background: var(--color-primary);
  color: white;
}

.nav-icon {
  width: 18px;
  height: 18px;
}

@container (max-width: 768px) {
  .header-content {
    grid-template-columns: 1fr;
    gap: var(--spacing);
  }

  .header-nav {
    justify-self: stretch;
    justify-content: space-around;
  }

  .nav-label {
    display: none;
  }

  .nav-link {
    flex-direction: column;
    gap: var(--spacing-xs);
    padding: var(--spacing-xs);
  }
}
</style>
