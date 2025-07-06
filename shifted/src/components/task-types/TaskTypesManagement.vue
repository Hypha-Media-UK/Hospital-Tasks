<template>
  <BaseManagementContainer
    title="Task Types"
    :items="taskTypesWithItems"
    :loading="taskTypesStore.loading.taskTypes"
    loading-text="Loading task types..."
    :empty-icon="TaskIcon"
    empty-title="No Task Types"
    empty-description="Create your first task type to get started with task management."
    add-button-text="Add Task Type"
    @add-item="openAddModal"
  >
    <template #items="{ items }">
      <TaskTypeCard
        v-for="taskType in items"
        :key="taskType.id"
        :task-type="taskType"
        @deleted="handleTaskTypeDeleted"
        @assignment-click="openAssignmentModal"
      />
    </template>

    <template #modals>
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
            class="form-control"
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
    </template>
  </BaseManagementContainer>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue'
import { useTaskTypesStore } from '../../stores/taskTypesStore'
import BaseButton from '../ui/BaseButton.vue'
import BaseModal from '../ui/BaseModal.vue'
import BaseManagementContainer from '../ui/BaseManagementContainer.vue'
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
/* Form styles */
.form-group {
  margin-bottom: var(--spacing-md);
}

.form-group label {
  display: block;
  margin-bottom: var(--spacing-xs);
  font-weight: 500;
  color: var(--color-text-primary);
}

.form-control {
  width: 100%;
  padding: var(--spacing-sm) var(--spacing-md);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  font-size: 1rem;
  transition: all 0.2s ease;
}

.form-control:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px var(--color-primary-alpha);
}
</style>
