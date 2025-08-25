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
              <input 
                v-model.number="newTaskItemPortersRequired" 
                type="number"
                min="1"
                placeholder="Porters Required"
                class="form-control porters-input"
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
            <div 
              v-for="item in taskItems" 
              :key="item.id" 
              class="task-item"
              :class="{ 'task-item--regular': isRegular(item.id) }"
            >
              <div v-if="editingTaskItem === item.id" class="task-item-edit">
                <div class="edit-form-group">
                  <input 
                    v-model="editTaskItemName" 
                    class="form-control"
                    placeholder="Task item name"
                    @keyup.enter="saveTaskItem(item)"
                    @keyup.esc="cancelEditTaskItem"
                  />
                  <input 
                    v-model.number="editTaskItemPortersRequired" 
                    type="number"
                    min="1"
                    max="10"
                    placeholder="Porters Required"
                    class="form-control porters-input"
                    @keyup.enter="saveTaskItem(item)"
                    @keyup.esc="cancelEditTaskItem"
                  />
                </div>
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
                  <div v-if="item.porters_required && item.porters_required > 1" class="task-item-porters">
                    ({{ item.porters_required }} porters)
                  </div>
                </div>
                
                <div class="task-item-actions">
                  <button 
                    @click="toggleRegular(item.id)"
                    class="btn-action"
                    :class="{ 'btn-active': isRegular(item.id) }"
                    title="Mark as Regular"
                  >
                    <StarIcon size="16" :filled="isRegular(item.id)" />
                  </button>
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
import StarIcon from '../icons/StarIcon.vue';
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
const newTaskItemPortersRequired = ref(1);
const editingTaskItem = ref(null);
const editTaskItemName = ref('');
const editTaskItemPortersRequired = ref(1);

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

// Check if a task item is marked as regular
const isRegular = (itemId) => {
  const item = taskTypesStore.taskItems.find(item => item.id === itemId);
  return item && item.is_regular === true;
};

// Toggle regular status for a task item
const toggleRegular = async (itemId) => {
  const item = taskTypesStore.taskItems.find(item => item.id === itemId);
  if (item) {
    await taskTypesStore.setTaskItemRegular(itemId, !item.is_regular);
  }
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
    name: newTaskItemName.value.trim(),
    porters_required: newTaskItemPortersRequired.value || 1
  });
  
  newTaskItemName.value = '';
  newTaskItemPortersRequired.value = 1;
};

// Edit task item
const editTaskItem = (item) => {
  editingTaskItem.value = item.id;
  editTaskItemName.value = item.name;
  editTaskItemPortersRequired.value = item.porters_required || 1;
};

// Save task item changes
const saveTaskItem = async (item) => {
  if (!editTaskItemName.value.trim()) {
    cancelEditTaskItem();
    return;
  }
  
  const hasNameChange = editTaskItemName.value !== item.name;
  const hasPortersChange = editTaskItemPortersRequired.value !== (item.porters_required || 1);
  
  if (hasNameChange || hasPortersChange) {
    const updateData = {};
    if (hasNameChange) {
      updateData.name = editTaskItemName.value.trim();
    }
    if (hasPortersChange) {
      updateData.porters_required = editTaskItemPortersRequired.value || 1;
    }
    
    await taskTypesStore.updateTaskItem(item.id, updateData);
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

<!-- Styles are now handled by the global CSS layers -->