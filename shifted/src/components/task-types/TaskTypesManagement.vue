<template>
  <div class="task-types-management">
    <div class="header">
      <h2>Task Types</h2>
      <BaseButton @click="showAddModal = true" variant="primary">
        <PlusIcon />
        Add Task Type
      </BaseButton>
    </div>

    <div v-if="taskTypesStore.loading.taskTypes" class="loading">
      Loading task types...
    </div>

    <div v-else-if="taskTypesWithItems.length === 0" class="empty-state">
      <div class="empty-content">
        <TaskIcon class="empty-icon" />
        <h3>No Task Types</h3>
        <p>Create your first task type to get started with task management.</p>
        <BaseButton @click="showAddModal = true" variant="primary">
          Add Task Type
        </BaseButton>
      </div>
    </div>

    <div v-else class="task-types-list">
      <TaskTypeCard
        v-for="taskType in taskTypesWithItems"
        :key="taskType.id"
        :task-type="taskType"
        @deleted="handleTaskTypeDeleted"
        @assignment-click="openAssignmentModal"
      />
    </div>

    <!-- Add Task Type Modal -->
    <BaseModal
      v-if="showAddModal"
      title="Add Task Type"
      size="md"
      show-footer
      @close="closeAddModal"
    >
      <div class="form-group">
        <label for="taskTypeName">Task Type Name</label>
        <input
          id="taskTypeName"
          v-model="newTaskTypeName"
          type="text"
          placeholder="Enter task type name"
          @keyup.enter="addTaskType"
          @keyup.esc="closeAddModal"
          ref="taskTypeNameInput"
        />
      </div>

      <template #footer>
        <BaseButton @click="closeAddModal" variant="secondary">
          Cancel
        </BaseButton>
        <BaseButton
          @click="addTaskType"
          variant="primary"
          :disabled="!newTaskTypeName.trim() || taskTypesStore.loading.taskTypes"
        >
          Add Task Type
        </BaseButton>
      </template>
    </BaseModal>

    <!-- Assignment Modal -->
    <AssignmentModal
      v-if="assignmentModal.show"
      :task-type-id="assignmentModal.taskTypeId"
      :task-item-id="assignmentModal.taskItemId"
      :title="assignmentModal.title"
      @close="closeAssignmentModal"
      @saved="handleAssignmentsSaved"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue'
import { useTaskTypesStore } from '../../stores/taskTypesStore'
import BaseButton from '../ui/BaseButton.vue'
import BaseModal from '../ui/BaseModal.vue'
import TaskTypeCard from './TaskTypeCard.vue'
import AssignmentModal from './AssignmentModal.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import TaskIcon from '../icons/TaskIcon.vue'

const taskTypesStore = useTaskTypesStore()

// State
const showAddModal = ref(false)
const newTaskTypeName = ref('')
const taskTypeNameInput = ref<HTMLInputElement>()

const assignmentModal = ref({
  show: false,
  taskTypeId: undefined as string | undefined,
  taskItemId: undefined as string | undefined,
  title: ''
})

// Computed
const taskTypesWithItems = computed(() => taskTypesStore.taskTypesWithItems)

// Methods
const addTaskType = async () => {
  if (!newTaskTypeName.value.trim()) return

  const result = await taskTypesStore.addTaskType({
    name: newTaskTypeName.value.trim()
  })

  if (result) {
    newTaskTypeName.value = ''
    showAddModal.value = false
  }
}

const closeAddModal = () => {
  newTaskTypeName.value = ''
  showAddModal.value = false
}

const handleTaskTypeDeleted = (taskTypeId: string) => {
  // Task type is already removed from store, no additional action needed
}

const showAssignmentModal = (title: string, taskTypeId?: string, taskItemId?: string) => {
  assignmentModal.value = {
    show: true,
    taskTypeId,
    taskItemId,
    title
  }
}

const closeAssignmentModal = () => {
  assignmentModal.value = {
    show: false,
    taskTypeId: undefined,
    taskItemId: undefined,
    title: ''
  }
}

const handleAssignmentsSaved = () => {
  closeAssignmentModal()
}

// Watch for modal opening to focus input
const openAddModal = async () => {
  showAddModal.value = true
  await nextTick()
  taskTypeNameInput.value?.focus()
}

// Provide method for child components to open assignment modal
const openAssignmentModal = (title: string, taskTypeId?: string, taskItemId?: string) => {
  showAssignmentModal(title, taskTypeId, taskItemId)
}

// Expose methods for child components
defineExpose({
  openAssignmentModal
})

// Initialize
onMounted(async () => {
  await taskTypesStore.initialize()
})
</script>

<style scoped>
.task-types-management {
  container-type: inline-size;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-lg);
}

.header h2 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--color-text-primary);
}

.loading {
  text-align: center;
  padding: var(--spacing-xl);
  color: var(--color-text-secondary);
}

.empty-state {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 400px;
}

.empty-content {
  text-align: center;
  max-width: 400px;
}

.empty-icon {
  width: 64px;
  height: 64px;
  margin: 0 auto var(--spacing-lg);
  color: var(--color-text-tertiary);
}

.empty-content h3 {
  margin: 0 0 var(--spacing-sm);
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--color-text-primary);
}

.empty-content p {
  margin: 0 0 var(--spacing-lg);
  color: var(--color-text-secondary);
  line-height: 1.5;
}

.task-types-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.form-group {
  margin-bottom: var(--spacing-md);
}

.form-group label {
  display: block;
  margin-bottom: var(--spacing-xs);
  font-weight: 500;
  color: var(--color-text-primary);
}

.form-group input {
  width: 100%;
  padding: var(--spacing-sm) var(--spacing-md);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  font-size: 1rem;
  transition: all 0.2s ease;
}

.form-group input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px var(--color-primary-alpha);
}

@container (max-width: 768px) {
  .header {
    flex-direction: column;
    align-items: stretch;
    gap: var(--spacing-md);
  }
}
</style>
