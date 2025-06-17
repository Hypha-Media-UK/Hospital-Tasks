<template>
  <div class="modal-overlay" @click.self="closeModal">
    <div class="modal-container">
      <div class="modal-header">
        <h3 class="modal-title">Allocate Porter</h3>
        <button class="modal-close" @click="closeModal">&times;</button>
      </div>
      
      <div class="modal-body">
        <div v-if="porter" class="porter-info">
          <div class="porter-name">{{ porter.first_name }} {{ porter.last_name }}</div>
        </div>
        
        <div class="allocation-form">
          <div class="allocation-type">
            <div class="form-group">
              <label>Allocation Type</label>
              <div class="btn-group">
                <button 
                  @click="allocationType = 'department'" 
                  :class="{ active: allocationType === 'department' }" 
                  class="btn btn-toggle"
                >
                  Department
                </button>
                <button 
                  @click="allocationType = 'service'" 
                  :class="{ active: allocationType === 'service' }" 
                  class="btn btn-toggle"
                >
                  Service
                </button>
                <button 
                  @click="allocationType = 'absence'" 
                  :class="{ active: allocationType === 'absence' }" 
                  class="btn btn-toggle"
                >
                  Absence
                </button>
              </div>
            </div>
          </div>
          
          <!-- Department Selection (shown if allocationType is 'department') -->
          <div v-if="allocationType === 'department'" class="form-group">
            <label for="departmentSelect">Department</label>
            <select 
              id="departmentSelect" 
              v-model="selectedDepartmentId" 
              class="form-control"
              required
            >
              <option value="">Select Department</option>
              <option 
                v-for="assignment in departmentAssignments" 
                :key="assignment.id"
                :value="assignment.id"
              >
                {{ assignment.department.name }} ({{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }})
              </option>
            </select>
          </div>
          
          <!-- Service Selection (shown if allocationType is 'service') -->
          <div v-if="allocationType === 'service'" class="form-group">
            <label for="serviceSelect">Service</label>
            <select 
              id="serviceSelect" 
              v-model="selectedServiceId" 
              class="form-control"
              required
            >
              <option value="">Select Service</option>
              <option 
                v-for="assignment in serviceAssignments" 
                :key="assignment.id"
                :value="assignment.id"
              >
                {{ assignment.service.name }} ({{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }})
              </option>
            </select>
          </div>
          
          <!-- Absence Reason (shown if allocationType is 'absence') -->
          <div v-if="allocationType === 'absence'" class="form-group">
            <label for="absenceReason">Absence Reason</label>
            <input 
              type="text" 
              id="absenceReason" 
              v-model="absenceReason" 
              class="form-control"
              placeholder="E.g., Break, Training, Meeting"
              required
            />
          </div>
          
          <!-- Time fields -->
          <div class="form-row">
            <div class="form-group">
              <label for="startTime">Start Time</label>
              <input 
                type="time" 
                id="startTime" 
                v-model="startTime" 
                class="form-control"
                required
              />
            </div>
            
            <div class="form-group">
              <label for="endTime">End Time</label>
              <input 
                type="time" 
                id="endTime" 
                v-model="endTime" 
                class="form-control"
                required
              />
            </div>
          </div>
          
          <!-- Future allocation notice -->
          <div v-if="isFutureAllocation" class="future-allocation-notice">
            <p>
              <strong>Note:</strong> This allocation will start at {{ formattedStartTime }}. 
              The porter will remain in the pool until this time.
            </p>
          </div>

          <!-- Error message -->
          <div v-if="errorMessage" class="error-message">
            {{ errorMessage }}
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <button @click="closeModal" class="btn btn-secondary">Cancel</button>
        <button 
          @click="allocatePorter" 
          class="btn btn-primary" 
          :disabled="!isFormValid || allocating"
        >
          {{ allocating ? 'Allocating...' : 'Allocate Porter' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useShiftsStore } from '../stores/shiftsStore';

const props = defineProps({
  porter: {
    type: Object,
    required: true
  },
  shiftId: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['close', 'allocated']);

const shiftsStore = useShiftsStore();

// Form state
const allocationType = ref('department'); // 'department', 'service', or 'absence'
const selectedDepartmentId = ref('');
const selectedServiceId = ref('');
const absenceReason = ref('');
const startTime = ref('');
const endTime = ref('');
const errorMessage = ref('');
const allocating = ref(false);

// Get department assignments from the store
const departmentAssignments = computed(() => {
  return shiftsStore.shiftAreaCoverAssignments || [];
});

// Get service assignments from the store
const serviceAssignments = computed(() => {
  return shiftsStore.shiftSupportServiceAssignments || [];
});

// Check if this would be a future allocation
const isFutureAllocation = computed(() => {
  if (!startTime.value) return false;
  
  const now = new Date();
  const currentHours = now.getHours();
  const currentMinutes = now.getMinutes();
  const currentTimeInMinutes = (currentHours * 60) + currentMinutes;
  
  // Convert start time to minutes for comparison
  const [startHours, startMinutes] = startTime.value.split(':').map(Number);
  const startTimeInMinutes = (startHours * 60) + startMinutes;
  
  // It's a future allocation if the start time is after the current time
  return startTimeInMinutes > currentTimeInMinutes;
});

// Formatted start time for display
const formattedStartTime = computed(() => {
  if (!startTime.value) return '';
  
  const [hours, minutes] = startTime.value.split(':').map(Number);
  
  // Format with AM/PM
  const period = hours >= 12 ? 'PM' : 'AM';
  const hours12 = hours % 12 || 12; // Convert 0 to 12 for 12 AM
  
  return `${hours12}:${minutes.toString().padStart(2, '0')} ${period}`;
});

// Validate the form
const isFormValid = computed(() => {
  // Clear any previous error message
  errorMessage.value = '';
  
  if (allocationType.value === 'department' && !selectedDepartmentId.value) {
    return false;
  }
  
  if (allocationType.value === 'service' && !selectedServiceId.value) {
    return false;
  }
  
  if (allocationType.value === 'absence' && !absenceReason.value) {
    return false;
  }
  
  if (!startTime.value || !endTime.value) {
    return false;
  }
  
  // Check if end time is after start time
  const [startHours, startMinutes] = startTime.value.split(':').map(Number);
  const [endHours, endMinutes] = endTime.value.split(':').map(Number);
  
  const startInMinutes = (startHours * 60) + startMinutes;
  const endInMinutes = (endHours * 60) + endMinutes;
  
  if (endInMinutes <= startInMinutes) {
    errorMessage.value = 'End time must be after start time';
    return false;
  }
  
  return true;
});

// Format time for display
function formatTime(timeStr) {
  if (!timeStr) return '';
  return timeStr.substring(0, 5); // Extract HH:MM part
}

// Set default start/end times based on the selected department/service
watch([selectedDepartmentId, selectedServiceId], ([newDepartmentId, newServiceId]) => {
  // Set default times based on the selected allocation
  if (allocationType.value === 'department' && newDepartmentId) {
    const assignment = departmentAssignments.value.find(a => a.id === newDepartmentId);
    if (assignment) {
      startTime.value = formatTime(assignment.start_time);
      endTime.value = formatTime(assignment.end_time);
    }
  } else if (allocationType.value === 'service' && newServiceId) {
    const assignment = serviceAssignments.value.find(a => a.id === newServiceId);
    if (assignment) {
      startTime.value = formatTime(assignment.start_time);
      endTime.value = formatTime(assignment.end_time);
    }
  }
});

// Reset selections when allocation type changes
watch(allocationType, () => {
  selectedDepartmentId.value = '';
  selectedServiceId.value = '';
  absenceReason.value = '';
  
  // Only reset time fields if not switching to absence
  if (allocationType.value !== 'absence') {
    startTime.value = '';
    endTime.value = '';
  }
});

// Allocate porter to the selected department/service
async function allocatePorter() {
  if (!isFormValid.value || allocating.value) return;
  
  allocating.value = true;
  errorMessage.value = '';
  
  try {
    let result;
    
    if (allocationType.value === 'department') {
      // Allocate to department
      result = await shiftsStore.allocatePorterToDepartment({
        porterId: props.porter.id,
        shiftId: props.shiftId,
        departmentAssignmentId: selectedDepartmentId.value,
        startTime: startTime.value,
        endTime: endTime.value
      });
      
      if (result) {
        emit('allocated', { 
          type: 'department', 
          departmentId: selectedDepartmentId.value,
          startTime: startTime.value,
          endTime: endTime.value,
          isFuture: isFutureAllocation.value
        });
        closeModal();
      } else {
        errorMessage.value = 'Failed to allocate porter to department';
      }
    } else if (allocationType.value === 'service') {
      // Allocate to service
      result = await shiftsStore.allocatePorterToService({
        porterId: props.porter.id,
        shiftId: props.shiftId,
        serviceAssignmentId: selectedServiceId.value,
        startTime: startTime.value,
        endTime: endTime.value
      });
      
      if (result) {
        emit('allocated', { 
          type: 'service', 
          serviceId: selectedServiceId.value,
          startTime: startTime.value,
          endTime: endTime.value,
          isFuture: isFutureAllocation.value
        });
        closeModal();
      } else {
        errorMessage.value = 'Failed to allocate porter to service';
      }
    } else {
      // Allocate to absence
      result = await shiftsStore.addPorterAbsence(
        props.shiftId,
        props.porter.id,
        startTime.value,
        endTime.value,
        absenceReason.value
      );
      
      if (result) {
        emit('allocated', { 
          type: 'absence', 
          absenceId: result.id,
          startTime: startTime.value,
          endTime: endTime.value,
          reason: absenceReason.value,
          isFuture: isFutureAllocation.value
        });
        closeModal();
      } else {
        errorMessage.value = 'Failed to add porter absence';
      }
    }
  } catch (error) {
    console.error('Error allocating porter:', error);
    errorMessage.value = error.message || 'An error occurred while allocating the porter';
  } finally {
    allocating.value = false;
  }
}

// Close modal
function closeModal() {
  emit('close');
}

// Initialize component
onMounted(() => {
  // Set default time to current time
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  
  startTime.value = `${hours}:${minutes}`;
  
  // End time = current time + 1 hour
  const endDate = new Date(now.getTime() + (60 * 60 * 1000));
  const endHours = String(endDate.getHours()).padStart(2, '0');
  const endMinutes = String(endDate.getMinutes()).padStart(2, '0');
  
  endTime.value = `${endHours}:${endMinutes}`;
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
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.modal-header {
  padding: 16px;
  border-bottom: 1px solid #e0e0e0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-title {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}

.modal-close {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: #666;
  
  &:hover {
    color: #333;
  }
}

.modal-body {
  padding: 16px;
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid #e0e0e0;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.porter-info {
  margin-bottom: 20px;
  background-color: #f5f5f5;
  padding: 12px;
  border-radius: 6px;
  
  .porter-name {
    font-weight: 600;
    font-size: 1.1rem;
  }
}

.allocation-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.allocation-type {
  margin-bottom: 8px;
}

.form-group {
  margin-bottom: 0;
  
  label {
    display: block;
    margin-bottom: 8px;
    font-weight: 500;
  }
  
  .form-control {
    width: 100%;
    padding: 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 1rem;
  }
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.btn-group {
  display: flex;
  gap: 8px;
  
  .btn-toggle {
    flex: 1;
    background-color: #f5f5f5;
    color: #333;
    border: 1px solid #ccc;
    padding: 8px 12px;
    border-radius: 4px;
    cursor: pointer;
    
    &.active {
      background-color: #4285f4;
      color: white;
      border-color: #4285f4;
    }
  }
}

.btn {
  padding: 8px 16px;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  
  &-primary {
    background-color: #4285f4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#4285f4, 10%);
    }
    
    &:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
  }
  
  &-secondary {
    background-color: #f1f1f1;
    color: #333;
    
    &:hover {
      background-color: darken(#f1f1f1, 5%);
    }
  }
}

.future-allocation-notice {
  background-color: #fff8e1;
  border: 1px solid #ffe082;
  border-radius: 4px;
  padding: 12px;
  font-size: 0.9rem;
  
  p {
    margin: 0;
  }
}

.error-message {
  color: #d32f2f;
  background-color: #ffebee;
  padding: 12px;
  border-radius: 4px;
  margin-top: 12px;
  font-size: 0.9rem;
}
</style>
