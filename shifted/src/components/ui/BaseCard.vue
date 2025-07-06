<template>
  <div class="base-card">
    <div v-if="$slots.header || $slots.actions" class="card-header">
      <div class="header-content">
        <slot name="header" />
      </div>
      <div v-if="$slots.actions" class="header-actions">
        <slot name="actions" />
      </div>
    </div>

    <div v-if="$slots.content || $slots.default" class="card-body">
      <slot name="content">
        <slot />
      </slot>
    </div>

    <div v-if="$slots.footer" class="card-footer">
      <slot name="footer" />
    </div>
  </div>
</template>

<script setup lang="ts">
// No props needed - this is a pure layout component using slots
</script>

<style scoped>
.base-card {
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: 0; /* No rounded corners as requested */
  overflow: hidden;
}

.card-header {
  padding: var(--spacing-lg);
  border-bottom: 1px solid var(--color-border);
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: var(--spacing);
}

.header-content {
  flex: 1;
  min-width: 0; /* Prevent flex item from overflowing */
}

.header-actions {
  display: flex;
  gap: var(--spacing-xs);
  flex-shrink: 0;
}

.card-body {
  padding: var(--spacing-lg);
}

.card-footer {
  padding: var(--spacing-lg);
  border-top: 1px solid var(--color-border);
  background: var(--color-background-alt);
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .card-header {
    flex-direction: column;
    align-items: stretch;
    gap: var(--spacing);
  }

  .header-actions {
    justify-content: flex-end;
  }
}
</style>
