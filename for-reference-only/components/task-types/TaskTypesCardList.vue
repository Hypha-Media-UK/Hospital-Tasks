<template>
  <div class="task-types-card-list">
    <div class="task-types-card-list__header">
      <button 
        class="btn btn--primary"
        @click="showAddForm = true"
        v-if="!showAddForm"
      >
        Add Task Type
      </button>
    </div>
    
    <div v-if="showAddForm" class="task-types-card-list__form">
      <input 
        v-model="newTaskTypeName" 
        placeholder="Task type name"
        class="task-types-card-list__input"
        ref="newTaskTypeInput"
        @keyup.enter="addTaskType"
        @keyup.esc="cancelAdd"
      />
      <div class="task-types-card-list__form-actions">
        <button 
          class="btn btn--primary" 
          @click="addTaskType"
          :disabled="!newTaskTypeName.trim()"
        >
          Add
        </button>
        <button 
          class="btn btn--secondary" 
          @click="cancelAdd"
        >
          Cancel
        </button>
      </div>
    </div>
    
    <div v-if="taskTypesStore.loading.taskTypes" class="task-types-card-list__loading">
      Loading task types...
    </div>
    
    <div v-else-if="taskTypes.length === 0 && !taskTypesStore.loading.taskTypes" class="task-types-card-list__empty">
      No task types added yet. Add your first task type to get started.
    </div>
    
    <div class="task-types-card-list__grid">
      <TaskTypeCard 
        v-for="taskType in taskTypes" 
        :key="taskType.id"
        :taskType="taskType"
        @view-items="viewTaskTypeItems"
        @deleted="handleTaskTypeDeleted"
      />
    </div>
    
    <!-- Task Type Items Modal -->
    <TaskTypeItemsModal
      v-if="selectedTaskType"
      :taskType="selectedTaskType"
      @close="selectedTaskType = null"
    />
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
import TaskTypeCard from './TaskTypeCard.vue';
import TaskTypeItemsModal from './TaskTypeItemsModal.vue';

const taskTypesStore = useTaskTypesStore();
const showAddForm = ref(false);
const newTaskTypeName = ref('');
const newTaskTypeInput = ref(null);
const selectedTaskType = ref(null);

// Get sorted task types
const taskTypes = computed(() => {
  return [...taskTypesStore.taskTypes].sort((a, b) => a.name.localeCompare(b.name));
});

// Show add form and focus input
const showAddTaskTypeForm = async () => {
  showAddForm.value = true;
  await nextTick();
  newTaskTypeInput.value?.focus();
};

// Add a new task type
const addTaskType = async () => {
  if (!newTaskTypeName.value.trim()) return;
  
  await taskTypesStore.addTaskType({
    name: newTaskTypeName.value.trim()
  });
  
  newTaskTypeName.value = '';
  showAddForm.value = false;
};

// Cancel adding a task type
const cancelAdd = () => {
  newTaskTypeName.value = '';
  showAddForm.value = false;
};

// View task type items
const viewTaskTypeItems = (taskTypeId) => {
  const taskType = taskTypesStore.taskTypes.find(t => t.id === taskTypeId);
  if (taskType) {
    selectedTaskType.value = taskType;
  }
};

// Handle task type deleted event
const handleTaskTypeDeleted = (taskTypeId) => {
  // If the deleted task type is currently selected, close the modal
  if (selectedTaskType.value && selectedTaskType.value.id === taskTypeId) {
    selectedTaskType.value = null;
  }
};

// Initialize data
onMounted(async () => {
  await taskTypesStore.initialize();
});
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.task-types-card-list {
  &__header {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    margin-bottom: 24px;
  }
  
  &__form {
    background-color: white;
    border-radius: mix.radius('lg');
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    padding: 16px;
    margin-bottom: 24px;
  }
  
  &__input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #ddd;
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    margin-bottom: 16px;
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
  
  &__form-actions {
    display: flex;
    gap: 12px;
  }
  
  &__loading {
    text-align: center;
    padding: 24px;
    color: rgba(0, 0, 0, 0.6);
  }
  
  &__empty {
    text-align: center;
    padding: 32px;
    background-color: white;
    border-radius: mix.radius('lg');
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    color: rgba(0, 0, 0, 0.6);
  }
  
  &__grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.adjust(mix.color('primary'), $lightness: -5%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: #e5e5e5;
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
