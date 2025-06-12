<template>
  <div class="shift-porter-pool">
    <!-- Loading Overlay -->
    <div v-if="isLoading" class="loading-overlay">
      <div class="spinner"></div>
      <div class="loading-text">Loading shift data...</div>
    </div>
    
    <div v-if="shiftsStore.loading.porterPool" class="loading">
      Loading shift porters...
    </div>
    
    <div v-else-if="sortedPorterPool.length === 0" class="empty-state">
      No porters assigned to this shift yet. Add porters using the button above.
    </div>
    
    <div v-else class="porter-grid">
      <div v-for="entry in sortedPorterPool" :key="entry.id" class="porter-card" 
           :class="{ 'assigned': getPorterAssignments(entry.porter_id).length > 0 }">
        <div class="porter-card__content">
          <div class="porter-card__name" 
               :class="{ 
                 'porter-absent': isPorterAbsent(entry.porter_id),
                 'porter-illness': getPorterAbsenceType(entry.porter_id) === 'illness',
                 'porter-annual-leave': getPorterAbsenceType(entry.porter_id) === 'annual_leave'
               }">
            {{ entry.porter.first_name }} {{ entry.porter.last_name }}
            <span v-if="getPorterAbsenceType(entry.porter_id) === 'illness'" class="absence-badge illness">ILL</span>
            <span v-if="getPorterAbsenceType(entry.porter_id) === 'annual_leave'" class="absence-badge annual-leave">AL</span>
          </div>
          
          <div class="porter-card__assignments">
            <div v-if="getPorterAssignments(entry.porter_id).length > 0" class="assignments-list">
              <div v-for="assignment in getPorterAssignments(entry.porter_id)" :key="assignment.id" 
                   class="assignment-item" 
                   :style="{ backgroundColor: getAssignmentBackgroundColor(assignment) }">
                {{ getAssignmentName(assignment) }}: {{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
              </div>
            </div>
            <div v-else class="assignments-list">
              <div class="assignment-item" style="background-color: rgba(128, 128, 128, 0.15);">
                Runner
              </div>
            </div>
          </div>
        </div>
        
        <div class="porter-card__actions">
          <button 
            @click="removePorter(entry.id)" 
            class="btn btn--icon btn--danger"
            title="Remove porter from shift"
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 6h18"></path>
              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
            </svg>
          </button>
        </div>
      </div>
    </div>
    
    <!-- Porter Selector Modal -->
    <div v-if="showPorterSelector" class="modal-overlay" @click.self="showPorterSelector = false">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">Add Porters to Shift</h3>
          <button class="modal-close" @click="showPorterSelector = false">&times;</button>
        </div>
        
        <div class="modal-body">
          <div v-if="availablePorters.length === 0" class="empty-state">
            No porters available to add. All porters are already assigned to this shift, are absent, or are assigned to departments in settings.
          </div>
          
          <div v-else class="porter-selector">
            <div class="select-all-container">
              <label class="checkbox-container">
                <input 
                  type="checkbox" 
                  :checked="isAllSelected" 
                  @change="toggleSelectAll"
                >
                <span class="checkmark"></span>
                <span class="select-all-text">Select All Porters</span>
              </label>
              <span v-if="selectedPorters.length > 0" class="selected-count">
                {{ selectedPorters.length }} porter{{ selectedPorters.length > 1 ? 's' : '' }} selected
              </span>
            </div>
            
            <div v-for="porter in availablePorters" :key="porter.id" class="porter-item">
              <label class="checkbox-container">
                <input 
                  type="checkbox" 
                  :value="porter.id" 
                  v-model="selectedPorters"
                >
                <span class="checkmark"></span>
              </label>
              <div class="porter-name">{{ porter.first_name }} {{ porter.last_name }}</div>
            </div>
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            class="btn btn--secondary" 
            @click="showPorterSelector = false"
          >
            Cancel
          </button>
          <button 
            class="btn btn--primary" 
            @click="addSelectedPorters"
            :disabled="selectedPorters.length === 0 || addingPorters"
          >
            {{ addingPorters ? 'Adding...' : 'Add Selected Porters' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useAreaCoverStore } from '../stores/areaCoverStore';

const props = defineProps({
  shiftId: {
    type: String,
    required: true
  }
});

const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const areaCoverStore = useAreaCoverStore();

const showPorterSelector = ref(false);

// Expose showPorterSelector method to parent
const openPorterSelector = () => {
  showPorterSelector.value = true;
};

// Expose necessary methods to parent
defineExpose({
  openPorterSelector
});
const selectedPorters = ref([]);
const addingPorters = ref(false);
const isLoading = ref(true);

// Computed properties
const porterPool = computed(() => {
  return shiftsStore.shiftPorterPool || [];
});

// Sorted porter pool with Runners first, then assigned porters
const sortedPorterPool = computed(() => {
  if (!porterPool.value.length) return [];
  
  return [...porterPool.value].sort((a, b) => {
    const aAssignments = getPorterAssignments(a.porter_id).length;
    const bAssignments = getPorterAssignments(b.porter_id).length;
    
    // If a is a Runner (0 assignments) and b is not, a comes first
    if (aAssignments === 0 && bAssignments > 0) return -1;
    // If b is a Runner and a is not, b comes first
    if (bAssignments === 0 && aAssignments > 0) return 1;
    // Otherwise keep original order
    return 0;
  });
});

const availablePorters = computed(() => {
  // Get all porters
  const allPorters = staffStore.porters || [];
  
  // Get porters already in the pool
  const poolPorterIds = porterPool.value.map(p => p.porter_id);
  
  // Get porters assigned to departments in settings
  // Get assignments for all shift types
  const weekDayAssignments = areaCoverStore.getAssignmentsByShiftType('week_day') || [];
  const weekNightAssignments = areaCoverStore.getAssignmentsByShiftType('week_night') || [];
  const weekendDayAssignments = areaCoverStore.getAssignmentsByShiftType('weekend_day') || [];
  const weekendNightAssignments = areaCoverStore.getAssignmentsByShiftType('weekend_night') || [];
  
  // Get all porter assignments
  const departmentPorterIds = [];
  
  // Check each area assignment for assigned porters
  for (const assignment of [...weekDayAssignments, ...weekNightAssignments, 
                            ...weekendDayAssignments, ...weekendNightAssignments]) {
    // Get porter assignments for this area assignment
    const porterAssignments = areaCoverStore.getPorterAssignmentsByAreaId(assignment.id) || [];
    // Add porter IDs to the list
    for (const pa of porterAssignments) {
      if (pa.porter_id) {
        departmentPorterIds.push(pa.porter_id);
      }
    }
  }
  
  // Get porters already assigned to departments in THIS shift
  const shiftDepartmentPorterIds = shiftsStore.shiftAreaCoverPorterAssignments
    .map(a => a.porter_id);
    
  // Get porters already assigned to services in THIS shift
  const shiftServicePorterIds = shiftsStore.shiftSupportServicePorterAssignments
    .map(a => a.porter_id);
  
  // Combine all excluded porter IDs
  const excludedPorterIds = [...new Set([...poolPorterIds, ...departmentPorterIds, ...shiftDepartmentPorterIds, ...shiftServicePorterIds])];
  
  // Filter out porters who are absent
  const today = new Date();
  return allPorters.filter(p => {
    // First check if porter is in excluded list
    if (excludedPorterIds.includes(p.id)) {
      return false;
    }
    
    // Then check if porter is absent
    if (staffStore.isPorterAbsent(p.id, today)) {
      return false;
    }
    
    return true;
  });
});

// Check if all porters are selected
const isAllSelected = computed(() => {
  return availablePorters.value.length > 0 && 
         selectedPorters.value.length === availablePorters.value.length;
});

// Check if a porter is absent
const isPorterAbsent = (porterId) => {
  const today = new Date();
  return staffStore.isPorterAbsent(porterId, today);
};

// Get the absence type for a porter (illness or annual_leave)
const getPorterAbsenceType = (porterId) => {
  const today = new Date();
  const absence = staffStore.getPorterAbsenceDetails(porterId, today);
  return absence ? absence.absence_type : null;
};

// Methods
const addPorter = async (porterId) => {
  await shiftsStore.addPorterToShift(props.shiftId, porterId);
  showPorterSelector.value = false;
};

// Add multiple selected porters at once
const addSelectedPorters = async () => {
  if (selectedPorters.value.length === 0 || addingPorters.value) return;
  
  addingPorters.value = true;
  
  try {
    // Process each porter sequentially
    for (const porterId of selectedPorters.value) {
      await shiftsStore.addPorterToShift(props.shiftId, porterId);
    }
    
    // Reset selection and close modal
    selectedPorters.value = [];
    showPorterSelector.value = false;
  } catch (error) {
    console.error('Error adding porters to shift:', error);
  } finally {
    addingPorters.value = false;
  }
};

// Toggle select all porters
const toggleSelectAll = () => {
  if (isAllSelected.value) {
    // Deselect all
    selectedPorters.value = [];
  } else {
    // Select all
    selectedPorters.value = availablePorters.value.map(porter => porter.id);
  }
};

const removePorter = async (porterPoolId) => {
  if (confirm('Are you sure you want to remove this porter from the shift?')) {
    await shiftsStore.removePorterFromShift(porterPoolId);
  }
};

const getPorterAssignments = (porterId) => {
  // Get area cover assignments for this porter in this shift
  const areaCoverAssignments = shiftsStore.shiftAreaCoverPorterAssignments.filter(
    a => a.porter_id === porterId
  );
  
  // Get service assignments for this porter in this shift
  const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments.filter(
    a => a.porter_id === porterId
  );
  
  // Return both types of assignments
  return [...areaCoverAssignments, ...serviceAssignments];
};

// Get the background color for an assignment item
const getAssignmentBackgroundColor = (assignment) => {
  // Check if this is an area cover assignment or service assignment
  if (assignment.shift_area_cover_assignment_id) {
    // Area cover assignment
    const color = assignment.shift_area_cover_assignment?.color || '#4285F4';
    return `${color}25`; // 25 is hex for 15% opacity
  } else if (assignment.shift_support_service_assignment_id) {
    // Service assignment
    // Get the service assignment from the store
    const serviceAssignment = shiftsStore.shiftSupportServiceAssignments.find(
      s => s.id === assignment.shift_support_service_assignment_id
    );
    const color = serviceAssignment?.color || '#4285F4';
    return `${color}25`; // 25 is hex for 15% opacity
  }
  
  // Default color
  return 'rgba(66, 133, 244, 0.15)'; // Light blue
};

// Format time (e.g., "09:30") in 24-hour format
// Get the assignment name (department or service)
const getAssignmentName = (assignment) => {
  // Check if this is an area cover assignment
  if (assignment.shift_area_cover_assignment_id) {
    // Area cover assignment - return department name
    return assignment.shift_area_cover_assignment?.department?.name || 'Unknown Department';
  } else if (assignment.shift_support_service_assignment_id) {
    // Service assignment - find the service assignment
    const serviceAssignment = shiftsStore.shiftSupportServiceAssignments.find(
      s => s.id === assignment.shift_support_service_assignment_id
    );
    // Return the service name
    return serviceAssignment?.service?.name || 'Unknown Service';
  }
  
  // Default
  return 'Unknown Assignment';
};

const formatTime = (timeStr) => {
  if (!timeStr) return '';
  
  // Convert "HH:MM:SS" to "HH:MM" in 24-hour format
  const [hours, minutes] = timeStr.split(':');
  const hoursNum = parseInt(hours, 10);
  
  // Format with leading zeros for consistency
  return `${String(hoursNum).padStart(2, '0')}:${minutes}`;
};

// Reset selected porters when modal is closed
watch(showPorterSelector, (isOpen) => {
  if (!isOpen) {
    selectedPorters.value = [];
  }
});

// Lifecycle hooks
onMounted(async () => {
  isLoading.value = true;
  
  try {
    // Load data in sequence
    await shiftsStore.fetchShiftPorterPool(props.shiftId);
    
    if (!staffStore.porters.length) {
      await staffStore.fetchPorters();
    }
    
    // Initialize area cover store if needed
    await areaCoverStore.initialize();
    
    // Ensure area cover assignments load last
    await shiftsStore.fetchShiftAreaCover(props.shiftId);
  } catch (error) {
    console.error('Error loading shift data:', error);
  } finally {
    // Delay slightly to ensure computed values update
    setTimeout(() => {
      isLoading.value = false;
    }, 300);
  }
});
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../assets/scss/mixins' as mix;

.shift-porter-pool {
  position: relative;
}

.loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(255, 255, 255, 0.8);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  z-index: 10;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid rgba(0, 0, 0, 0.1);
  border-radius: 50%;
  border-top-color: #4285F4;
  animation: spin 1s ease-in-out infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading-text {
  font-size: 1rem;
  color: #333;
}

.shift-porter-pool {
  &__header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }
}

.section-title {
  font-size: 1.25rem;
  font-weight: 600;
  margin: 0;
}

.loading, .empty-state {
  padding: 24px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
}

.porter-grid {
  display: grid;
  grid-template-columns: 1fr; /* Default: single column for mobile */
  gap: 16px;
  
  @media (min-width: 700px) {
    grid-template-columns: repeat(2, 1fr); /* 2 columns from 700px to 960px */
  }
  
  @media (min-width: 961px) {
    grid-template-columns: repeat(3, 1fr); /* 3 columns from 961px and up */
  }
}

.porter-card {
  display: flex;
  justify-content: space-between;
  padding: 12px 16px;
  background-color: white;
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  
  &.assigned {
    background-color: #FFF8ED;  /* Extremely pale orange background */
    border: 1px solid rgba(0, 0, 0, 0.15);
  }
  
  &__content {
    flex: 1;
  }
  
  &__name {
    font-size: 0.85rem;
    font-weight: 600;
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    gap: 8px;
    
    &.assigned {
      color: rgba(0, 0, 0, 0.4); /* Lighter gray for assigned porters */
    }
    
    // Absence styling
    &.porter-absent {
      opacity: 0.9;
    }
    
    &.porter-illness {
      color: #d32f2f;
      background-color: rgba(234, 67, 53, 0.1);
      padding: 2px 8px;
      border-radius: 4px;
    }
    
    &.porter-annual-leave {
      color: #f57c00;
      background-color: rgba(251, 192, 45, 0.1);
      padding: 2px 8px;
      border-radius: 4px;
    }
    
    .absence-badge {
      display: inline-block;
      font-size: 9px;
      font-weight: 700;
      padding: 2px 4px;
      border-radius: 3px;
      margin-left: 5px;
      
      &.illness {
        background-color: #d32f2f;
        color: white;
      }
      
      &.annual-leave {
        background-color: #f57c00;
        color: white;
      }
    }
  }
  
  &__assignments {
    font-size: 0.8rem;
    color: rgba(0, 0, 0, 0.6);
    
    .assignments-list {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    
    .assignment-item {
      background-color: rgba(66, 133, 244, 0.1);
      padding: 2px 8px;
      border-radius: 4px;
      display: inline-block;
    }
    
    .no-assignments {
      font-style: italic;
    }
  }
  
  &__actions {
    display: flex;
    align-items: flex-start;
  }
}

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
  border-radius: 8px;
  width: 90%;
  max-width: 500px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  overflow: hidden;
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
  font-size: 1.25rem;
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

.porter-selector {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.select-all-container {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 12px;
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: 6px;
  margin-bottom: 8px;
  
  .select-all-text {
    font-weight: 500;
    margin-left: 8px;
  }
  
  .selected-count {
    font-size: 0.9rem;
    color: #4285F4;
    font-weight: 500;
    padding: 2px 8px;
    background-color: rgba(66, 133, 244, 0.1);
    border-radius: 100px;
  }
}

.porter-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 6px;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.02);
  }
  
  .porter-name {
    margin-left: 8px;
  }
}

/* Checkbox styling */
.checkbox-container {
  display: flex;
  align-items: center;
  position: relative;
  cursor: pointer;
  user-select: none;
  
  input {
    position: absolute;
    opacity: 0;
    cursor: pointer;
    height: 0;
    width: 0;
  }
  
  .checkmark {
    position: relative;
    height: 20px;
    width: 20px;
    background-color: #fff;
    border: 2px solid #ccc;
    border-radius: 4px;
    transition: all 0.2s;
    
    &:after {
      content: "";
      position: absolute;
      display: none;
      left: 6px;
      top: 2px;
      width: 5px;
      height: 10px;
      border: solid white;
      border-width: 0 2px 2px 0;
      transform: rotate(45deg);
    }
  }
  
  input:checked ~ .checkmark {
    background-color: #4285F4;
    border-color: #4285F4;
  }
  
  input:checked ~ .checkmark:after {
    display: block;
  }
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: #4285F4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#4285F4, $lightness: -10%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: #333;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#f1f1f1, $lightness: -5%);
    }
  }
  
  &--danger {
    color: #EA4335;
    
    &:hover:not(:disabled) {
      background-color: rgba(234, 67, 53, 0.1);
    }
  }
  
  &--small {
    padding: 4px 10px;
    font-size: 0.9rem;
  }
  
  &--icon {
    padding: 6px;
    background: transparent;
    
    .icon {
      font-size: 16px;
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
