<template>
  <div class="department-item" :class="{ 'department-item--frequent': department.is_frequent }">
    <div class="department-content">
      <div class="department-name">
        {{ department.name }}
        <StarIcon
          v-if="department.is_frequent"
          class="w-4 h-4 frequent-icon"
          title="Frequent department"
        />
      </div>
    </div>

    <div class="department-actions">
      <BaseButton
        variant="ghost"
        size="sm"
        @click="$emit('toggle-frequent', department)"
        :title="department.is_frequent ? 'Remove from frequent' : 'Mark as frequent'"
      >
        <StarIcon
          class="w-4 h-4"
          :class="{ 'star-filled': department.is_frequent, 'star-outline': !department.is_frequent }"
        />
      </BaseButton>

      <BaseButton variant="ghost" size="sm" @click="$emit('edit', department)">
        <EditIcon class="w-4 h-4" />
      </BaseButton>

      <BaseButton variant="ghost" size="sm" @click="$emit('delete', department)">
        <TrashIcon class="w-4 h-4" />
      </BaseButton>
    </div>
  </div>
</template>

<script setup lang="ts">
import BaseButton from '../ui/BaseButton.vue'
import StarIcon from '../icons/StarIcon.vue'
import EditIcon from '../icons/EditIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'
import type { Department } from '../../types/locations'

interface Props {
  department: Department
}

interface Emits {
  edit: [department: Department]
  delete: [department: Department]
  'toggle-frequent': [department: Department]
}

defineProps<Props>()
defineEmits<Emits>()
</script>

<style scoped>
.department-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-sm) var(--spacing);
  background: var(--color-background-alt);
  border-radius: var(--radius);
  border: 1px solid transparent;
  transition: all 0.2s ease;
}

.department-item:hover {
  border-color: var(--color-border);
  background: var(--color-background);
}

.department-item--frequent {
  background: rgba(255, 193, 7, 0.1);
  border-color: rgba(255, 193, 7, 0.3);
}

.department-item--frequent:hover {
  background: rgba(255, 193, 7, 0.15);
  border-color: rgba(255, 193, 7, 0.4);
}

.department-content {
  flex: 1;
}

.department-name {
  font-weight: 500;
  color: var(--color-text);
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
}

.frequent-icon {
  color: #fbbf24;
  fill: currentColor;
}

.department-actions {
  display: flex;
  gap: var(--spacing-xs);
}

.star-filled {
  color: #fbbf24;
  fill: currentColor;
}

.star-outline {
  color: var(--color-text-light);
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
}

.star-outline:hover {
  color: #fbbf24;
}
</style>
