<template>
  <div class="task-types-list">
    <div class="task-types-list__header">
      <button 
        class="btn btn--primary"
        @click="showAddForm = true"
        v-if="!showAddForm"
      >
        Add Task Type
      </button>
    </div>
    
    <div v-if="showAddForm" class="task-types-list__form">
      <input 
        v-model="newTaskTypeName" 
        placeholder="Task type name"
        class="task-types-list__input"
        ref="newTaskTypeInput"
        @keyup.enter="addTaskType"
        @keyup.esc="cancelAdd"
      />
      <div class="task-types-list__form-actions">
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
    
    <div v-if="taskTypesStore.loading.taskTypes" class="task-types-list__loading">
      Loading task types...
    </div>
    
    <div v-else-if="taskTypes.length === 0 && !taskTypesStore.loading.taskTypes" class="task-types-list__empty">
      No task types added yet. Add your first task type to get started.
    </div>
    
    <transition-group name="list" tag="div" class="task-types-list__items">
      <TaskTypeItem 
        v-for="taskType in taskTypes" 
        :key="taskType.id"
        :taskType="taskType"
      />
    </transition-group>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
import TaskTypeItem from './TaskTypeItem.vue';

const taskTypesStore = useTaskTypesStore();
const showAddForm = ref(false);
const newTaskTypeName = ref('');
const newTaskTypeInput = ref(null);

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

// Initialize data
onMounted(async () => {
  await taskTypesStore.initialize();
});
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.task-types-list {
  &__header {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    margin-bottom: 24px;
  }
  
  &__title {
    font-size: mix.font-size('xl');
    font-weight: 600;
    margin: 0;
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

// List transition animations
.list-enter-active,
.list-leave-active {
  transition: all 0.5s ease;
}

.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateY(30px);
}
</style>
