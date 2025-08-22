<template>
  <!-- Clean semantic app structure -->
  <div class="app-layout">
    <header class="app-header">
      <nav>
        <h1>
          <router-link to="/">Hospital Tasks V2</router-link>
        </h1>
        
        <ul>
          <li><router-link to="/staff">Staff</router-link></li>
          <li><router-link to="/buildings">Buildings</router-link></li>
          <li><router-link to="/departments">Departments</router-link></li>
          <li><router-link to="/task-types">Task Types</router-link></li>
          <li><router-link to="/shifts">Shifts</router-link></li>
        </ul>
      </nav>
    </header>
    
    <main class="app-main">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
// No logic needed for now
</script>

<style scoped>
/* Navigation styling with sibling selectors */
nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-md) var(--space-lg);
  max-width: 1400px;
  margin: 0 auto;
}

nav h1 {
  margin: 0;
  font-size: var(--font-size-xl);
}

nav h1 a {
  color: var(--color-primary);
  text-decoration: none;
  font-weight: var(--font-weight-bold);
}

nav h1 a:hover {
  color: var(--color-primary-dark);
}

nav ul {
  display: flex;
  list-style: none;
  margin: 0;
  padding: 0;
  gap: var(--space-lg);
}

nav ul a {
  color: var(--color-gray-700);
  text-decoration: none;
  font-weight: var(--font-weight-medium);
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-md);
  transition: all var(--transition-fast);
}

nav ul a:hover {
  color: var(--color-primary);
  background-color: var(--color-primary-light);
}

nav ul a.router-link-active {
  color: var(--color-primary);
  background-color: var(--color-primary-light);
}

/* Mobile navigation */
@media (max-width: 768px) {
  nav {
    flex-direction: column;
    gap: var(--space-md);
    padding: var(--space-md);
  }
  
  nav ul {
    gap: var(--space-md);
    flex-wrap: wrap;
    justify-content: center;
  }
}
</style>
