<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container">
      <div class="modal-header">
        <h3 class="modal-title">Assign Departments to {{ taskItem.name }}</h3>
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
          :disabled="taskTypesStore.loading.itemAssignments"
        >
          {{ taskTypesStore.loading.itemAssignments ? 'Saving...' : 'Save' }}
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
  taskItem: {
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
  
  // Fetch existing assignments for this task item
  const existingAssignments = await taskTypesStore.fetchItemAssignments(props.taskItem.id);
  
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
      task_item_id: props.taskItem.id,
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
        task_item_id: props.taskItem.id,
        department_id: selectedDestination.value,
        is_origin: false,
        is_destination: true
      });
    }
  }
  
  // Save to database
  const success = await taskTypesStore.updateItemAssignments(props.taskItem.id, assignmentsArray);
  
  if (success) {
    emit('saved');
    emit('close');
  }
};
</script>

<!-- Styles are now handled by the global CSS layers -->