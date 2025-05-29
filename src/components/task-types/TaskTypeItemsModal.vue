<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <div class="modal-title-container">
          <div v-if="isEditingTaskTypeName" class="task-type-name-edit">
            <input 
              v-model="editTaskTypeName" 
              ref="taskTypeNameInput"
              class="form-control"
              @keyup.enter="saveTaskTypeName"
              @keyup.esc="cancelEditTaskTypeName"
              placeholder="Task type name"
            />
            <div class="edit-actions">
              <button 
                class="btn btn-small btn-primary" 
                @click="saveTaskTypeName"
                :disabled="!editTaskTypeName.trim()"
              >
                Save
              </button>
              <button 
                class="btn btn-small btn-secondary" 
                @click="cancelEditTaskTypeName"
              >
                Cancel
              </button>
            </div>
          </div>
          <div v-else class="modal-title">
            <h3>{{ taskType.name }} Items</h3>
            <div class="task-type-actions">
              <button 
                @click="showTaskTypeAssignmentModal = true" 
                class="btn-action"
                title="Assign departments to task type"
              >
                <MapPinIcon size="16" :active="hasTaskTypeAssignments" />
              </button>
              <button 
                @click="startEditTaskTypeName" 
                class="btn-action edit-task-type-btn"
                title="Edit task type name"
              >
                <EditIcon size="16" />
              </button>
            </div>
          </div>
        </div>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <!-- Add Task Item Form -->
        <div class="task-item-form">
          <div class="form-header">
            <h4>Add Task Item</h4>
          </div>
          
          <div class="form-content">
            <div class="form-group">
              <input 
                v-model="newTaskItemName" 
                placeholder="Task item name"
                class="form-control"
                @keyup.enter="addTaskItem"
              />
              <button 
                class="btn btn-primary"
                @click="addTaskItem"
                :disabled="!newTaskItemName.trim()"
              >
                Add
              </button>
            </div>
          </div>
        </div>
        
        <!-- Task Items List -->
        <div class="task-items-section">
          <h4 class="section-title">Task Items</h4>
          
          <div v-if="taskItems.length === 0" class="empty-state">
            No task items added yet. Add your first task item using the form above.
          </div>
          
          <div v-else class="task-items-list">
            <div v-for="item in taskItems" :key="item.id" class="task-item">
              <div v-if="editingTaskItem === item.id" class="task-item-edit">
                <input 
                  v-model="editTaskItemName" 
                  class="form-control"
                  @keyup.enter="saveTaskItem(item)"
                  @keyup.esc="cancelEditTaskItem"
                />
                <div class="edit-actions">
                  <button 
                    class="btn btn-small btn-primary" 
                    @click="saveTaskItem(item)"
                    :disabled="!editTaskItemName.trim()"
                  >
                    Save
                  </button>
                  <button 
                    class="btn btn-small btn-secondary" 
                    @click="cancelEditTaskItem"
                  >
                    Cancel
                  </button>
                </div>
              </div>
              <div v-else class="task-item-content">
                <div class="task-item-details">
                  <div class="task-item-name">{{ item.name }}</div>
                </div>
                
                <div class="task-item-actions">
                  <button 
                    @click="openItemAssignmentModal(item)"
                    class="btn-action"
                    title="Assign departments to task item"
                  >
                    <MapPinIcon size="16" :active="hasItemAssignments(item.id)" />
                  </button>
                  <button 
                    @click="editTaskItem(item)"
                    class="btn-action"
                    title="Edit task item"
                  >
                    <EditIcon size="16" />
                  </button>
                  <button 
                    @click="deleteTaskItem(item)"
                    class="btn-action"
                    title="Delete task item"
                  >
                    <TrashIcon size="16" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <div class="modal-footer-left">
          <button 
            class="btn btn-danger" 
            @click="confirmDeleteTaskType"
          >
            Delete Task Type
          </button>
        </div>
        <div class="modal-footer-right">
          <button @click="$emit('close')" class="btn btn-secondary">
            Close
          </button>
        </div>
      </div>
    </div>
    
    <!-- Department Assignment Modals -->
    <DepartmentAssignmentModal 
      v-if="showTaskTypeAssignmentModal"
      :taskType="taskType"
      @close="showTaskTypeAssignmentModal = false"
      @saved="showTaskTypeAssignmentModal = false"
    />
    
    <ItemDepartmentAssignmentModal 
      v-if="selectedTaskItem"
      :taskItem="selectedTaskItem"
      @close="selectedTaskItem = null"
      @saved="selectedTaskItem = null"
    />
  </div>
