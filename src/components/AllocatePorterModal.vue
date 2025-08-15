<template>
  <div class="modal-overlay" @click.self="closeModal">
    <div class="modal-container">
      <div class="modal-header">
        <h3>{{ modalTitle }}</h3>
        <button class="modal-close" @click="closeModal">×</button>
      </div>
      
      <div class="modal-body">
        <div v-if="!porter" class="empty-state">
          No porter selected
        </div>
        
        <div v-else class="porter-allocation">
          <div class="porter-info">
            <div class="porter-name">{{ porter.first_name }} {{ porter.last_name }}</div>
            
            <div v-if="porter.availability_pattern" class="porter-availability">
              {{ porter.availability_pattern }}
              <span v-if="porter.contracted_hours_start && porter.contracted_hours_end">
                ({{ formatTime(porter.contracted_hours_start) }} - {{ formatTime(porter.contracted_hours_end) }})
              </span>
            </div>
          </div>
          
          <div class="allocation-tabs">
            <button 
              :class="{ active: activeTab === 'department' }"
              @click="activeTab = 'department'"
              class="tab-button"
            >
              Department
            </button>
            <button 
              :class="{ active: activeTab === 'service' }"
              @click="activeTab = 'service'"
              class="tab-button"
            >
              Service
            </button>
            <button 
              :class="{ active: activeTab === 'absence' }"
              @click="activeTab = 'absence'"
              class="tab-button"
            >
              Absence
            </button>
          </div>
          
          <!-- Conflict Error Display -->
          <div v-if="conflictError" class="conflict-error">
            <div class="error-message">
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="15" y1="9" x2="9" y2="15"></line>
                <line x1="9" y1="9" x2="15" y2="15"></line>
              </svg>
              {{ conflictError }}
            </div>
          </div>
          
          <div class="tab-content">
            <!-- Department Tab -->
            <div v-if="activeTab === 'department'" class="tab-pane">
              <div class="form-group">
                <label for="departmentSelect">Department</label>
                <select 
                  id="departmentSelect" 
                  v-model="departmentId"
                  class="form-control"
                  :disabled="processing"
                >
                  <option value="">Select department</option>
                  <option v-for="dept in availableDepartments" :key="dept.id" :value="dept.id">
                    {{ dept.name }}
                  </option>
                </select>
              </div>
              
              <div class="time-fields">
                <div class="form-group">
                  <label for="departmentStartTime">Start Time</label>
                  <input 
                    type="time" 
                    id="departmentStartTime" 
                    v-model="departmentStartTime"
                    class="form-control"
                    :disabled="processing"
                  />
                </div>
                <div class="form-group">
                  <label for="departmentEndTime">End Time</label>
                  <input 
                    type="time" 
                    id="departmentEndTime" 
                    v-model="departmentEndTime"
                    class="form-control"
                    :disabled="processing"
                  />
                </div>
              </div>
            </div>
            
            <!-- Service Tab -->
            <div v-if="activeTab === 'service'" class="tab-pane">
              <div class="form-group">
                <label for="serviceSelect">Service</label>
                <select 
                  id="serviceSelect" 
                  v-model="serviceId"
                  class="form-control"
                  :disabled="processing"
                >
                  <option value="">Select service</option>
                  <option v-for="service in availableServices" :key="service.id" :value="service.id">
                    {{ service.name }}
                  </option>
                </select>
              </div>
              
              <div class="time-fields">
                <div class="form-group">
                  <label for="serviceStartTime">Start Time</label>
                  <input 
                    type="time" 
                    id="serviceStartTime" 
                    v-model="serviceStartTime"
                    class="form-control"
                    :disabled="processing"
                  />
                </div>
                <div class="form-group">
                  <label for="serviceEndTime">End Time</label>
                  <input 
                    type="time" 
                    id="serviceEndTime" 
                    v-model="serviceEndTime"
                    class="form-control"
                    :disabled="processing"
                  />
                </div>
              </div>
            </div>
            
            <!-- Absence Tab -->
            <div v-if="activeTab === 'absence'" class="tab-pane">
              <div class="form-group">
                <label for="absenceReason">Absence Reason</label>
                <input 
                  type="text" 
                  id="absenceReason" 
                  v-model="absenceReason"
                  class="form-control"
                  placeholder="e.g., Break, Training, etc."
                  :disabled="processing"
                />
              </div>
              
              <div class="time-fields">
                <div class="form-group">
                  <label for="absenceStartTime">Start Time</label>
                  <input 
                    type="time" 
                    id="absenceStartTime" 
                    v-model="absenceStartTime"
                    class="form-control"
                    :disabled="processing"
                  />
                </div>
                <div class="form-group">
                  <label for="absenceEndTime">End Time</label>
                  <input 
                    type="time" 
                    id="absenceEndTime" 
                    v-model="absenceEndTime"
                    class="form-control"
                    :disabled="processing"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div v-if="porter" class="modal-footer">
        <button @click="closeModal" class="btn btn-secondary" :disabled="processing">
          Cancel
        </button>
        <button @click="allocatePorter" class="btn btn-primary" :disabled="!canAllocate || processing">
          {{ submitButtonText }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useShiftsStore } from '../stores/shiftsStore';
