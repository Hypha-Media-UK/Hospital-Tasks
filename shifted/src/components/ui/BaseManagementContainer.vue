<template>
  <div class="management-container">
    <!-- Management Header -->
    <div class="management-header">
      <div class="header-info">
        <h2 class="management-title">{{ title }}</h2>
        <p v-if="subtitle" class="management-subtitle">{{ subtitle }}</p>
      </div>
      <BaseButton
        v-if="showAddButton"
        variant="primary"
        @click="$emit('add-item')"
      >
        <PlusIcon class="w-4 h-4" />
        {{ addButtonText }}
      </BaseButton>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="loading-state">
      <div class="loading-spinner"></div>
      <p>{{ loadingText }}</p>
    </div>

    <!-- Empty State -->
    <div v-else-if="items.length === 0" class="empty-state">
      <div class="empty-icon">
        <component :is="emptyIcon" class="w-16 h-16" />
      </div>
      <h3>{{ emptyTitle }}</h3>
      <p>{{ emptyDescription }}</p>
      <BaseButton
        v-if="showAddButton"
        variant="primary"
        @click="$emit('add-item')"
      >
        <PlusIcon class="w-4 h-4" />
        {{ addButtonText }}
      </BaseButton>
    </div>

    <!-- Items List -->
    <div v-else class="items-container">
      <slot name="items" :items="items" />
    </div>

    <!-- Modals Slot -->
    <slot name="modals" />
  </div>
</template>

<script setup lang="ts">
import type { Component } from 'vue'
import BaseButton from './BaseButton.vue'
import PlusIcon from '../icons/PlusIcon.vue'

interface Props {
  title: string
  subtitle?: string
  items: any[]
  loading?: boolean
  loadingText?: string
  emptyIcon: Component
  emptyTitle: string
  emptyDescription: string
  addButtonText?: string
  showAddButton?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  loadingText: 'Loading...',
  addButtonText: 'Add Item',
  showAddButton: true
})

defineEmits<{
  'add-item': []
}>()
</script>

<style scoped>
.management-container {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
  container-type: inline-size;
}

.management-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: var(--spacing);
}

.header-info {
  flex: 1;
  min-width: 0;
}

.management-title {
  font-size: 1.5rem;
  font-weight: 600;
  margin: 0 0 var(--spacing-xs) 0;
  color: var(--color-text);
}

.management-subtitle {
  margin: 0;
  color: var(--color-text-light);
  font-size: 0.875rem;
  line-height: 1.4;
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
  background: var(--color-background-alt);
  border-radius: var(--radius-lg);
  border: 2px dashed var(--color-border);
  min-height: 300px;
}

.empty-icon {
  margin-bottom: var(--spacing-lg);
  color: var(--color-text-light);
  opacity: 0.6;
}

.empty-state h3 {
  margin: 0 0 var(--spacing-sm) 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--color-text);
}

.empty-state p {
  margin: 0 0 var(--spacing-lg) 0;
  color: var(--color-text-light);
  max-width: 400px;
  line-height: 1.5;
}

.items-container {
  display: flex;
  flex-direction: column;
  gap: var(--spacing);
}

/* Responsive adjustments */
@container (max-width: 768px) {
  .management-header {
    flex-direction: column;
    align-items: stretch;
  }

  .empty-state {
    padding: var(--spacing-xl);
    min-height: 250px;
  }

  .empty-icon {
    margin-bottom: var(--spacing);
  }
}
</style>
