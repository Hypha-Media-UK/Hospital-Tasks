<template>
  <div
    class="base-list-item"
    :class="{
      'base-list-item--highlighted': highlighted,
      'base-list-item--editing': editing
    }"
  >
    <div v-if="editing" class="item-edit-form">
      <slot name="edit-form" />
    </div>

    <template v-else>
      <div class="item-content">
        <slot name="content" />
      </div>

      <div class="item-actions">
        <slot name="actions" />
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
interface Props {
  highlighted?: boolean
  editing?: boolean
}

defineProps<Props>()
</script>

<style scoped>
.base-list-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-sm) var(--spacing);
  background: var(--color-background-alt);
  border-radius: var(--radius);
  border: 1px solid transparent;
  transition: all 0.2s ease;
}

.base-list-item:hover {
  border-color: var(--color-border);
  background: var(--color-background);
}

.base-list-item--highlighted {
  background: rgba(255, 193, 7, 0.1);
  border-color: rgba(255, 193, 7, 0.3);
}

.base-list-item--highlighted:hover {
  background: rgba(255, 193, 7, 0.15);
  border-color: rgba(255, 193, 7, 0.4);
}

.base-list-item--editing {
  background: var(--color-background);
  border-color: var(--color-primary);
}

.item-content {
  flex: 1;
  min-width: 0;
}

.item-actions {
  display: flex;
  gap: var(--spacing-xs);
  flex-shrink: 0;
}

.item-edit-form {
  width: 100%;
}

/* Responsive design */
@media (max-width: 768px) {
  .base-list-item {
    flex-direction: column;
    align-items: stretch;
    gap: var(--spacing-sm);
  }

  .item-actions {
    justify-content: center;
  }
}
</style>
