<template>
  <BaseListItem :highlighted="department.is_frequent">
    <template #content>
      <div class="item-name">
        {{ department.name }}
        <StarIcon
          v-if="department.is_frequent"
          class="w-4 h-4 frequent-icon"
          title="Frequent department"
        />
      </div>
    </template>

    <template #actions>
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
    </template>
  </BaseListItem>
</template>

<script setup lang="ts">
import BaseButton from '../ui/BaseButton.vue'
import BaseListItem from '../ui/BaseListItem.vue'
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
.item-name {
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
