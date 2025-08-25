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

<!-- Styles are now handled by the global CSS layers -->