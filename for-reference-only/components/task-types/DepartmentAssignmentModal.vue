<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container">
      <div class="modal-header">
        <h3 class="modal-title">Assign Departments to {{ taskType.name }}</h3>
        <button class="modal-close" @click="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div class="modal-info">
          <p>Select one department as origin and/or one department as destination.</p>
        </div>
        
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
          <div class="building-item special">
            <div class="building-name">Clear Selection</div>
            <div class="department-item">
              <div class="department-name">No Origin</div>
              <div class="department-radio">
                <input 
                  type="radio" 
                  id="origin-none" 
                  name="origin"
                  :checked="!selectedOrigin"
                  @change="clearOrigin"
                />
              </div>
              <div class="department-radio">
                <!-- Empty cell for alignment -->
              </div>
            </div>
            <div class="department-item">
              <div class="department-name">No Destination</div>
              <div class="department-radio">
                <!-- Empty cell for alignment -->
              </div>
              <div class="department-radio">
                <input 
                  type="radio" 
                  id="destination-none" 
                  name="destination"
                  :checked="!selectedDestination"
                  @change="clearDestination"
                />
              </div>
            </div>
          </div>
          
          <div v-for="building in buildings" :key="building.id" class="building-item">
            <div class="building-name">{{ building.name }}</div>
            
            <div v-for="department in building.departments" :key="department.id" class="department-item">
              <div class="department-name">{{ department.name }}</div>
              
              <div class="department-radio">
                <input 
                  type="radio" 
                  :id="'origin-' + department.id" 
                  name="origin"
                  :checked="isOrigin(department.id)"
                  @change="setOrigin(department.id)"
                />
              </div>
              
              <div class="department-radio">
                <input 
                  type="radio" 
                  :id="'destination-' + department.id" 
                  name="destination"
                  :checked="isDestination(department.id)"
                  @change="setDestination(department.id)"
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
          :disabled="taskTypesStore.loading.typeAssignments"
        >
          {{ taskTypesStore.loading.typeAssignments ? 'Saving...' : 'Save' }}
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

// Track selected origin and destination
const selectedOrigin = ref(null);
const selectedDestination = ref(null);

// Initialize assignments from existing data
onMounted(async () => {
  if (locationsStore.buildings.length === 0) {
    await locationsStore.initialize();
  }
  
  // Get existing assignments for this task type
  const existingAssignments = taskTypesStore.getTypeAssignmentsByTypeId(props.taskType.id);
  
  // Find the origin and destination departments (if any)
  const originAssignment = existingAssignments.find(a => a.is_origin);
  const destinationAssignment = existingAssignments.find(a => a.is_destination);
  
  // Set the selected departments
  selectedOrigin.value = originAssignment ? originAssignment.department_id : null;
  selectedDestination.value = destinationAssignment ? destinationAssignment.department_id : null;
});

// Check if a department is the origin
const isOrigin = (departmentId) => {
  return selectedOrigin.value === departmentId;
};

// Check if a department is the destination
const isDestination = (departmentId) => {
  return selectedDestination.value === departmentId;
};

// Set a department as the origin
const setOrigin = (departmentId) => {
  selectedOrigin.value = departmentId;
};

// Set a department as the destination
const setDestination = (departmentId) => {
  selectedDestination.value = departmentId;
};

// Clear the origin selection
const clearOrigin = () => {
  selectedOrigin.value = null;
};

// Clear the destination selection
const clearDestination = () => {
  selectedDestination.value = null;
};

// Save assignments
const saveAssignments = async () => {
  // Create the assignments array
  const assignmentsArray = [];
  
  // Add origin assignment if selected
  if (selectedOrigin.value) {
    assignmentsArray.push({
      task_type_id: props.taskType.id,
      department_id: selectedOrigin.value,
      is_origin: true,
      is_destination: false
    });
  }
  
  // Add destination assignment if selected
  if (selectedDestination.value) {
    // Check if it's the same as the origin
    if (selectedDestination.value === selectedOrigin.value) {
      // Update the existing assignment to be both origin and destination
      const index = assignmentsArray.findIndex(a => a.department_id === selectedDestination.value);
      if (index !== -1) {
        assignmentsArray[index].is_destination = true;
      }
    } else {
      // Add a new assignment
      assignmentsArray.push({
        task_type_id: props.taskType.id,
        department_id: selectedDestination.value,
        is_origin: false,
        is_destination: true
      });
    }
  }
  
  // Save to database
  const success = await taskTypesStore.updateTypeAssignments(props.taskType.id, assignmentsArray);
  
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

.modal-info {
  background-color: rgba(66, 133, 244, 0.1);
  border-radius: mix.radius('md');
  padding: 12px;
  margin-bottom: 16px;
  
  p {
    margin: 0;
    font-size: mix.font-size('sm');
    color: mix.color('primary');
  }
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
  
  &.special {
    background-color: rgba(0, 0, 0, 0.02);
    margin-bottom: 8px;
  }
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

.department-radio {
  display: flex;
  align-items: center;
  justify-content: center;
  
  input[type="radio"] {
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
