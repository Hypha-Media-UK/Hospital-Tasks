<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container">
      <div class="modal-header">
        <h3 class="modal-title">Allocate Porter</h3>
        <button class="modal-close" @click="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div v-if="loading" class="loading-state">
          Loading departments and services...
        </div>
        
        <div v-else>
          <div class="porter-info">
            <div class="porter-name">{{ porter.first_name }} {{ porter.last_name }}</div>
          </div>
          
          <div class="form-group">
            <label for="allocationType">Allocation Type</label>
            <select id="allocationType" v-model="allocationType" class="form-control">
              <option value="department">Department</option>
              <option value="service">Support Service</option>
            </select>
          </div>
          
          <div v-if="allocationType === 'department'" class="form-group">
            <label for="department">Department</label>
            <select id="department" v-model="selectedDepartmentId" class="form-control">
              <option value="">Select Department</option>
              <option v-for="assignment in areaCoverAssignments" :key="assignment.id" :value="assignment.id">
                {{ assignment.department.name }}
              </option>
            </select>
          </div>
          
          <div v-if="allocationType === 'service'" class="form-group">
            <label for="service">Support Service</label>
            <select id="service" v-model="selectedServiceId" class="form-control">
              <option value="">Select Service</option>
              <option v-for="assignment in supportServiceAssignments" :key="assignment.id" :value="assignment.id">
                {{ assignment.service.name }}
              </option>
            </select>
          </div>
          
          <div class="time-fields">
            <div class="form-group">
              <label for="startTime">Start Time</label>
              <input type="time" id="startTime" v-model="startTime" class="form-control" required>
            </div>
            
            <div class="form-group">
              <label for="endTime">End Time</label>
              <input type="time" id="endTime" v-model="endTime" class="form-control" required>
            </div>
          </div>

          <div class="allocation-info">
            <p v-if="showFutureAllocationInfo" class="info-text">
              This porter will remain in the pool until their allocation time ({{ formatTime(startTime) }}) matches the current time.
            </p>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <button 
          class="btn btn--secondary" 
          @click="$emit('close')"
          :disabled="allocating"
        >
          Cancel
        </button>
        <button 
          class="btn btn--primary" 
          @click="allocatePorter"
          :disabled="!canAllocate || allocating"
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
const allocationType = ref('department');
const selectedDepartmentId = ref('');
const selectedServiceId = ref('');
const startTime = ref('');
const endTime = ref('');
const loading = ref(true);
const allocating = ref(false);

// Get area cover assignments from the store
const areaCoverAssignments = computed(() => {
  return shiftsStore.shiftAreaCoverAssignments || [];
});

// Get support service assignments from the store
const supportServiceAssignments = computed(() => {
  return shiftsStore.shiftSupportServiceAssignments || [];
});

// Calculate if this will be a future allocation
const showFutureAllocationInfo = computed(() => {
  if (!startTime.value) return false;
  
  // Convert form time to minutes for comparison
  const [hours, minutes] = startTime.value.split(':').map(Number);
  const startTimeMinutes = (hours * 60) + minutes;
  
  // Get current time in minutes
  const now = new Date();
  const currentHours = now.getHours();
  const currentMinutes = now.getMinutes();
  const currentTimeMinutes = (currentHours * 60) + currentMinutes;
  
  // Show message if start time is in the future
  return startTimeMinutes > currentTimeMinutes;
});

// Check if we can allocate (all required fields filled)
const canAllocate = computed(() => {
  if (!startTime.value || !endTime.value) return false;
  
  if (allocationType.value === 'department') {
    return !!selectedDepartmentId.value;
  } else if (allocationType.value === 'service') {
    return !!selectedServiceId.value;
  }
  
  return false;
});

