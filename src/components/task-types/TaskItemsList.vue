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

<!-- Styles are now handled by the global CSS layers -->