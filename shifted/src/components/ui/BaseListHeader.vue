<template>
  <div class="list-header">
    <div class="header-info">
      <h4>{{ title }}</h4>
      <p v-if="count > 0">
        {{ count }} {{ itemType }}{{ count !== 1 ? 's' : '' }} configured
      </p>
      <p v-else class="no-items">
        No {{ itemType }}s configured for this shift type
      </p>
    </div>
    <slot name="actions" />
  </div>
</template>

<script setup lang="ts">
interface Props {
  title: string
  count: number
  itemType: string
}

defineProps<Props>()
</script>

<style scoped>
.list-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: var(--spacing);
  flex-wrap: wrap;
}

.header-info h4 {
  font-size: 1.125rem;
  font-weight: 600;
  margin-bottom: var(--spacing-xs);
  color: var(--color-text);
}

.header-info p {
  color: var(--color-text-light);
  font-size: 0.875rem;
  margin: 0;
}

.no-items {
  color: var(--color-text-muted);
}
</style>
