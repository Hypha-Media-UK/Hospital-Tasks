<template>
  <div class="area-cover-shift-list">
    <div class="area-cover-shift-list__header" v-if="showHeader">
      <h4>{{ shiftTypeLabel }} Coverage</h4>
      <button class="btn btn--primary" @click="showDepartmentSelector = true">
        Add Department
      </button>
    </div>
    
    <div v-if="shiftsStore.loading.areaCover" class="loading">
      Loading {{ shiftTypeLabel.toLowerCase() }} coverage...
    </div>
    
    <div v-else-if="assignments.length === 0" class="empty-state">
      No departments assigned to {{ shiftTypeLabel.toLowerCase() }} coverage. 
      Add departments using the button above.
    </div>
    
    <div v-else class="department-grid">
      <ShiftAreaCoverDepartmentCard 
        v-for="assignment in assignments" 
        :key="assignment.id"
        :assignment="assignment"
        @update="handleUpdate"
        @remove="handleRemove"
      />
    </div>
    
    <!-- Department Selector Modal -->
    <div v-if="showDepartmentSelector" class="modal-overlay">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">Add Department to {{ shiftTypeLabel }} Coverage</h3>
          <button class="modal-close" @click="showDepartmentSelector = false">&times;</button>
        </div>
        
        <div class="modal-body">
          <div v-if="availableDepartments.length === 0" class="empty-state">
            No departments available to add. All departments have already been assigned or no departments exist.
          </div>
          
          <div v-else class="department-selector">
            <div v-for="building in buildingsWithAvailableDepartments" :key="building.id" class="building-item">
              <div class="building-name">{{ building.name }}</div>
              
              <div v-for="department in building.departments" :key="department.id" class="department-item">
                <div class="department-name">{{ department.name }}</div>
                <button 
                  class="btn btn--small btn--primary" 
                  @click="addDepartment(department.id)"
                >
                  Add
                </button>
              </div>
            </div>
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            class="btn btn--secondary" 
            @click="showDepartmentSelector = false"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useShiftsStore } from '../../stores/shiftsStore';
import { useLocationsStore } from '../../stores/locationsStore';
import ShiftAreaCoverDepartmentCard from './ShiftAreaCoverDepartmentCard.vue';

const props = defineProps({
  shiftId: {
    type: String,
    required: true
  },
  shiftType: {
    type: String,
    required: true,
    validator: (value) => ['week_day', 'week_night', 'weekend_day', 'weekend_night'].includes(value)
  },
  showHeader: {
    type: Boolean,
    default: true
  }
});

const shiftsStore = useShiftsStore();
const locationsStore = useLocationsStore();

const showDepartmentSelector = ref(false);

// Expose showDepartmentSelector method to parent
const openDepartmentSelector = () => {
  showDepartmentSelector.value = true;
};

// Expose necessary methods to parent
defineExpose({
  openDepartmentSelector
});

// Computed properties
const shiftTypeLabel = computed(() => {
  switch (props.shiftType) {
    case 'week_day':
      return 'Day';
    case 'week_night':
      return 'Night';
    case 'weekend_day':
      return 'Weekend Day';
    case 'weekend_night':
      return 'Weekend Night';
    default:
      return 'Shift';
  }
});

const assignments = computed(() => {
  
  const filteredAssignments = shiftsStore.shiftAreaCoverAssignments.filter(
    assignment => assignment.shift_id === props.shiftId
  );
  
  return filteredAssignments;
});

const availableDepartments = computed(() => {
  const allDepartments = [];
  const buildingsWithDepartments = locationsStore.buildingsWithDepartments || [];
  
  buildingsWithDepartments.forEach(building => {
    building.departments.forEach(dept => {
      allDepartments.push({
        ...dept,
        building_name: building.name
      });
    });
  });
  
  // Filter out departments that are already assigned
  const assignedDeptIds = assignments.value.map(a => a.department_id);
  
  return allDepartments.filter(dept => !assignedDeptIds.includes(dept.id));
});

const buildingsWithAvailableDepartments = computed(() => {
  // Group available departments by building
  const buildingsMap = new Map();
  
  availableDepartments.value.forEach(dept => {
    const buildingId = dept.building_id;
    const buildingName = dept.building_name || 'Unknown Building';
    
    if (!buildingsMap.has(buildingId)) {
      buildingsMap.set(buildingId, {
        id: buildingId,
        name: buildingName,
        departments: []
      });
    }
    
    buildingsMap.get(buildingId).departments.push(dept);
  });
  
  // Convert map to array and sort by building name
  return Array.from(buildingsMap.values())
    .sort((a, b) => a.name.localeCompare(b.name));
});

// Methods
const addDepartment = async (departmentId) => {
  // Default times based on specific shift type from settings
  let startTime, endTime;
  
  if (props.shiftType === 'week_day') {
    startTime = '08:00:00';
    endTime = '16:00:00';
  } else if (props.shiftType === 'week_night') {
    startTime = '20:00:00';
    endTime = '04:00:00';
  } else if (props.shiftType === 'weekend_day') {
    startTime = '08:00:00';
    endTime = '16:00:00';
  } else if (props.shiftType === 'weekend_night') {
    startTime = '20:00:00';
    endTime = '04:00:00';
  }
  
  await shiftsStore.addShiftAreaCover(
    props.shiftId,
    departmentId,
    startTime,
    endTime
  );
  
  showDepartmentSelector.value = false;
};

const handleUpdate = (assignmentId, updates) => {
  shiftsStore.updateShiftAreaCover(assignmentId, updates);
};

const handleRemove = (assignmentId) => {
  if (confirm('Are you sure you want to remove this department from coverage?')) {
    shiftsStore.removeShiftAreaCover(assignmentId);
  }
};

// Lifecycle hooks
onMounted(async () => {
  
  // First, initialize the locations store if needed
  if (!locationsStore.buildings.length) {
    await locationsStore.initialize();
  }
  
  // Initialize areaCoverStore - we're directly importing and initializing here to ensure it's always loaded
  const { useAreaCoverStore } = await import('../../stores/areaCoverStore');
  const areaCoverStore = useAreaCoverStore();
  
  // Always ensure the specific shift type assignments are loaded
  await areaCoverStore.ensureAssignmentsLoaded(props.shiftType);
  
  // Check if this is a new shift without assignments yet
  const existingAssignments = shiftsStore.shiftAreaCoverAssignments.filter(a => a.shift_id === props.shiftId);
  if (existingAssignments.length === 0) {
    
    
    // If this is a new shift, we need to initialize the area cover from defaults
    await shiftsStore.setupShiftAreaCoverFromDefaults(props.shiftId, props.shiftType);
    
    // Verify it worked by refetching
    await shiftsStore.fetchShiftAreaCover(props.shiftId);
  }
  
  // Always fetch area cover assignments to ensure we have fresh data
  await shiftsStore.fetchShiftAreaCover(props.shiftId);
  
});
</script>

<!-- Styles are now handled by the global CSS layers -->
