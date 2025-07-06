<template>
  <BaseCard>
    <template #header>
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
      <div v-else class="title-section">
        <h3 class="task-type-name">{{ taskType.name }}</h3>
        <div class="item-count">{{ taskType.items.length }} items</div>
      </div>
    </template>

    <template #actions>
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
        title="Edit Task Type"
      >
        <EditIcon />
      </BaseButton>

      <BaseButton
        v-if="!isEditing"
        @click="confirmDelete"
        variant="ghost"
        size="sm"
        title="Delete Task Type"
      >
        <TrashIcon />
      </BaseButton>
    </template>

    <template #content>
      <!-- Add Task Item Form -->
      <div v-if="showAddForm" class="add-item-form">
        <div class="form-row">
          <input
            v-model="newItemName"
            ref="newItemInput"
            placeholder="Task item name"
            class="item-input"
            @keyup.enter="addTaskItem"
            @keyup.esc="cancelAdd"
          />
          <div class="form-actions">
            <BaseButton @click="addTaskItem" variant="primary" size="sm">
              Add
            </BaseButton>
            <BaseButton @click="cancelAdd" variant="secondary" size="sm">
              Cancel
            </BaseButton>
          </div>
        </div>
      </div>

      <!-- Task Items List -->
      <div v-if="taskType.items.length > 0" class="items-list">
        <TaskItemRow
          v-for="item in taskType.items"
          :key="item.id"
          :task-item="item"
          @deleted="handleItemDeleted"
          @assignment-click="handleItemAssignmentClick"
        />
      </div>

      <!-- Empty State -->
      <div v-else-if="!showAddForm" class="empty-items">
        <p>No task items yet. Add your first task item to get started.</p>
      </div>

      <!-- Add Item Button -->
      <div v-if="!showAddForm" class="add-item-section">
        <BaseButton @click="showAddItemForm" variant="secondary" size="sm">
          <PlusIcon />
          Add Task Item
        </BaseButton>
      </div>
    </template>
  </BaseCard>
</template>

<script setup lang="ts">
import { ref, computed, nextTick } from 'vue'
import { useTaskTypesStore } from '../../stores/taskTypesStore'
import type { TaskTypeWithItems } from '../../types/taskTypes'
import BaseButton from '../ui/BaseButton.vue'
import BaseCard from '../ui/BaseCard.vue'
import TaskItemRow from './TaskItemRow.vue'
import MapPinIcon from '../icons/MapPinIcon.vue'
import EditIcon from '../icons/EditIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'
import PlusIcon from '../icons/PlusIcon.vue'

interface Props {
  taskType: TaskTypeWithItems
}

interface Emits {
  (e: 'deleted', taskTypeId: string): void
  (e: 'assignment-click', title: string, taskTypeId?: string, taskItemId?: string): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const taskTypesStore = useTaskTypesStore()

// State
const isEditing = ref(false)
const editName = ref('')
const editInput = ref<HTMLInputElement>()

const showAddForm = ref(false)
const newItemName = ref('')
const newItemInput = ref<HTMLInputElement>()

// Computed
const hasAssignments = computed(() =>
  taskTypesStore.hasTypeAssignments(props.taskType.id)
)

// Methods
const startEdit = async () => {
  editName.value = props.taskType.name
  isEditing.value = true
  await nextTick()
  editInput.value?.focus()
}

const saveEdit = async () => {
  if (!editName.value.trim()) {
    cancelEdit()
    return
  }

  if (editName.value !== props.taskType.name) {
    await taskTypesStore.updateTaskType(props.taskType.id, {
      name: editName.value.trim()
    })
  }

  isEditing.value = false
}

const cancelEdit = () => {
  editName.value = ''
  isEditing.value = false
}

const confirmDelete = async () => {
  const itemCount = props.taskType.items.length
  const message = itemCount > 0
    ? `Are you sure you want to delete "${props.taskType.name}" and all ${itemCount} task items?`
    : `Are you sure you want to delete "${props.taskType.name}"?`

  if (confirm(message)) {
    const success = await taskTypesStore.deleteTaskType(props.taskType.id)
    if (success) {
      emit('deleted', props.taskType.id)
    }
  }
}

const showAddItemForm = async () => {
  showAddForm.value = true
  await nextTick()
  newItemInput.value?.focus()
}

const addTaskItem = async () => {
  if (!newItemName.value.trim()) return

  const result = await taskTypesStore.addTaskItem({
    task_type_id: props.taskType.id,
    name: newItemName.value.trim(),
    is_regular: false
  })

  if (result) {
    newItemName.value = ''
    showAddForm.value = false
  }
}

const cancelAdd = () => {
  newItemName.value = ''
  showAddForm.value = false
}

const handleItemDeleted = (itemId: string) => {
  // Item is already removed from store, no additional action needed
}

const openAssignmentModal = () => {
  emit('assignment-click', `Department Assignments - ${props.taskType.name}`, props.taskType.id)
}

const handleItemAssignmentClick = (title: string, taskItemId: string) => {
  emit('assignment-click', title, undefined, taskItemId)
}
</script>

<style scoped>
.title-section {
  display: flex;
  align-items: center;
  gap: var(--spacing-md);
}

.task-type-name {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-text);
}

.item-count {
  font-size: 0.875rem;
  color: var(--color-text-light);
}

.edit-form {
  width: 100%;
}

.edit-input {
  width: 100%;
  padding: var(--spacing-sm);
  border: 1px solid var(--color-primary);
  border-radius: var(--radius);
  font-size: 1.125rem;
  font-weight: 600;
  background: var(--color-background);
}

.edit-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-light);
}

.has-assignments {
  color: var(--color-primary);
}

.add-item-form {
  margin-bottom: var(--spacing-lg);
  padding: var(--spacing-md);
  background: var(--color-gray-50);
  border-radius: var(--border-radius-md);
}

.form-row {
  display: flex;
  gap: var(--spacing-sm);
  align-items: center;
}

.item-input {
  flex: 1;
  padding: var(--spacing-sm) var(--spacing-md);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  font-size: 0.875rem;
}

.item-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px var(--color-primary-alpha);
}

.form-actions {
  display: flex;
  gap: var(--spacing-xs);
}

.items-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing-lg);
}

.empty-items {
  text-align: center;
  padding: var(--spacing-xl);
  color: var(--color-text-secondary);
  font-style: italic;
}

.empty-items p {
  margin: 0;
}

.add-item-section {
  display: flex;
  justify-content: center;
}

@container (max-width: 768px) {
  .card-header {
    flex-direction: column;
    align-items: stretch;
    gap: var(--spacing-md);
  }

  .title-section {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-xs);
  }

  .actions {
    justify-content: center;
  }

  .form-row {
    flex-direction: column;
    align-items: stretch;
  }

  .form-actions {
    justify-content: center;
  }
}
</style>
