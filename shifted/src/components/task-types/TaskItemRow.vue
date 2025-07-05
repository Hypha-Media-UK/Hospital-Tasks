<template>
  <div class="task-item-row" :class="{ 'is-regular': taskItem.is_regular }">
    <div class="item-content">
      <div v-if="isEditing" class="edit-form">
        <input
          v-model="editName"
          ref="editInput"
          class="edit-input"
          @keyup.enter="saveEdit"
          @keyup.esc="cancelEdit"
          @blur="saveEdit"
        />
      </div>
      <div v-else class="item-info">
        <span class="item-name">{{ taskItem.name }}</span>
        <div class="item-badges">
          <span v-if="taskItem.is_regular" class="regular-badge">Regular</span>
          <span v-if="hasAssignments" class="assignments-badge">Assigned</span>
        </div>
      </div>
    </div>

    <div class="item-actions">
      <BaseButton
        v-if="!isEditing"
        @click="toggleRegular"
        variant="ghost"
        size="sm"
        :class="{ 'is-active': taskItem.is_regular }"
        title="Toggle Regular Item"
      >
        <StarIcon />
      </BaseButton>

      <BaseButton
        v-if="!isEditing"
        @click="openAssignmentModal"
        variant="ghost"
        size="sm"
        :class="{ 'has-assignments': hasAssignments }"
        title="Manage Department Assignments"
      >
        <MapPinIcon />
      </BaseButton>

      <BaseButton
        v-if="!isEditing"
        @click="startEdit"
        variant="ghost"
        size="sm"
        title="Edit Task Item"
      >
        <EditIcon />
      </BaseButton>

      <BaseButton
        v-if="!isEditing"
        @click="confirmDelete"
        variant="ghost"
        size="sm"
        title="Delete Task Item"
      >
        <TrashIcon />
      </BaseButton>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, nextTick } from 'vue'
import { useTaskTypesStore } from '../../stores/taskTypesStore'
import type { TaskItem } from '../../types/taskTypes'
import BaseButton from '../ui/BaseButton.vue'
import StarIcon from '../icons/StarIcon.vue'
import MapPinIcon from '../icons/MapPinIcon.vue'
import EditIcon from '../icons/EditIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'

interface Props {
  taskItem: TaskItem
}

interface Emits {
  (e: 'deleted', itemId: string): void
  (e: 'assignment-click', title: string, taskItemId: string): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const taskTypesStore = useTaskTypesStore()

// State
const isEditing = ref(false)
const editName = ref('')
const editInput = ref<HTMLInputElement>()

// Computed
const hasAssignments = computed(() =>
  taskTypesStore.hasItemAssignments(props.taskItem.id)
)

// Methods
const startEdit = async () => {
  editName.value = props.taskItem.name
  isEditing.value = true
  await nextTick()
  editInput.value?.focus()
}

const saveEdit = async () => {
  if (!editName.value.trim()) {
    cancelEdit()
    return
  }

  if (editName.value !== props.taskItem.name) {
    await taskTypesStore.updateTaskItem(props.taskItem.id, {
      name: editName.value.trim()
    })
  }

  isEditing.value = false
}

const cancelEdit = () => {
  editName.value = ''
  isEditing.value = false
}

const toggleRegular = async () => {
  await taskTypesStore.setTaskItemRegular(props.taskItem.id, !props.taskItem.is_regular)
}

const confirmDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.taskItem.name}"?`)) {
    const success = await taskTypesStore.deleteTaskItem(props.taskItem.id)
    if (success) {
      emit('deleted', props.taskItem.id)
    }
  }
}

const openAssignmentModal = () => {
  emit('assignment-click', `Department Assignments - ${props.taskItem.name}`, props.taskItem.id)
}
</script>

<style scoped>
.task-item-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-md);
  background: white;
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  transition: all 0.2s ease;
}

.task-item-row:hover {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 1px var(--color-primary-alpha);
}

.task-item-row.is-regular {
  background: var(--color-primary-light);
  border-color: var(--color-primary);
}

.item-content {
  flex: 1;
  min-width: 0;
}

.edit-form {
  width: 100%;
}

.edit-input {
  width: 100%;
  padding: var(--spacing-xs) var(--spacing-sm);
  border: 1px solid var(--color-primary);
  border-radius: var(--border-radius-sm);
  font-size: 0.875rem;
  background: white;
}

.edit-input:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary-alpha);
}

.item-info {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.item-name {
  font-weight: 500;
  color: var(--color-text-primary);
}

.item-badges {
  display: flex;
  gap: var(--spacing-xs);
}

.regular-badge,
.assignments-badge {
  font-size: 0.75rem;
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--border-radius-full);
  font-weight: 500;
}

.regular-badge {
  background: var(--color-primary);
  color: white;
}

.assignments-badge {
  background: var(--color-gray-200);
  color: var(--color-text-secondary);
}

.item-actions {
  display: flex;
  gap: var(--spacing-xs);
}

.is-active {
  color: var(--color-primary);
}

.has-assignments {
  color: var(--color-primary);
}

@container (max-width: 768px) {
  .task-item-row {
    flex-direction: column;
    align-items: stretch;
    gap: var(--spacing-sm);
  }

  .item-info {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-xs);
  }

  .item-actions {
    justify-content: center;
  }
}
</style>
