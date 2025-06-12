<template>
  <div class="support-services-shift-list">
    <!-- Loading state -->
    <div v-if="loading" class="loading-state">
      Loading support services...
    </div>
    
    <!-- Empty state -->
    <div v-else-if="serviceAssignments.length === 0" class="empty-state">
      <p>No support services have been assigned to this shift type.</p>
      <button v-if="showHeader" @click="showAddServiceModal = true" class="btn-add-service">
        <span class="icon">+</span> Add Service
      </button>
    </div>
    
    <!-- Service Assignments List -->
    <div v-else>
      <div class="services-list-header" v-if="showHeader">
        <h4>{{ shiftTypeLabel }} Coverage</h4>
        <button @click="showAddServiceModal = true" class="btn-add-service">
          <span class="icon">+</span> Add Service
        </button>
      </div>
      
      <div class="services-grid">
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
    <div v-if="showAddServiceModal" class="modal-overlay" @click.self="showAddServiceModal = false">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">Add Support Service</h3>
          <button @click="showAddServiceModal = false" class="modal-close">&times;</button>
        </div>
        
        <div class="modal-body">
          <div class="form-group">
            <label for="service-select">Select Service</label>
            <select 
              id="service-select"
              v-model="addServiceForm.serviceId"
              class="form-control"
              required
            >
              <option value="">Select a support service</option>
              <option 
                v-for="service in availableServices" 
                :key="service.id"
                :value="service.id"
              >
                {{ service.name }}
              </option>
            </select>
            
            <div v-if="availableServices.length === 0" class="form-help-text">
              No available services to add. Create new services in the support services section.
            </div>
          </div>
          
          <div class="form-group">
            <label for="start-time">Start Time</label>
            <input 
              type="time"
              id="start-time"
              v-model="addServiceForm.startTime"
              class="form-control"
              required
            />
          </div>
          
          <div class="form-group">
            <label for="end-time">End Time</label>
            <input 
              type="time"
              id="end-time"
              v-model="addServiceForm.endTime"
              class="form-control"
              required
            />
          </div>
          
          <!-- Only show color selection in settings mode, not in shift mode -->
          <div class="form-group" v-if="!isShiftMode">
            <label for="color">Color</label>
            <input 
              type="color"
              id="color"
              v-model="addServiceForm.color"
              class="form-control color-input"
            />
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            @click="addService" 
            class="btn btn-primary"
            :disabled="!canAddService || isSubmitting"
          >
            {{ isSubmitting ? 'Adding...' : 'Add Service' }}
          </button>
          <button 
            @click="showAddServiceModal = false" 
            class="btn btn-secondary"
            :disabled="isSubmitting"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
    
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
    console.log(`Computing service assignments for shift ${props.shiftId}; total: ${shiftsStore.shiftSupportServiceAssignments.length}`);
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
  // Get all services
  const allServices = supportServicesStore.services || [];
  
  // Get ids of services already assigned
  const assignedServiceIds = serviceAssignments.value.map(a => 
    isShiftMode.value ? a.service_id : a.service.id
  );
  
  // Return only services not already assigned
  return allServices.filter(service => 
    !assignedServiceIds.includes(service.id) && service.is_active !== false
  );
});

const canAddService = computed(() => 
  addServiceForm.value.serviceId && 
  addServiceForm.value.startTime && 
  addServiceForm.value.endTime
);

// Load data when component mounts
onMounted(async () => {
  console.log(`SupportServicesShiftList mounted for shift ${props.shiftId} with type ${props.shiftType}`);

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
      console.log(`Loading support service assignments for shift: ${props.shiftId}`);
      // If in shift mode, load support service assignments for this shift
      await shiftsStore.fetchShiftSupportServices(props.shiftId);
      
      // Log the loaded assignments to check if everything is correctly loaded
      console.log(`Loaded ${shiftsStore.shiftSupportServiceAssignments.length} support service assignments`);
      console.log(`Filtered for this shift: ${serviceAssignments.value.length}`);
      
      // Check porter assignments for each service
      if (serviceAssignments.value.length > 0) {
        console.log('Checking porter assignments for each service');
        serviceAssignments.value.forEach(assignment => {
          const porterAssignments = shiftsStore.getPorterAssignmentsByServiceId(assignment.id);
          console.log(`Service ${assignment.id} (${assignment.service.name}) has ${porterAssignments.length} porter assignments`);
          
          // Check if service has coverage gaps
          const gaps = shiftsStore.getServiceCoverageGaps(assignment.id);
          console.log(`Service ${assignment.id} coverage gaps:`, gaps);
        });
      }
    } else {
      // Otherwise, load default assignments for this shift type
      await supportServicesStore.ensureAssignmentsLoaded(props.shiftType);
    }
  } catch (error) {
    console.error('Error loading service assignments:', error);
  }
  
  // Set default times based on shift type
  initializeFormDefaults();
});

// Methods
function initializeFormDefaults() {
  // Set default times based on the specific shift type
  if (props.shiftType === 'week_day') {
    addServiceForm.value.startTime = settingsStore.shiftDefaults.week_day?.startTime || '08:00';
    addServiceForm.value.endTime = settingsStore.shiftDefaults.week_day?.endTime || '16:00';
  } else if (props.shiftType === 'week_night') {
    addServiceForm.value.startTime = settingsStore.shiftDefaults.week_night?.startTime || '20:00';
    addServiceForm.value.endTime = settingsStore.shiftDefaults.week_night?.endTime || '08:00';
  } else if (props.shiftType === 'weekend_day') {
    addServiceForm.value.startTime = settingsStore.shiftDefaults.weekend_day?.startTime || '08:00';
    addServiceForm.value.endTime = settingsStore.shiftDefaults.weekend_day?.endTime || '16:00';
  } else if (props.shiftType === 'weekend_night') {
    addServiceForm.value.startTime = settingsStore.shiftDefaults.weekend_night?.startTime || '20:00';
    addServiceForm.value.endTime = settingsStore.shiftDefaults.weekend_night?.endTime || '08:00';
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
    console.error('Error adding service assignment:', error);
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
    console.error('Error updating assignment:', error);
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
      console.error('Error removing assignment:', error);
    }
  }
}
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.support-services-shift-list {
  // List container styles
  
  .services-list-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    
    h4 {
      margin: 0;
      font-size: mix.font-size('md');
    }
  }
  
  .btn-add-service {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border: none;
    background-color: mix.color('primary');
    color: white;
    border-radius: mix.radius('md');
    font-weight: 500;
    cursor: pointer;
    font-size: mix.font-size('sm');
    
    &:hover {
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
    
    .icon {
      font-size: 16px;
      font-weight: bold;
    }
  }
  
  .services-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }
  
  .loading-state, .empty-state {
    padding: 24px;
    text-align: center;
    background-color: #f9f9f9;
    border-radius: mix.radius('md');
    
    p {
      margin-bottom: 16px;
      color: rgba(0, 0, 0, 0.6);
    }
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
  border-radius: mix.radius('lg');
  width: 90%;
  max-width: 500px;
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
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    
    &.color-input {
      height: 40px;
      padding: 4px;
      cursor: pointer;
    }
  }
  
  .form-help-text {
    margin-top: 4px;
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
  }
}

.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &-primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
  }
  
  &-secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
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