import { useLocationsStore } from '../stores/locationsStore';
import { useSupportServicesStore } from '../stores/supportServicesStore';
import { useSettingsStore } from '../stores/settingsStore';

const props = defineProps({
  porter: {
    type: Object,
    default: null
  },
  shiftId: {
    type: String,
    required: true
  },
  editingAssignment: {
    type: Object,
    default: null
  }
});

const emits = defineEmits(['close', 'allocated']);

// Stores
const shiftsStore = useShiftsStore();
const locationsStore = useLocationsStore();
const supportServicesStore = useSupportServicesStore();
const settingsStore = useSettingsStore();

// State
const activeTab = ref('department');
const processing = ref(false);

// Department allocation
const departmentId = ref('');
const departmentStartTime = ref('');
const departmentEndTime = ref('');

// Service allocation
const serviceId = ref('');
const serviceStartTime = ref('');
const serviceEndTime = ref('');

// Absence allocation
const absenceReason = ref('');
const absenceStartTime = ref('');
const absenceEndTime = ref('');

// Computed properties
const isEditMode = computed(() => {
  return props.editingAssignment !== null;
});

const modalTitle = computed(() => {
  return isEditMode.value ? 'Edit Assignment' : 'Allocate Porter';
});

const submitButtonText = computed(() => {
  if (processing.value) {
    return isEditMode.value ? 'Updating...' : 'Allocating...';
  }
  return isEditMode.value ? 'Update Assignment' : 'Allocate Porter';
});

const availableDepartments = computed(() => {
  // Get all departments with area cover assignments for this shift
  const deptIds = shiftsStore.shiftAreaCoverAssignments.map(a => a.department_id);
  
  // Return only departments that have area cover assignments in this shift
  return locationsStore.departments.filter(dept => deptIds.includes(dept.id));
});

const availableServices = computed(() => {
  // Get all services with assignments for this shift
  const serviceIds = shiftsStore.shiftSupportServiceAssignments.map(a => a.service_id);
  
  // Return only services that have assignments in this shift
  return supportServicesStore.services.filter(service => serviceIds.includes(service.id));
});

const canAllocate = computed(() => {
  if (activeTab.value === 'department') {
    return departmentId.value && departmentStartTime.value && departmentEndTime.value;
  } else if (activeTab.value === 'service') {
    return serviceId.value && serviceStartTime.value && serviceEndTime.value;
  } else if (activeTab.value === 'absence') {
    return absenceStartTime.value && absenceEndTime.value; // Reason is optional
  }
  return false;
});

// Initialize time fields with current time as default
const initializeTimeFields = () => {
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const currentTime = `${hours}:${minutes}`;
  
  // Add one hour to get a default end time
  const endDate = new Date(now.getTime() + 60 * 60 * 1000);
  const endHours = String(endDate.getHours()).padStart(2, '0');
  const endMinutes = String(endDate.getMinutes()).padStart(2, '0');
  const endTime = `${endHours}:${endMinutes}`;
  
  // Department times
  departmentStartTime.value = currentTime;
  departmentEndTime.value = endTime;
  
  // Service times
  serviceStartTime.value = currentTime;
  serviceEndTime.value = endTime;
  
  // Absence times
  absenceStartTime.value = currentTime;
  absenceEndTime.value = endTime;
};

// Methods
const closeModal = () => {
  emits('close');
};

// Time conflict detection
const conflictError = ref('');

// Helper function to convert time string (HH:MM) to minutes
const timeToMinutes = (timeStr) => {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
};

