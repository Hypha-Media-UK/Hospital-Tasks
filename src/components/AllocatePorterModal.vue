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
                  <div style="font-size: 10px; color: #666;">
                    departmentStartTime: {{ departmentStartTime }}
                  </div>
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
                  <div style="font-size: 10px; color: #666;">
                    departmentEndTime: {{ departmentEndTime }}
                  </div>
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
  const filtered = locationsStore.departments.filter(dept => deptIds.includes(dept.id));
  return filtered;
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

// Initialize time fields with current time as default using timezone helpers
const initializeTimeFields = () => {
  const now = new Date();
  const currentTime = now.toLocaleTimeString('en-GB', { 
    hour: '2-digit', 
    minute: '2-digit', 
    hour12: false 
  });
  
  // Add one hour to get a default end time
  const endDate = new Date(now.getTime() + 60 * 60 * 1000);
  const endTime = endDate.toLocaleTimeString('en-GB', { 
    hour: '2-digit', 
    minute: '2-digit', 
    hour12: false 
  });
  
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

    if (areaCover && areaCover.department_id) {
      departmentId.value = areaCover.department_id;
    } else {
      // Fallback: try to get department_id from the assignment itself if it exists
      if (assignment.department_id) {
        departmentId.value = assignment.department_id;
      }
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

    if (serviceAssignment && serviceAssignment.service_id) {
      serviceId.value = serviceAssignment.service_id;
    } else {
      // Fallback: try to get service_id from the assignment itself if it exists
      if (assignment.service_id) {
        serviceId.value = assignment.service_id;
      }
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
        // Check if department has changed
        const currentAreaCover = shiftsStore.shiftAreaCoverAssignments.find(
          a => a.id === props.editingAssignment.shift_area_cover_assignment_id
        );
        const departmentChanged = currentAreaCover && currentAreaCover.department_id !== departmentId.value;
        
        if (departmentChanged) {
          // Department changed - need to delete old assignment and create new one
          await shiftsStore.removeShiftAreaCoverPorter(props.editingAssignment.id);
          
          // Get the new area cover assignment for the selected department
          const newAreaAssignment = shiftsStore.shiftAreaCoverAssignments.find(
            a => a.department_id === departmentId.value
          );
          
          if (!newAreaAssignment) {
            throw new Error('New department assignment not found');
          }
          
          // Create new assignment
          result = await shiftsStore.assignPorterToShiftAreaCover({
            shift_id: props.shiftId,
            porter_id: props.porter.id,
            shift_area_cover_assignment_id: newAreaAssignment.id,
            start_time: departmentStartTime.value + ':00',
            end_time: departmentEndTime.value + ':00'
          });
        } else {
          // Only times changed - update existing assignment
          result = await shiftsStore.updateShiftAreaCoverPorter(props.editingAssignment.id, {
            start_time: departmentStartTime.value + ':00',
            end_time: departmentEndTime.value + ':00'
          });
        }
        
        emits('allocated', {
          type: 'department',
          assignment_id: departmentChanged ? result?.id : props.editingAssignment.id,
          porter_id: props.porter.id,
          department_id: departmentId.value,
          start_time: departmentStartTime.value,
          end_time: departmentEndTime.value,
          isEdit: true,
          departmentChanged
        });
        
      } else if (activeTab.value === 'service') {
        // Check if service has changed
        const currentServiceAssignment = shiftsStore.shiftSupportServiceAssignments.find(
          s => s.id === props.editingAssignment.shift_support_service_assignment_id
        );
        const serviceChanged = currentServiceAssignment && currentServiceAssignment.service_id !== serviceId.value;
        
        if (serviceChanged) {
          // Service changed - need to delete old assignment and create new one
          await shiftsStore.removeShiftSupportServicePorter(props.editingAssignment.id);
          
          // Get the new service assignment for the selected service
          const newServiceAssignment = shiftsStore.shiftSupportServiceAssignments.find(
            a => a.service_id === serviceId.value
          );
          
          if (!newServiceAssignment) {
            throw new Error('New service assignment not found');
          }
          
          // Create new assignment
          result = await shiftsStore.assignPorterToShiftSupportService({
            shift_id: props.shiftId,
            porter_id: props.porter.id,
            shift_support_service_assignment_id: newServiceAssignment.id,
            start_time: serviceStartTime.value + ':00',
            end_time: serviceEndTime.value + ':00'
          });
        } else {
          // Only times changed - update existing assignment
          result = await shiftsStore.updateShiftSupportServicePorter(props.editingAssignment.id, {
            start_time: serviceStartTime.value + ':00',
            end_time: serviceEndTime.value + ':00'
          });
        }
        
        emits('allocated', {
          type: 'service',
          assignment_id: serviceChanged ? result?.id : props.editingAssignment.id,
          porter_id: props.porter.id,
          service_id: serviceId.value,
          start_time: serviceStartTime.value,
          end_time: serviceEndTime.value,
          isEdit: true,
          serviceChanged
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

// Format time for display in time inputs (HH:MM format)
const formatTime = (timeString) => {
  if (!timeString) return '';
  
  // If it's already in HH:MM format, return as is
  if (timeString.match(/^\d{2}:\d{2}$/)) {
    return timeString;
  }
  
  // If it's in HH:MM:SS format, extract HH:MM
  if (timeString.match(/^\d{2}:\d{2}:\d{2}$/)) {
    return timeString.substring(0, 5);
  }
  
  // If it's a Date object or timestamp, format it
  try {
    const date = new Date(timeString);
    return date.toLocaleTimeString('en-GB', { 
      hour: '2-digit', 
      minute: '2-digit', 
      hour12: false 
    });
  } catch (error) {
    console.warn('Could not format time:', timeString);
    return '';
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

<!-- Styles are now handled by the global CSS layers -->