</template>

<script setup>
import { ref, computed, nextTick } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
import EditIcon from '../icons/EditIcon.vue';
import TrashIcon from '../icons/TrashIcon.vue';
import MapPinIcon from '../icons/MapPinIcon.vue';
import DepartmentAssignmentModal from './DepartmentAssignmentModal.vue';
import ItemDepartmentAssignmentModal from './ItemDepartmentAssignmentModal.vue';

const props = defineProps({
  taskType: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close']);

const taskTypesStore = useTaskTypesStore();

// Task Type edit state
const isEditingTaskTypeName = ref(false);
const editTaskTypeName = ref('');
const taskTypeNameInput = ref(null);

// Task Item state
const newTaskItemName = ref('');
const editingTaskItem = ref(null);
const editTaskItemName = ref('');

// Department assignment modal state
const showTaskTypeAssignmentModal = ref(false);
const selectedTaskItem = ref(null);

// Check if task type has any department assignments
const hasTaskTypeAssignments = computed(() => {
  return taskTypesStore.hasTypeAssignments(props.taskType.id);
});

// Check if a task item has any department assignments
const hasItemAssignments = (itemId) => {
  return taskTypesStore.hasItemAssignments(itemId);
};

// Open item assignment modal
const openItemAssignmentModal = (item) => {
  selectedTaskItem.value = item;
};

// Task Type name editing
const startEditTaskTypeName = async () => {
  editTaskTypeName.value = props.taskType.name;
  isEditingTaskTypeName.value = true;
  // Wait for the DOM to update before focusing the input
  await nextTick();
  taskTypeNameInput.value?.focus();
};

const saveTaskTypeName = async () => {
  if (!editTaskTypeName.value.trim()) {
    cancelEditTaskTypeName();
    return;
  }
  
  if (editTaskTypeName.value !== props.taskType.name) {
    await taskTypesStore.updateTaskType(props.taskType.id, {
      name: editTaskTypeName.value.trim()
    });
  }
  
  isEditingTaskTypeName.value = false;
};

const cancelEditTaskTypeName = () => {
  isEditingTaskTypeName.value = false;
  editTaskTypeName.value = '';
};

// Computed property to get task items for this task type
const taskItems = computed(() => {
  return taskTypesStore.getTaskItemsByType(props.taskType.id)
    .sort((a, b) => a.name.localeCompare(b.name));
});

// Add a new task item
const addTaskItem = async () => {
  if (!newTaskItemName.value.trim()) return;
  
  await taskTypesStore.addTaskItem({
    task_type_id: props.taskType.id,
    name: newTaskItemName.value.trim()
  });
  
  newTaskItemName.value = '';
};

// Edit task item
const editTaskItem = (item) => {
  editingTaskItem.value = item.id;
  editTaskItemName.value = item.name;
};

// Save task item changes
const saveTaskItem = async (item) => {
  if (!editTaskItemName.value.trim()) {
    cancelEditTaskItem();
    return;
  }
  
  if (editTaskItemName.value !== item.name) {
    await taskTypesStore.updateTaskItem(item.id, {
      name: editTaskItemName.value.trim()
    });
  }
  
  cancelEditTaskItem();
};

// Cancel editing task item
const cancelEditTaskItem = () => {
  editingTaskItem.value = null;
  editTaskItemName.value = '';
};

// Delete task item
const deleteTaskItem = async (item) => {
  if (confirm(`Are you sure you want to delete "${item.name}"?`)) {
    await taskTypesStore.deleteTaskItem(item.id);
  }
};

// Delete task type with confirmation
const confirmDeleteTaskType = async () => {
  if (confirm(`Are you sure you want to delete "${props.taskType.name}" and all its items?`)) {
    await taskTypesStore.deleteTaskType(props.taskType.id);
    emit('close');
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

// Modal styles
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-container {
  background-color: white;
  border-radius: mix.radius('lg');
  width: 90%;
  max-width: 600px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.modal-header {
  padding: 16px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title-container {
  display: flex;
  flex: 1;
  margin-right: 16px;
}

.modal-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  gap: 8px;
  
  h3 {
    margin: 0;
    font-size: mix.font-size('lg');
    font-weight: 600;
  }
  
  .task-type-actions {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  
  .edit-task-type-btn {
    opacity: 0.7;
    
    &:hover {
      opacity: 1;
    }
  }
}

.task-type-name-edit {
  width: 100%;
  
  .form-control {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid mix.color('primary');
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    margin-bottom: 8px;
    
    &:focus {
      outline: none;
      box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.1);
    }
  }
  
  .edit-actions {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }
}

.modal-close {
  background: transparent;
  border: none;
  font-size: 24px;
  cursor: pointer;
  padding: 0;
  line-height: 1;
}

.modal-body {
  padding: 16px;
  overflow-y: auto;
  flex: 1;
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: space-between;
  
  &-left {
    display: flex;
    gap: 12px;
  }
  
  &-right {
    display: flex;
    gap: 12px;
  }
}

// Task Item form styles
.task-item-form {
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: mix.radius('md');
  margin-bottom: 24px;
  overflow: hidden;
  
  .form-header {
    padding: 12px 16px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
    
    h4 {
      margin: 0;
      font-size: mix.font-size('md');
      font-weight: 600;
    }
  }
  
  .form-content {
    padding: 16px;
  }
  
  .form-group {
    display: flex;
    gap: 8px;
    
    .form-control {
      flex: 1;
      padding: 8px 12px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('md');
      font-size: mix.font-size('md');
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.1);
      }
    }
  }
}

// Task Items section styles
.task-items-section {
  .section-title {
    font-size: mix.font-size('md');
    font-weight: 600;
    margin-top: 0;
    margin-bottom: 16px;
    padding-bottom: 8px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  }
  
  .empty-state {
    padding: 24px;
    text-align: center;
    color: rgba(0, 0, 0, 0.6);
    background-color: rgba(0, 0, 0, 0.02);
    border-radius: mix.radius('md');
  }
  
  .task-items-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  
  .task-item {
    border-radius: mix.radius('md');
    background-color: rgba(0, 0, 0, 0.02);
    overflow: hidden;
  }
  
  .task-item-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 16px;
  }
  
  .task-item-details {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  
  .task-item-name {
    font-weight: 500;
  }
  
  .task-item-actions {
    display: flex;
    gap: 4px;
  }
  
  .task-item-edit {
    padding: 10px 16px;
    
    .form-control {
      width: 100%;
      padding: 8px 12px;
      border: 1px solid mix.color('primary');
      border-radius: mix.radius('md');
      font-size: mix.font-size('md');
      margin-bottom: 8px;
      
      &:focus {
        outline: none;
        box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.1);
      }
    }
    
    .edit-actions {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
    }
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
  
  &.btn-primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
  }
  
  &.btn-secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: color.scale(#f1f1f1, $lightness: -5%);
    }
  }
  
  &.btn-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#dc3545, $lightness: -10%);
    }
  }
  
  &.btn-small {
    padding: 4px 10px;
    font-size: mix.font-size('sm');
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.btn-action {
  background: none;
  border: none;
  cursor: pointer;
  padding: 6px;
  border-radius: mix.radius('sm');
  line-height: 1;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.05);
  }
}
</style>