// Check for time conflicts with existing assignments
const checkTimeConflicts = (startTime, endTime) => {
  if (!props.porter || !startTime || !endTime) return null;
  
  const startMinutes = timeToMinutes(startTime);
  const endMinutes = timeToMinutes(endTime);
  
  // Get all existing assignments for this porter
  const areaAssignments = shiftsStore.shiftAreaCoverPorterAssignments.filter(
    a => a.porter_id === props.porter.id
  );
  
  const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments.filter(
    a => a.porter_id === props.porter.id
  );
  
  const absenceAssignments = shiftsStore.shiftPorterAbsences.filter(
    a => a.porter_id === props.porter.id
  );
  
  const allAssignments = [...areaAssignments, ...serviceAssignments, ...absenceAssignments];
  
  // Check for overlaps
  for (const assignment of allAssignments) {
    // In edit mode, skip the assignment we're currently editing
    if (isEditMode.value && props.editingAssignment && assignment.id === props.editingAssignment.id) {
      continue;
    }
    
    const assignmentStart = timeToMinutes(assignment.start_time.substring(0, 5));
    const assignmentEnd = timeToMinutes(assignment.end_time.substring(0, 5));
    
    // Check for overlap
    const hasOverlap = (startMinutes < assignmentEnd && endMinutes > assignmentStart);
    
    if (hasOverlap) {
      // Get assignment name for better error message
      let assignmentName = 'Unknown Assignment';
      
      if (assignment.shift_area_cover_assignment_id) {
        const areaCover = shiftsStore.shiftAreaCoverAssignments.find(
          a => a.id === assignment.shift_area_cover_assignment_id
        );
        assignmentName = areaCover?.department?.name || 'Department Assignment';
      } else if (assignment.shift_support_service_assignment_id) {
        const service = shiftsStore.shiftSupportServiceAssignments.find(
          s => s.id === assignment.shift_support_service_assignment_id
        );
        assignmentName = service?.service?.name || 'Service Assignment';
      } else if (assignment.absence_reason) {
        assignmentName = `Absence: ${assignment.absence_reason}`;
      }
      
      return {
        hasConflict: true,
        message: `Porter already assigned to "${assignmentName}" during ${assignment.start_time.substring(0, 5)} - ${assignment.end_time.substring(0, 5)}`,
        conflictingAssignment: assignment
      };
    }
  }
  
  return { hasConflict: false };
};

// Initialize form for edit mode
const initializeEditMode = () => {
  if (!isEditMode.value || !props.editingAssignment) return;
  
  const assignment = props.editingAssignment;
  
  // Determine assignment type and set active tab
  if (assignment.shift_area_cover_assignment_id) {
    // Department assignment
    activeTab.value = 'department';
    
    // Find the department ID from the area cover assignment
    const areaCover = shiftsStore.shiftAreaCoverAssignments.find(
      a => a.id === assignment.shift_area_cover_assignment_id
    );
    if (areaCover) {
      departmentId.value = areaCover.department_id;
    }
    
    // Set times
    departmentStartTime.value = formatTime(assignment.start_time);
    departmentEndTime.value = formatTime(assignment.end_time);
    
  } else if (assignment.shift_support_service_assignment_id) {
    // Service assignment
    activeTab.value = 'service';
    
    // Find the service ID from the service assignment
    const serviceAssignment = shiftsStore.shiftSupportServiceAssignments.find(
      s => s.id === assignment.shift_support_service_assignment_id
    );
    if (serviceAssignment) {
      serviceId.value = serviceAssignment.service_id;
    }
    
    // Set times
    serviceStartTime.value = formatTime(assignment.start_time);
    serviceEndTime.value = formatTime(assignment.end_time);
    
  } else if (assignment.absence_reason !== undefined) {
    // Absence assignment
    activeTab.value = 'absence';
    absenceReason.value = assignment.absence_reason || '';
    
    // Set times
    absenceStartTime.value = formatTime(assignment.start_time);
    absenceEndTime.value = formatTime(assignment.end_time);
  }
};

