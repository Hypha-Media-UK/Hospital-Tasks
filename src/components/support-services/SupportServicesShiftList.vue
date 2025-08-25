<template>
  <div class="support-services-shift-list">
    <!-- Loading state -->
    <div v-if="loading" class="loading-state">
      Loading support services...
    </div>
    
    <!-- Empty state -->
    <div v-else-if="serviceAssignments.length === 0" class="empty-state">
      <p>No support services have been assigned to this shift type.</p>
      <button v-if="showHeader" @click="showAddServiceModal = true" class="btn btn--primary">
        Add Service
      </button>
    </div>
    
    <!-- Service Assignments List -->
    <div v-else>
      <div class="services-list-header" v-if="showHeader">
        <h4>{{ shiftTypeLabel }} Coverage</h4>
        <button @click="showAddServiceModal = true" class="btn btn--primary">
          Add Service
        </button>
      </div>
      
      <div class="card-grid">
        <SupportServiceItem
          v-for="assignment in serviceAssignments"
          :key="assignment.id"
          :assignment="assignment"
          @edit="openEditModal"
          @remove="confirmRemove"
        />
      </div>
    </div>
    
    <!-- Add Service Modal -->
    <BaseModal
      v-if="showAddServiceModal"
      title="Add Support Service"
      :subtitle="`Configure a support service for ${shiftTypeLabel.toLowerCase()} coverage`"
      size="medium"
      @close="showAddServiceModal = false"
    >
      <div v-if="availableServices.length === 0" class="empty-state">
        <h4>No Services Available</h4>
        <p>No available services to add. Create new services in the support services section first.</p>
      </div>
      
      <div v-else class="service-form">
        <div class="service-form__info">
          <p class="info-text">
            Select a support service and configure its coverage times for {{ shiftTypeLabel.toLowerCase() }} shifts.
            {{ isShiftMode ? 'This will apply to the current shift only.' : 'This will set the default configuration for all future shifts.' }}
          </p>
        </div>
        
        <div class="form-section">
          <div class="form-group">
            <label for="service-select" class="form-label">
              <span class="label-text">Support Service</span>
              <span class="label-required">*</span>
            </label>
            <select 
              id="service-select"
              v-model="addServiceForm.serviceId"
              class="form-control"
              required
              :aria-describedby="availableServices.length === 0 ? 'service-help' : undefined"
            >
              <option value="">Choose a support service...</option>
              <option 
                v-for="service in availableServices" 
                :key="service.id"
                :value="service.id"
              >
                {{ service.name }}
              </option>
            </select>
          </div>
          
          <div class="form-row">
            <div class="form-group">
              <label for="start-time" class="form-label">
                <span class="label-text">Start Time</span>
                <span class="label-required">*</span>
              </label>
              <input 
                type="time"
                id="start-time"
                v-model="addServiceForm.startTime"
                class="form-control"
                required
              />
            </div>
            
            <div class="form-group">
              <label for="end-time" class="form-label">
                <span class="label-text">End Time</span>
                <span class="label-required">*</span>
              </label>
              <input 
                type="time"
                id="end-time"
                v-model="addServiceForm.endTime"
                class="form-control"
                required
              />
            </div>
          </div>
          
          <!-- Only show color selection in settings mode, not in shift mode -->
          <div class="form-group" v-if="!isShiftMode">
            <label for="color" class="form-label">
              <span class="label-text">Display Color</span>
            </label>
            <div class="color-input-wrapper">
              <input 
                type="color"
                id="color"
                v-model="addServiceForm.color"
                class="form-control color-input"
              />
              <span class="color-preview" :style="{ backgroundColor: addServiceForm.color }"></span>
            </div>
          </div>
        </div>
      </div>
      
      <template #footer>
        <button 
          @click="addService" 
          class="btn btn--primary"
          :disabled="!canAddService || isSubmitting"
        >
          {{ isSubmitting ? 'Adding...' : 'Add Service' }}
        </button>
        <button 
          @click="showAddServiceModal = false" 
          class="btn btn--secondary"
          :disabled="isSubmitting"
        >
          Cancel
        </button>
      </template>
    </BaseModal>
    
    <!-- Edit Service Modal -->
    <EditServiceModal
      v-if="showEditModal && selectedAssignment"
      :assignment="selectedAssignment"
      @close="showEditModal = false"
      @update="updateAssignment"
      @remove="confirmRemove"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useShiftsStore } from '../../stores/shiftsStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';
import { useStaffStore } from '../../stores/staffStore';
import { useSettingsStore } from '../../stores/settingsStore';
import SupportServiceItem from './SupportServiceItem.vue';
import EditServiceModal from './EditServiceModal.vue';
import BaseModal from '../shared/BaseModal.vue';

