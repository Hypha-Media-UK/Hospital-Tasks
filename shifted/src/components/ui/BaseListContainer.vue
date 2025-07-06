<template>
  <div class="list-container">
    <BaseListHeader
      :title="title"
      :count="items.length"
      :item-type="itemType"
    >
      <template #actions>
        <slot name="header-actions" />
      </template>
    </BaseListHeader>

    <div v-if="loading" class="loading-state">
      <div class="loading-spinner"></div>
      <p>{{ loadingText }}</p>
    </div>

    <div v-else-if="items.length === 0" class="empty-state">
      <slot name="empty-state" />
    </div>

    <div v-else class="items-grid">
      <slot name="items" :items="items" />
    </div>

    <slot name="modals" />
  </div>
</template>

<script setup lang="ts">
import BaseListHeader from './BaseListHeader.vue'

interface Props {
  title: string
  itemType: string
  items: any[]
  loading?: boolean
  loadingText?: string
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  loadingText: 'Loading...'
})
</script>

<style scoped>
.list-container {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  gap: var(--spacing);
  color: var(--color-text-light);
}

.loading-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-border);
  border-top: 3px solid var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  text-align: center;
  color: var(--color-text-light);
}

.items-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: var(--spacing-lg);
}

/* Support responsive grid for services */
@container (min-width: 640px) {
  .items-grid {
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  }
}

@container (min-width: 1024px) {
  .items-grid {
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  }
}
</style>