const allocatePorter = async () => {
  if (!canAllocate.value || !props.porter || processing.value) return;
  
  // Clear any previous conflict errors
  conflictError.value = '';
  
  // Check for time conflicts before proceeding
  let startTime, endTime;
  
  if (activeTab.value === 'department') {
    startTime = departmentStartTime.value;
    endTime = departmentEndTime.value;
  } else if (activeTab.value === 'service') {
    startTime = serviceStartTime.value;
    endTime = serviceEndTime.value;
  } else if (activeTab.value === 'absence') {
    startTime = absenceStartTime.value;
    endTime = absenceEndTime.value;
  }
  
  const conflictCheck = checkTimeConflicts(startTime, endTime);
  
  if (conflictCheck?.hasConflict) {
    conflictError.value = conflictCheck.message;
    return;
  }
  
  processing.value = true;
  
  try {
    let result;
    
    if (isEditMode.value) {
      // Edit mode - update existing assignment
      if (activeTab.value === 'department') {
        // Update area cover porter assignment
        result = await shiftsStore.updateShiftAreaCoverPorter(props.editingAssignment.id, {
          start_time: departmentStartTime.value + ':00',
          end_time: departmentEndTime.value + ':00'
        });
        
        emits('allocated', {
          type: 'department',
          assignment_id: props.editingAssignment.id,
          porter_id: props.porter.id,
          start_time: departmentStartTime.value,
          end_time: departmentEndTime.value,
          isEdit: true
        });
        
      } else if (activeTab.value === 'service') {
        // Update service porter assignment
        result = await shiftsStore.updateShiftSupportServicePorter(props.editingAssignment.id, {
          start_time: serviceStartTime.value + ':00',
          end_time: serviceEndTime.value + ':00'
        });
        
        emits('allocated', {
          type: 'service',
          assignment_id: props.editingAssignment.id,
          porter_id: props.porter.id,
          start_time: serviceStartTime.value,
          end_time: serviceEndTime.value,
          isEdit: true
        });
        
      } else if (activeTab.value === 'absence') {
        // Update absence assignment
        result = await shiftsStore.updatePorterAbsence(props.editingAssignment.id, {
          absence_reason: absenceReason.value,
          start_time: absenceStartTime.value + ':00',
          end_time: absenceEndTime.value + ':00'
        });
        
        emits('allocated', {
          type: 'absence',
          assignment_id: props.editingAssignment.id,
          porter_id: props.porter.id,
          absence_reason: absenceReason.value,
          start_time: absenceStartTime.value,
          end_time: absenceEndTime.value,
          isEdit: true
        });
      }
      
    } else {
      // Create mode - new assignment
      if (activeTab.value === 'department') {
        // Get the area cover assignment for this department
        const areaAssignment = shiftsStore.shiftAreaCoverAssignments.find(
          a => a.department_id === departmentId.value
        );
        
        if (!areaAssignment) {
          throw new Error('Area assignment not found');
        }
        
        // Allocate porter to department
        result = await shiftsStore.assignPorterToShiftAreaCover({
          shift_id: props.shiftId,
          porter_id: props.porter.id,
          shift_area_cover_assignment_id: areaAssignment.id,
          start_time: departmentStartTime.value + ':00', // Add seconds
          end_time: departmentEndTime.value + ':00' // Add seconds
        });
        
        // Emit allocated event with details
        emits('allocated', {
          type: 'department',
          department_id: departmentId.value,
          porter_id: props.porter.id,
          start_time: departmentStartTime.value,
          end_time: departmentEndTime.value
        });
        
      } else if (activeTab.value === 'service') {
        // Get the service assignment for this service
        const serviceAssignment = shiftsStore.shiftSupportServiceAssignments.find(
          a => a.service_id === serviceId.value
        );
        
        if (!serviceAssignment) {
          throw new Error('Service assignment not found');
        }
        
        // Allocate porter to service
        result = await shiftsStore.assignPorterToShiftSupportService({
          shift_id: props.shiftId,
          porter_id: props.porter.id,
          shift_support_service_assignment_id: serviceAssignment.id,
          start_time: serviceStartTime.value + ':00', // Add seconds
          end_time: serviceEndTime.value + ':00' // Add seconds
        });
        
        // Emit allocated event with details
        emits('allocated', {
          type: 'service',
          service_id: serviceId.value,
          porter_id: props.porter.id,
          start_time: serviceStartTime.value,
          end_time: serviceEndTime.value
        });
        
      } else if (activeTab.value === 'absence') {
        // Add scheduled absence for porter
        result = await shiftsStore.addPorterAbsenceToShift({
          shift_id: props.shiftId,
          porter_id: props.porter.id,
          absence_reason: absenceReason.value,
          start_time: absenceStartTime.value + ':00', // Add seconds
          end_time: absenceEndTime.value + ':00' // Add seconds
        });
        
        // Emit allocated event with details
        emits('allocated', {
          type: 'absence',
          porter_id: props.porter.id,
          absence_reason: absenceReason.value,
          start_time: absenceStartTime.value,
          end_time: absenceEndTime.value
        });
      }
    }
    
    // Close modal on success
    closeModal();
  } catch (error) {
    alert(`Failed to ${isEditMode.value ? 'update' : 'allocate'} porter: ` + (error.message || 'Unknown error'));
  } finally {
    processing.value = false;
  }
};