// Props
const props = defineProps({
  shiftId: {
    type: String,
    required: false,
    default: null
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

// Store references
const shiftsStore = useShiftsStore();
const supportServicesStore = useSupportServicesStore();
const staffStore = useStaffStore();
const settingsStore = useSettingsStore();

// Determine whether we're in shift mode or settings mode
const isShiftMode = computed(() => !!props.shiftId);

// Local state
const showAddServiceModal = ref(false);
const showEditModal = ref(false);
const selectedAssignment = ref(null);
const isSubmitting = ref(false);

// Expose method to open modal
const openAddServiceModal = () => {
  showAddServiceModal.value = true;
};

// Expose necessary methods
defineExpose({
  openAddServiceModal
});
const addServiceForm = ref({
  serviceId: '',
  startTime: '',
  endTime: '',
  color: '#4285F4'
});

// Computed properties
const loading = computed(() => {
  // If we're in shift mode, use the shiftsStore loading state
  if (isShiftMode.value) {
    return shiftsStore.loading.supportServices;
  }
  // Otherwise, use the supportServicesStore loading state
  return supportServicesStore.loading.services;
});

const serviceAssignments = computed(() => {
  // If we're in shift mode, use shift-specific assignments
  if (isShiftMode.value) {
    return shiftsStore.shiftSupportServiceAssignments.filter(
      assignment => assignment.shift_id === props.shiftId
    );
  }
  
  // Otherwise, use default assignments for the specified shift type
  return supportServicesStore.getSortedAssignmentsByType(props.shiftType) || [];
});

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

const availableServices = computed(() => {
  // Get all services with null check
  const allServices = supportServicesStore.services || [];
  
  // Get ids of services already assigned with proper null checks
  const assignedServiceIds = serviceAssignments.value
    .map(a => {
      if (isShiftMode.value) {
        return a?.service_id;
      } else {
        return a?.service?.id || a?.support_services?.id;
      }
    })
    .filter(id => id !== undefined && id !== null);
  
  // Return only services not already assigned with proper null checks
  return allServices.filter(service => 
    service && 
    service.id && 
    !assignedServiceIds.includes(service.id) && 
    service.is_active !== false
  );
});

const canAddService = computed(() => 
  addServiceForm.value.serviceId && 
  addServiceForm.value.startTime && 
  addServiceForm.value.endTime
);

// Load data when component mounts
onMounted(async () => {

  // Make sure we have all support services loaded
  if (!supportServicesStore.services || !supportServicesStore.services.length) {
    await supportServicesStore.fetchServices();
  }
  
  // Make sure porters are loaded
  if (!staffStore.porters.length) {
    await staffStore.fetchPorters();
  }
  
  try {
    if (isShiftMode.value) {
      // If in shift mode, load support service assignments for this shift
      await shiftsStore.fetchShiftSupportServices(props.shiftId);
      
      // Log the loaded assignments to check if everything is correctly loaded
      
      // Check if this is a new shift without assignments yet
      const existingAssignments = shiftsStore.shiftSupportServiceAssignments.filter(a => a.shift_id === props.shiftId);
      if (existingAssignments.length === 0) {
        
        // If this is a new shift, we need to initialize the support services from defaults
        await shiftsStore.setupShiftSupportServicesFromDefaults(props.shiftId, props.shiftType);
        
        // Verify it worked by refetching
        await shiftsStore.fetchShiftSupportServices(props.shiftId);
      }

      // Check porter assignments for each service
      if (serviceAssignments.value.length > 0) {
        serviceAssignments.value.forEach(assignment => {
          const porterAssignments = shiftsStore.getPorterAssignmentsByServiceId(assignment.id);
          
          // Check if service has coverage gaps
          const gaps = shiftsStore.getServiceCoverageGaps(assignment.id);
        });
      }
    } else {
      // Otherwise, load default assignments for this shift type
      await supportServicesStore.ensureAssignmentsLoaded(props.shiftType);
    }
  } catch (error) {
  }
  
  // Set default times based on shift type
  initializeFormDefaults();
});

// Methods
function extractTimeString(timeValue) {
  if (!timeValue) return null;
  
  // If it's already a simple time string (HH:MM), return it
  if (typeof timeValue === 'string' && timeValue.match(/^\d{2}:\d{2}$/)) {
    return timeValue;
  }
  
  // If it's a Date object, extract time
  if (timeValue instanceof Date) {
    return timeValue.toTimeString().substring(0, 5);
  }
  
  // If it's an ISO string (e.g., "1970-01-01T08:00:00.000Z"), extract time
  if (typeof timeValue === 'string' && timeValue.includes('T')) {
    const date = new Date(timeValue);
    return date.toTimeString().substring(0, 5);
  }
  
  // If it's a time string with seconds (HH:MM:SS), extract HH:MM
  if (typeof timeValue === 'string' && timeValue.match(/^\d{2}:\d{2}:\d{2}/)) {
    return timeValue.substring(0, 5);
  }
  
  // If it's a string that starts with "1970-" (our backend format), extract time
  if (typeof timeValue === 'string' && timeValue.startsWith('1970-')) {
    try {
      const date = new Date(timeValue);
      return date.toTimeString().substring(0, 5);
    } catch (e) {
      return null;
    }
  }
  
  // Fallback: try to extract using slice if it's a string
  if (typeof timeValue === 'string' && timeValue.length >= 5) {
    const extracted = timeValue.slice(0, 5);
    // Validate it's a proper time format
    if (extracted.match(/^\d{2}:\d{2}$/)) {
      return extracted;
    }
  }
  
  return null;
}

function initializeFormDefaults() {
  // Set default times based on the specific shift type
  const shiftDefaults = settingsStore.shiftDefaultsByType;
  
  if (props.shiftType === 'week_day') {
    const weekDay = shiftDefaults.week_day;
    addServiceForm.value.startTime = extractTimeString(weekDay?.start_time) || '08:00';
    addServiceForm.value.endTime = extractTimeString(weekDay?.end_time) || '16:00';
  } else if (props.shiftType === 'week_night') {
    const weekNight = shiftDefaults.week_night;
    addServiceForm.value.startTime = extractTimeString(weekNight?.start_time) || '20:00';
    addServiceForm.value.endTime = extractTimeString(weekNight?.end_time) || '08:00';
  } else if (props.shiftType === 'weekend_day') {
    const weekendDay = shiftDefaults.weekend_day;
    addServiceForm.value.startTime = extractTimeString(weekendDay?.start_time) || '08:00';
    addServiceForm.value.endTime = extractTimeString(weekendDay?.end_time) || '16:00';
  } else if (props.shiftType === 'weekend_night') {
    const weekendNight = shiftDefaults.weekend_night;
    addServiceForm.value.startTime = extractTimeString(weekendNight?.start_time) || '20:00';
    addServiceForm.value.endTime = extractTimeString(weekendNight?.end_time) || '08:00';
  }
}

async function addService() {
  if (!canAddService.value || isSubmitting.value) return;
  
  isSubmitting.value = true;
  
  try {
    if (isShiftMode.value) {
      // In shift mode, add to the specific shift
      // Get default color from settings based on shift type
      let defaultColor = '#4285F4'; // Fallback default color
      
      // Use the appropriate color based on the shift type
      if (props.shiftType === 'week_day') {
        defaultColor = settingsStore.shiftDefaults.week_day?.color || defaultColor;
      } else if (props.shiftType === 'week_night') {
        defaultColor = settingsStore.shiftDefaults.week_night?.color || defaultColor;
      } else if (props.shiftType === 'weekend_day') {
        defaultColor = settingsStore.shiftDefaults.weekend_day?.color || defaultColor;
      } else if (props.shiftType === 'weekend_night') {
        defaultColor = settingsStore.shiftDefaults.weekend_night?.color || defaultColor;
      }
      
      await shiftsStore.addShiftSupportService(
        props.shiftId,
        addServiceForm.value.serviceId,
        addServiceForm.value.startTime,
        addServiceForm.value.endTime,
        defaultColor
      );
      
      // Reload the service assignments
      await shiftsStore.fetchShiftSupportServices(props.shiftId);
    } else {
      // In settings mode, add to default settings
      await supportServicesStore.addServiceAssignment(
        addServiceForm.value.serviceId,
        props.shiftType,
        addServiceForm.value.startTime,
        addServiceForm.value.endTime,
        addServiceForm.value.color
      );
      
      // Reload default assignments
      await supportServicesStore.fetchServiceAssignments();
    }
    
    // Reset form and close modal
    addServiceForm.value.serviceId = '';
    showAddServiceModal.value = false;
  } catch (error) {
  } finally {
    isSubmitting.value = false;
  }
}

function openEditModal(assignment) {
  selectedAssignment.value = assignment;
  showEditModal.value = true;
}

async function updateAssignment(assignmentId, updates) {
  try {
    if (isShiftMode.value) {
      // In shift mode, update the specific shift assignment
      await shiftsStore.updateShiftSupportService(assignmentId, updates);
      
      // Reload assignments
      await shiftsStore.fetchShiftSupportServices(props.shiftId);
    } else {
      // In settings mode, update the default assignment
      await supportServicesStore.updateServiceAssignment(assignmentId, updates);
      
      // Reload default assignments
      await supportServicesStore.fetchServiceAssignments();
    }
    
    showEditModal.value = false;
    selectedAssignment.value = null;
  } catch (error) {
  }
}

async function confirmRemove(assignmentId) {
  if (confirm('Are you sure you want to remove this service assignment?')) {
    try {
      if (isShiftMode.value) {
        // In shift mode, remove from the specific shift
        await shiftsStore.removeShiftSupportService(assignmentId);
      } else {
        // In settings mode, remove from default settings
        await supportServicesStore.deleteServiceAssignment(assignmentId);
        
        // Refresh service assignments
        await supportServicesStore.fetchServiceAssignments();
      }
      
      showEditModal.value = false;
      selectedAssignment.value = null;
    } catch (error) {
    }
  }
}
</script>

<!-- Styles are now handled by the global CSS layers -->
