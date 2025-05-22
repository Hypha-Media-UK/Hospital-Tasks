<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container">
      <div class="modal-header">
        <h3 class="modal-title">Assign Departments to {{ taskType.name }}</h3>
        <button class="modal-close" @click="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div class="assignment-header">
          <div class="assignment-header__item">Department</div>
          <div class="assignment-header__item">Origin</div>
          <div class="assignment-header__item">Destination</div>
        </div>
        
        <div v-if="locationsStore.loading.buildings" class="loading">
          Loading departments...
        </div>
        
        <div v-else-if="buildings.length === 0" class="empty-state">
          No buildings or departments found. Please add some in the Locations tab.
        </div>
        
        <div v-else class="buildings-list">
          <div v-for="building in buildings" :key="building.id" class="building-item">
            <div class="building-name">{{ building.name }}</div>
            
            <div v-for="department in building.departments" :key="department.id" class="department-item">
              <div class="department-name">{{ department.name }}</div>
              
              <div class="department-checkbox">
                <input 
                  type="checkbox" 
                  :id="'origin-' + department.id" 
                  :checked="assignments[department.id]?.is_origin"
                  @change="toggleOrigin(department.id)"
                />
              </div>
              
              <div class="department-checkbox">
                <input 
                  type="checkbox" 
                  :id="'destination-' + department.id" 
                  :checked="assignments[department.id]?.is_destination"
                  @change="toggleDestination(department.id)"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <button 
          class="btn btn--secondary" 
          @click="$emit('close')"
        >
          Cancel
        </button>
        <button 
          class="btn btn--primary" 
          @click="saveAssignments"
          :disabled="taskTypesStore.loading.assignments"
        >
          {{ taskTypesStore.loading.assignments ? 'Saving...' : 'Save' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import { useTaskTypesStore } from '../../stores/taskTypesStore';

const props = defineProps({
  taskType: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'saved']);

const locationsStore = useLocationsStore();
const taskTypesStore = useTaskTypesStore();

// Get buildings with their departments
const buildings = computed(() => {
  return locationsStore.buildingsWithDepartments;
});

// Create a reactive map of department assignments
const assignments = ref({});

// Initialize assignments from existing data
onMounted(async () => {
  if (locationsStore.buildings.length === 0) {
    await locationsStore.initialize();
  }
  
  // Get existing assignments for this task type
  const existingAssignments = taskTypesStore.getAssignmentsByTypeId(props.taskType.id);
  
  // Initialize assignments map
  const assignmentsMap = {};
  
  // For each department, set up initial assignment state
  buildings.value.forEach(building => {
    building.departments.forEach(department => {
      const existing = existingAssignments.find(a => a.department_id === department.id);
      assignmentsMap[department.id] = {
        department_id: department.id,
        task_type_id: props.taskType.id,
        is_origin: existing ? existing.is_origin : false,
        is_destination: existing ? existing.is_destination : false
      };
    });
  });
  
  assignments.value = assignmentsMap;
});

// Toggle origin status for a department
const toggleOrigin = (departmentId) => {
  if (assignments.value[departmentId]) {
    assignments.value[departmentId].is_origin = !assignments.value[departmentId].is_origin;
  }
};

// Toggle destination status for a department
const toggleDestination = (departmentId) => {
  if (assignments.value[departmentId]) {
    assignments.value[departmentId].is_destination = !assignments.value[departmentId].is_destination;
  }
};

// Save all assignments
const saveAssignments = async () => {
  // Convert assignments map to array
  const assignmentsArray = Object.values(assignments.value);
  
  // Save to database
  const success = await taskTypesStore.updateAssignments(props.taskType.id, assignmentsArray);
  
  if (success) {
    emit('saved');
    emit('close');
  }
};
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

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

.modal-title {
  margin: 0;
  font-size: mix.font-size('lg');
  font-weight: 600;
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
  gap: 12px;
}

.assignment-header {
  display: grid;
  grid-template-columns: 1fr 80px 80px;
  gap: 8px;
  margin-bottom: 12px;
  font-weight: 600;
  
  &__item {
    padding: 8px 4px;
    text-align: center;
    
    &:first-child {
      text-align: left;
    }
  }
}

.buildings-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.building-item {
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: mix.radius('md');
  overflow: hidden;
}

.building-name {
  background-color: rgba(0, 0, 0, 0.03);
  padding: 8px 12px;
  font-weight: 600;
}

.department-item {
  display: grid;
  grid-template-columns: 1fr 80px 80px;
  gap: 8px;
  padding: 8px 12px;
  border-top: 1px solid rgba(0, 0, 0, 0.05);
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.02);
  }
}

.department-name {
  display: flex;
  align-items: center;
}

.department-checkbox {
  display: flex;
  align-items: center;
  justify-content: center;
  
  input[type="checkbox"] {
    width: 18px;
    height: 18px;
    cursor: pointer;
  }
}

.loading, .empty-state {
  padding: 24px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
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