// Format time (HH:MM)
const formatTime = (timeString) => {
  if (!timeString) return '';
  
  // If it's already just HH:MM
  if (timeString.length === 5) return timeString;
  
  // If it has seconds (HH:MM:SS), remove seconds
  if (timeString.length === 8) return timeString.substring(0, 5);
  
  // For any other format, try to parse as date
  try {
    const date = new Date(timeString);
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${hours}:${minutes}`;
  } catch (e) {
    return timeString; // Return original if parsing fails
  }
};

// Clear conflict error when time fields change
watch([departmentStartTime, departmentEndTime], () => {
  if (activeTab.value === 'department') {
    conflictError.value = '';
  }
});

watch([serviceStartTime, serviceEndTime], () => {
  if (activeTab.value === 'service') {
    conflictError.value = '';
  }
});

watch([absenceStartTime, absenceEndTime], () => {
  if (activeTab.value === 'absence') {
    conflictError.value = '';
  }
});

// Reset form when tab changes
watch(activeTab, () => {
  // Clear conflict error when switching tabs
  conflictError.value = '';
});

// Reset form when porter changes
watch(() => props.porter, () => {
  departmentId.value = '';
  serviceId.value = '';
  absenceReason.value = '';
  conflictError.value = '';
  
  // Initialize times again
  if (!isEditMode.value) {
    initializeTimeFields();
  }
});

// Watch for editingAssignment changes to initialize edit mode
watch(() => props.editingAssignment, () => {
  if (isEditMode.value) {
    initializeEditMode();
  } else {
    // Reset form for new allocation
    departmentId.value = '';
    serviceId.value = '';
    absenceReason.value = '';
    conflictError.value = '';
    initializeTimeFields();
  }
}, { immediate: true });

// On component mount
onMounted(() => {
  // Make sure data is loaded
  if (locationsStore.departments.length === 0) {
    locationsStore.fetchDepartments();
  }
  
  if (supportServicesStore.services.length === 0) {
    supportServicesStore.fetchServices();
  }
  
  // Initialize based on mode
  if (isEditMode.value) {
    initializeEditMode();
  } else {
    initializeTimeFields();
  }
});
</script>

<style lang="scss" scoped>
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
  
  h3 {
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
}

.modal-body {
  padding: 16px;
  overflow-y: auto;
  flex: 1;
  
  .empty-state {
    text-align: center;
    padding: 16px 0;
    color: #666;
  }
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.porter-info {
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  
  .porter-name {
    font-size: 1.2rem;
    font-weight: 600;
    margin-bottom: 4px;
  }
  
  .porter-availability {
    font-size: 0.9rem;
    color: #666;
  }
}

.allocation-tabs {
  display: flex;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  margin-bottom: 16px;
  
  .tab-button {
    padding: 8px 16px;
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    font-weight: 500;
    color: #666;
    
    &.active {
      color: #4285F4;
      border-bottom-color: #4285F4;
    }
    
    &:hover:not(.active) {
      background-color: rgba(0, 0, 0, 0.05);
    }
  }
}

.conflict-error {
  margin-bottom: 16px;
  
  .error-message {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px;
    background-color: rgba(234, 67, 53, 0.1);
    border: 1px solid rgba(234, 67, 53, 0.3);
    border-radius: 6px;
    color: #d32f2f;
    font-size: 0.9rem;
    font-weight: 500;
    
    svg {
      flex-shrink: 0;
      color: #d32f2f;
    }
  }
}

.tab-content {
  padding: 8px 0;
}

.form-group {
  margin-bottom: 16px;
  
  label {
    display: block;
    margin-bottom: 6px;
    font-weight: 500;
  }
  
  .form-control {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 1rem;
  }
}

.time-fields {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.btn {
  padding: 8px 16px;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: background-color 0.2s;
  
  &-primary {
    background-color: #4285F4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#4285F4, 10%);
    }
  }
  
  &-secondary {
    background-color: #f1f1f1;
    color: #333;
    
    &:hover:not(:disabled) {
      background-color: darken(#f1f1f1, 5%);
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
