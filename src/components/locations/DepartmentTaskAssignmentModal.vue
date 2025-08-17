<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3>Assign Task Type & Item to {{ department.name }}</h3>
        <button class="modal-close" @click="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div class="form-group">
          <label for="taskType">Task Type</label>
          <select 
            id="taskType" 
            v-model="selectedTaskTypeId" 
            class="form-control"
            @change="loadTaskItems"
          >
            <option value="">Select a task type</option>
            <option v-for="type in taskTypes" :key="type.id" :value="type.id">
              {{ type.name }}
            </option>
          </select>
        </div>
        
        <div class="form-group">
          <label for="taskItem">Task Item</label>
          <select 
            id="taskItem" 
            v-model="selectedTaskItemId" 
            class="form-control"
            :disabled="!selectedTaskTypeId || loadingTaskItems"
          >
            <option value="">{{ loadingTaskItems ? 'Loading items...' : 'Select a task item' }}</option>
            <option v-for="item in taskItems" :key="item.id" :value="item.id">
              {{ item.name }}{{ item.is_regular ? ' (Regular)' : '' }}
            </option>
          </select>
        </div>
      </div>
      
      <div class="modal-footer">
        <button @click="clearAssignment" class="btn btn-danger" v-if="hasExistingAssignment">
          Clear Assignment
        </button>
        <button @click="$emit('close')" class="btn btn-secondary">
          Cancel
        </button>
        <button 
          @click="saveAssignment" 
          class="btn btn-primary"
          :disabled="!canSave || saving"
        >
          {{ saving ? 'Saving...' : 'Save Assignment' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
import { useLocationsStore } from '../../stores/locationsStore';

const props = defineProps({
  department: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'saved']);

const taskTypesStore = useTaskTypesStore();
const locationsStore = useLocationsStore();

const selectedTaskTypeId = ref('');
const selectedTaskItemId = ref('');
const loadingTaskItems = ref(false);
const taskItems = ref([]);
const saving = ref(false);

const taskTypes = computed(() => taskTypesStore.taskTypes);

const hasExistingAssignment = computed(() => {
  const assignment = locationsStore.getDepartmentTaskAssignment(props.department.id);
  return !!assignment;
});

const canSave = computed(() => {
  return selectedTaskTypeId.value && selectedTaskItemId.value;
});

// Load existing assignment if it exists
onMounted(async () => {
  await taskTypesStore.fetchTaskTypes();
  await taskTypesStore.fetchTypeAssignments();
  
  // First check if there's a department task assignment in locations store
  const assignment = locationsStore.getDepartmentTaskAssignment(props.department.id);
  
  // Also check if there's an assignment in task types store where this department is an origin
  const typeAssignments = taskTypesStore.typeAssignments.filter(
    a => a.department_id === props.department.id && a.is_origin
  );
  
  if (assignment) {
    // If we have a department task assignment, use it
    selectedTaskTypeId.value = assignment.task_type_id;
    await loadTaskItems();
    selectedTaskItemId.value = assignment.task_item_id;
  } else if (typeAssignments.length > 0) {
    // If we have task type assignments where this department is an origin,
    // use the first one
    selectedTaskTypeId.value = typeAssignments[0].task_type_id;
    await loadTaskItems();
    
    // Look for a regular item
    const regularItem = taskItems.value.find(item => item.is_regular);
    if (regularItem) {
      selectedTaskItemId.value = regularItem.id;
    }
  }
});

// Load task items for the selected task type
async function loadTaskItems() {
  if (!selectedTaskTypeId.value) {
    taskItems.value = [];
    selectedTaskItemId.value = '';
    return;
  }
  
  loadingTaskItems.value = true;
  
  try {
    await taskTypesStore.fetchTaskItemsByType(selectedTaskTypeId.value);
    taskItems.value = taskTypesStore.getTaskItemsByType(selectedTaskTypeId.value);
    
    // Clear selected task item when task type changes
    selectedTaskItemId.value = '';
    
    // Auto-select regular item if it exists
    const regularItem = taskItems.value.find(item => item.is_regular);
    if (regularItem) {
      selectedTaskItemId.value = regularItem.id;
    }
  } catch (error) {
    console.error('Error loading task items:', error);
  } finally {
    loadingTaskItems.value = false;
  }
}

// Save the assignment
async function saveAssignment() {
  if (!canSave.value || saving.value) return;
  
  saving.value = true;
  
  try {
    // First, create or update the department task assignment in locations store
    const locationResult = await locationsStore.updateDepartmentTaskAssignment(
      props.department.id,
      selectedTaskTypeId.value,
      selectedTaskItemId.value
    );
    
    // Then, create or update the task type department assignment in task types store
    // Get current assignments for this task type
    const currentAssignments = taskTypesStore.getTypeAssignmentsByTypeId(selectedTaskTypeId.value);
    
    // Prepare the new assignment list - keep all existing assignments, but update/add the one for this department
    const newAssignments = currentAssignments.filter(a => a.department_id !== props.department.id);
    
    // Add the current department as an origin
    newAssignments.push({
      task_type_id: selectedTaskTypeId.value,
      department_id: props.department.id,
      is_origin: true,
      is_destination: false
    });
    
    // Check if there's a destination department in any of the current assignments
    // Find assignments where this task type has a destination
    const destinationAssignment = currentAssignments.find(a => a.is_destination);
    if (destinationAssignment) {
      // Add this as a destination assignment too
      newAssignments.push({
        task_type_id: selectedTaskTypeId.value,
        department_id: destinationAssignment.department_id,
        is_origin: false,
        is_destination: true
      });
    }
    
    // Update task type assignments
    const typeResult = await taskTypesStore.updateTypeAssignments(selectedTaskTypeId.value, newAssignments);
    
    if (locationResult && typeResult) {
      emit('saved');
      emit('close');
    }
  } catch (error) {
    console.error('Error saving assignment:', error);
  } finally {
    saving.value = false;
  }
}

// Clear the assignment
async function clearAssignment() {
  if (saving.value) return;
  
  saving.value = true;
  
  try {
    // First, remove the department task assignment from locations store
    const locationResult = await locationsStore.removeDepartmentTaskAssignment(props.department.id);
    
    // Then, remove this department from task type department assignments
    // Get current task type assignments
    const currentAssignments = taskTypesStore.typeAssignments.filter(
      a => a.department_id === props.department.id && a.is_origin
    );
    
    // Remove each assignment
    let typeResult = true;
    for (const assignment of currentAssignments) {
      // Get all assignments for this task type
      const taskTypeAssignments = taskTypesStore.getTypeAssignmentsByTypeId(assignment.task_type_id);
      
      // Filter out the one for this department
      const updatedAssignments = taskTypeAssignments.filter(a => a.department_id !== props.department.id);
      
      // Update task type assignments
      const result = await taskTypesStore.updateTypeAssignments(assignment.task_type_id, updatedAssignments);
      
      if (!result) {
        typeResult = false;
      }
    }
    
    if (locationResult && typeResult) {
      emit('saved');
      emit('close');
    }
  } catch (error) {
    console.error('Error clearing assignment:', error);
  } finally {
    saving.value = false;
  }
}
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
  max-width: 500px;
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

  h3 {
    margin: 0;
    font-size: mix.font-size('lg');
    font-weight: 600;
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
  justify-content: flex-end;
  gap: 8px;
}

.form-group {
  margin-bottom: 16px;
  
  label {
    display: block;
    margin-bottom: 8px;
    font-weight: 500;
  }
  
  .form-control {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.1);
    }
    
    &:disabled {
      background-color: #f5f5f5;
      cursor: not-allowed;
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
      background-color: color.adjust(mix.color('primary'), $lightness: -10%);
    }
  }
  
  &.btn-secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: color.adjust(#f1f1f1, $lightness: -5%);
    }
  }
  
  &.btn-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.adjust(#dc3545, $lightness: -10%);
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