// Initialize the component
onMounted(async () => {
  loading.value = true;
  
  try {
    // Ensure we have the shift area cover and service assignments
    if (areaCoverAssignments.value.length === 0) {
      await shiftsStore.fetchShiftAreaCover(props.shiftId);
    }
    
    if (supportServiceAssignments.value.length === 0) {
      await shiftsStore.fetchShiftSupportServices(props.shiftId);
    }
    
    // Set default times (current time to end of shift)
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    startTime.value = `${hours}:${minutes}`;
    
    // Set end time to the end of the first assignment (if any)
    if (areaCoverAssignments.value.length > 0) {
      endTime.value = areaCoverAssignments.value[0].end_time.substring(0, 5); // HH:MM format
    } else if (supportServiceAssignments.value.length > 0) {
      endTime.value = supportServiceAssignments.value[0].end_time.substring(0, 5); // HH:MM format
    } else {
      // Default to end of day if no assignments
      endTime.value = '17:00';
    }
  } catch (error) {
    console.error('Error loading data for porter allocation:', error);
  } finally {
    loading.value = false;
  }
});

// Watch for allocation type changes to reset selection
watch(allocationType, () => {
  selectedDepartmentId.value = '';
  selectedServiceId.value = '';
});

// When department is selected, update times based on department hours
watch(selectedDepartmentId, (newValue) => {
  if (newValue && allocationType.value === 'department') {
    const department = areaCoverAssignments.value.find(a => a.id === newValue);
    if (department) {
      // Only update end time, keeping the user-selected start time
      endTime.value = department.end_time.substring(0, 5); // HH:MM format
    }
  }
});

// When service is selected, update times based on service hours
watch(selectedServiceId, (newValue) => {
  if (newValue && allocationType.value === 'service') {
    const service = supportServiceAssignments.value.find(a => a.id === newValue);
    if (service) {
      // Only update end time, keeping the user-selected start time
      endTime.value = service.end_time.substring(0, 5); // HH:MM format
    }
  }
});

// Format time for display (HH:MM)
const formatTime = (timeStr) => {
  if (!timeStr) return '';
  
  // Check if the string already has the HH:MM format
  if (/^\d{1,2}:\d{2}$/.test(timeStr)) {
    // Extract hours and minutes to ensure proper formatting
    const [hours, minutes] = timeStr.split(':').map(Number);
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  }
  
  return timeStr.substring(0, 5); // Extract HH:MM part from a longer string
};

// Allocate the porter to selected department or service
const allocatePorter = async () => {
  if (!canAllocate.value || allocating.value) return;
  
  allocating.value = true;
  
  try {
    // Format times (ensure HH:MM:SS format for the API)
    const formattedStartTime = `${startTime.value}:00`;
    const formattedEndTime = `${endTime.value}:00`;
    
    let result;
    
    if (allocationType.value === 'department') {
      // Allocate to department
      result = await shiftsStore.addShiftAreaCoverPorter(
        selectedDepartmentId.value,
        props.porter.id,
        formattedStartTime,
        formattedEndTime
      );
    } else if (allocationType.value === 'service') {
      // Allocate to service
      result = await shiftsStore.addShiftSupportServicePorter(
        selectedServiceId.value,
        props.porter.id,
        formattedStartTime,
        formattedEndTime
      );
    }
    
    if (result) {
      // Notify parent that allocation was successful
      emit('allocated', {
        porter: props.porter,
        type: allocationType.value,
        assignmentId: allocationType.value === 'department' ? selectedDepartmentId.value : selectedServiceId.value,
        startTime: formattedStartTime,
        endTime: formattedEndTime
      });
      
      // Close the modal
      emit('close');
    }
  } catch (error) {
    console.error('Error allocating porter:', error);
  } finally {
    allocating.value = false;
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";

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

.loading-state {
  text-align: center;
  padding: 20px;
  color: rgba(0, 0, 0, 0.6);
}

.porter-info {
  margin-bottom: 16px;
  padding: 12px;
  background-color: #f8f9fa;
  border-radius: 6px;
  
  .porter-name {
    font-weight: 600;
    font-size: 1.1rem;
  }
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
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 1rem;
  }
}

.time-fields {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.allocation-info {
  margin-top: 16px;
  
  .info-text {
    background-color: #fff8ed;
    border: 1px solid rgba(251, 192, 45, 0.3);
    color: #f57c00;
    padding: 12px;
    border-radius: 4px;
    font-size: 0.9rem;
    margin: 0;
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
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
