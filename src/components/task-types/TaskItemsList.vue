<template>
  <div class="task-items-list">
    <div class="task-items-list__header">
      <h4 class="task-items-list__title">Task Items</h4>
      <div class="task-items-list__add">
        <IconButton 
          title="Add Task Item"
          @click="showAddForm = true"
        >
          <PlusIcon />
        </IconButton>
      </div>
    </div>
    
    <div v-if="showAddForm" class="task-items-list__form">
      <input 
        v-model="newTaskItemName" 
        placeholder="Task item name"
        class="task-items-list__input"
        ref="newTaskItemInput"
        @keyup.enter="addTaskItem"
        @keyup.esc="cancelAdd"
      />
      <div class="task-items-list__form-actions">
        <button 
          class="btn btn--primary btn--small" 
          @click="addTaskItem"
          :disabled="!newTaskItemName.trim()"
        >
          Add
        </button>
        <button 
          class="btn btn--secondary btn--small" 
          @click="cancelAdd"
        >
          Cancel
        </button>
      </div>
    </div>
    
    <div v-if="taskItems.length === 0 && !showAddForm" class="task-items-list__empty">
      No task items added yet
    </div>
    
    <transition-group name="list" tag="div" class="task-items-list__items">
      <TaskItemItem 
        v-for="taskItem in taskItems" 
        :key="taskItem.id"
        :taskItem="taskItem"
      />
    </transition-group>
  </div>
</template>

<script setup>
import { ref, nextTick, computed } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
import TaskItemItem from './TaskItemItem.vue';
import IconButton from '../IconButton.vue';
import PlusIcon from '../icons/PlusIcon.vue';

const props = defineProps({
  taskTypeId: {
    type: String,
    required: true
  }
});

const taskTypesStore = useTaskTypesStore();
const showAddForm = ref(false);
const newTaskItemName = ref('');
const newTaskItemInput = ref(null);

// Get task items for this task type
const taskItems = computed(() => {
  return taskTypesStore.getTaskItemsByTypeId(props.taskTypeId);
});

// Show add form and focus input
const showAddTaskItemForm = async () => {
  showAddForm.value = true;
  await nextTick();
  newTaskItemInput.value?.focus();
};

// Add a new task item
const addTaskItem = async () => {
  if (!newTaskItemName.value.trim()) return;
  
  await taskTypesStore.addTaskItem({
    task_type_id: props.taskTypeId,
    name: newTaskItemName.value.trim()
  });
  
  newTaskItemName.value = '';
  showAddForm.value = false;
};

// Cancel adding a task item
const cancelAdd = () => {
  newTaskItemName.value = '';
  showAddForm.value = false;
};
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.task-items-list {
  margin-top: 8px;
  margin-left: 16px;
  
  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  
  &__title {
    font-size: mix.font-size('sm');
    font-weight: 500;
    color: rgba(0, 0, 0, 0.6);
    margin: 0;
  }
  
  &__form {
    margin-bottom: 12px;
  }
  
  &__input {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #ddd;
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    margin-bottom: 8px;
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
  
  &__form-actions {
    display: flex;
    gap: 8px;
  }
  
  &__empty {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.5);
    font-style: italic;
    padding: 8px 0;
  }
  
  &__items {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
}

// Button styles
.btn {
  padding: 6px 12px;
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
  
  &--small {
    font-size: mix.font-size('sm');
    padding: 4px 10px;
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

// List transition animations
.list-enter-active,
.list-leave-active {
  transition: all 0.3s ease;
}

.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(-20px);
}
</style>
