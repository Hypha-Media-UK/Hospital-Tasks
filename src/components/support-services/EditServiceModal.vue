<template>
  <div class="modal-overlay" @click.stop="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">Edit {{ props.service.name }}</h3>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <!-- Service Info -->
        <div class="service-info">
          <div class="service-header">
            <div class="service-title">
              <div class="service-name">
                <input 
                  type="text"
                  id="edit-name"
                  v-model="editForm.name"
                  class="name-input"
                  required
                  placeholder="Service Name"
                />
              </div>
            </div>
            <input 
              type="color" 
              id="color" 
              v-model="editForm.color" 
              class="color-picker"
            />
          </div>
        </div>
        
        <!-- Service Time settings -->
        <div class="time-settings">
          <div class="time-group">
            <label for="startTime">Start Time</label>
            <input 
              type="time" 
              id="startTime" 
              v-model="editForm.startTime" 
            />
          </div>
          
          <div class="time-group">
            <label for="endTime">End Time</label>
            <input 
              type="time" 
              id="endTime" 
              v-model="editForm.endTime" 
            />
          </div>
        </div>
        
        <!-- Porter Assignments Section -->
        <div class="porter-assignments" v-if="serviceAssignment">
          <h4 class="section-title">Default Porter Assignments</h4>
          
          <div v-if="porterAssignments.length === 0" class="empty-state">
            <p>No porters assigned to this service yet.</p>
          </div>
          
          <div v-else class="porter-list">
            <div 
              v-for="assignment in porterAssignments" 
              :key="assignment.id"
              class="porter-item"
            >
              <div class="porter-info">
                <div class="porter-name">
                  {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
                </div>
                <div class="porter-time">
                  {{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
                </div>
              </div>
              
              <div class="porter-actions">
                <button 
                  @click.stop="editPorterAssignment(assignment)"
                  class="btn btn--icon"
                  title="Edit porter assignment"
                >
                  <span class="icon">✏️</span>
                </button>
                <button 
                  @click.stop="removePorterAssignment(assignment.id)"
                  class="btn btn--icon btn--danger"
                  title="Remove porter assignment"
                >
                  <span class="icon">🗑️</span>
                </button>
              </div>
            </div>
          </div>
          
          <button @click.stop="showAddPorterModal = true" class="btn btn-primary btn-sm mt-2">
            Add Porter
          </button>
          
          <!-- Coverage Status -->
          <div v-if="serviceAssignment" class="coverage-status" :class="{ 'has-gap': hasCoverageGap }">
            <div class="status-icon">{{ hasCoverageGap ? '⚠️' : '✅' }}</div>
            <div class="status-text">
              {{ hasCoverageGap ? 'Coverage gap detected! Some time slots are not covered.' : 'Full coverage for this service.' }}
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <div class="modal-footer-left">
          <button 
            class="btn btn-danger" 
            @click.stop="confirmDelete"
          >
            Delete Service
          </button>
        </div>
        <div class="modal-footer-right">
          <button 
            @click.stop="$emit('close')" 
            class="btn btn-secondary"
          >
            Cancel
          </button>
          <button 
            @click.stop="saveChanges" 
            class="btn btn-primary"
            :disabled="saving || !editForm.name.trim()"
          >
            {{ saving ? 'Saving...' : 'Save Changes' }}
          </button>
        </div>
      </div>
    </div>
    
    <!-- Porter Assignment Modal -->
    <DefaultServicePortersModal
      v-if="showPorterModal"
      :serviceAssignment="serviceAssignment"
      :porterAssignment="editingPorterAssignment ? { id: editingPorterAssignmentId, porter_id: porterForm.porterId, start_time: porterForm.startTime + ':00', end_time: porterForm.endTime + ':00' } : null"
      :defaultTimes="{ startTime: editForm.startTime, endTime: editForm.endTime }"
      @close="closePorterModal"
      @save="refreshPorterAssignments"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStaffStore } from '../../stores/staffStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';
import DefaultServicePortersModal from './DefaultServicePortersModal.vue';

const props = defineProps({
  service: {
    type: Object,
    required: true
  },
  assignment: {
    type: Object,
    required: false,
    default: null
  }
});

const emit = defineEmits(['close', 'update', 'delete', 'update-assignment']);

const staffStore = useStaffStore();
const supportServicesStore = useSupportServicesStore();

// Form state
const editForm = ref({
  name: '',
  description: '',
  startTime: '08:00',
  endTime: '16:00',
  color: '#4285F4'
});

const saving = ref(false);
const showPorterModal = ref(false);
const showAddPorterModal = ref(false);
const editingPorterAssignment = ref(false);
const editingPorterAssignmentId = ref(null);
const savingPorter = ref(false);

// Form data for porter assignment
const porterForm = ref({
  porterId: '',
  startTime: '',
  endTime: ''
});

// Get the current service assignment (if editing an existing one)
const serviceAssignment = computed(() => {
  if (props.assignment) {
    return props.assignment;
  }
  
  // Try to find the service assignment in the store
  const assignments = supportServicesStore.serviceAssignments.filter(a => 
    a.service_id === props.service.id
  );
  
  return assignments.length > 0 ? assignments[0] : null;
});

// Get porter assignments for this service
const porterAssignments = computed(() => {
  if (!serviceAssignment.value) return [];
  
  return supportServicesStore.getPorterAssignmentsByServiceId(serviceAssignment.value.id) || [];
});

// Check if there's a coverage gap
const hasCoverageGap = computed(() => {
  if (!serviceAssignment.value) return false;
  
  return supportServicesStore.hasCoverageGap(serviceAssignment.value.id);
});

// Get available porters for assignment
const availablePorters = computed(() => {
  // Get all porters
  const allPorters = staffStore.porters.filter(p => p.role === 'porter' || p.role === 'runner');
  
  // If editing an existing assignment, include the current porter
  if (editingPorterAssignment.value && porterForm.value.porterId) {
    // Check if the current porter is already in the list
    const currentPorterInList = allPorters.some(p => p.id === porterForm.value.porterId);
    
    // If not in list, add them
    if (!currentPorterInList) {
      const currentPorter = staffStore.porters.find(p => p.id === porterForm.value.porterId);
      if (currentPorter) {
        return [...allPorters, currentPorter];
      }
    }
  }
  
  return allPorters;
});

// Check if porter form is valid
const canSavePorter = computed(() => {
  return porterForm.value.porterId && 
         porterForm.value.startTime && 
         porterForm.value.endTime;
});

// Initialize form with service data
onMounted(async () => {
  // Load porters if not already loaded
  if (!staffStore.porters.length) {
    await staffStore.fetchPorters();
  }
  
  // Format time from HH:MM:SS to HH:MM for input
  const formatTime = (timeStr) => {
    if (!timeStr) return '';
    return timeStr.substring(0, 5); // Gets only HH:MM part
  };
  
  // Initialize form with service data
  editForm.value = {
    name: props.service.name || '',
    description: props.service.description || '',
    startTime: serviceAssignment.value ? formatTime(serviceAssignment.value.start_time) : '08:00',
    endTime: serviceAssignment.value ? formatTime(serviceAssignment.value.end_time) : '16:00',
    color: serviceAssignment.value ? serviceAssignment.value.color : '#4285F4'
  };
});

// Save changes
async function saveChanges() {
  if (!editForm.value.name.trim() || saving.value) return;
  
  saving.value = true;
  
  try {
    // Prepare update object for the service
    const updatedService = {
      id: props.service.id,
      name: editForm.value.name.trim(),
      description: editForm.value.description || null
    };
    
    // Emit update event for the service
    emit('update', updatedService);
    
    // If we have an assignment, update its times and color
    if (serviceAssignment.value) {
      const updates = {
        start_time: editForm.value.startTime + ':00', // Add seconds for database format
        end_time: editForm.value.endTime + ':00',
        color: editForm.value.color
      };
      
      await supportServicesStore.updateServiceAssignment(serviceAssignment.value.id, updates);
    }
  } catch (error) {
    console.error('Error saving service:', error);
  } finally {
    saving.value = false;
  }
}

// Delete service
function confirmDelete() {
  if (confirm(`Are you sure you want to delete "${props.service.name}"?`)) {
    emit('delete', props.service.id);
  }
}

// Porter assignment methods
function editPorterAssignment(assignment) {
  editingPorterAssignment.value = true;
  editingPorterAssignmentId.value = assignment.id;
  
  porterForm.value = {
    porterId: assignment.porter_id,
    startTime: assignment.start_time ? assignment.start_time.substring(0, 5) : '08:00',
    endTime: assignment.end_time ? assignment.end_time.substring(0, 5) : '16:00'
  };
  
  showPorterModal.value = true;
}

function closePorterModal() {
  showPorterModal.value = false;
  showAddPorterModal.value = false;
  editingPorterAssignment.value = false;
  editingPorterAssignmentId.value = null;
  
  // Reset form
  porterForm.value = {
    porterId: '',
    startTime: '',
    endTime: ''
  };
}

async function savePorterAssignment() {
  if (!canSavePorter.value || savingPorter.value) return;
  
  savingPorter.value = true;
  
  try {
    // Format times for storage (add seconds)
    const startTime = porterForm.value.startTime + ':00';
    const endTime = porterForm.value.endTime + ':00';
    
    if (editingPorterAssignment.value) {
      // Update existing assignment
      await supportServicesStore.updatePorterAssignment(editingPorterAssignmentId.value, {
        start_time: startTime,
        end_time: endTime
      });
    } else if (serviceAssignment.value) {
      // Add new assignment
      await supportServicesStore.addPorterToServiceAssignment(
        serviceAssignment.value.id,
        porterForm.value.porterId,
        startTime,
        endTime
      );
    }
    
    closePorterModal();
  } catch (error) {
    console.error('Error saving porter assignment:', error);
  } finally {
    savingPorter.value = false;
  }
}

async function removePorterAssignment(assignmentId) {
  if (confirm('Are you sure you want to remove this porter assignment?')) {
    await supportServicesStore.removePorterAssignment(assignmentId);
    // Refresh the assignments list after removing
    await refreshPorterAssignments();
  }
}

// Function to refresh porter assignments after changes
async function refreshPorterAssignments() {
  if (serviceAssignment.value) {
    // Refresh porter assignments from the store
    await supportServicesStore.fetchServiceAssignments();
  }
}

// Helper methods
function formatTime(timeStr) {
  if (!timeStr) return '';
  return timeStr.substring(0, 5); // Extract HH:MM from HH:MM:SS
}

// Watch for "Add Porter" button click
watch(showAddPorterModal, (newValue) => {
  if (newValue) {
    // Set default values for the form
    porterForm.value = {
      porterId: '',
      startTime: editForm.value.startTime,
      endTime: editForm.value.endTime
    };
    
    showPorterModal.value = true;
  }
});
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

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
  max-width: 550px;
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
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: space-between;
  
  &-left {
    display: flex;
    gap: 12px;
  }
  
  &-right {
    display: flex;
    gap: 12px;
  }
}

// Service info styling
.service-info {
  margin-bottom: 12px;
  
  .service-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    
    .service-title {
      flex: 1;
    }
    
    .service-name {
      .name-input {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('md');
        font-size: mix.font-size('md');
        font-weight: 600;
        
        &:focus {
          outline: none;
          border-color: mix.color('primary');
          box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.2);
        }
      }
    }
    
    .color-picker {
      width: 32px;
      height: 32px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      cursor: pointer;
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
      }
    }
  }
}

// Time settings
.time-settings {
  display: flex;
  gap: 16px;
  
  .time-group {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
    
    label {
      font-size: mix.font-size('sm');
      font-weight: 500;
      color: rgba(0, 0, 0, 0.7);
    }
    
    input[type="time"] {
      padding: 6px 8px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('md');
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
      }
    }
  }
}

.section-title {
  font-size: mix.font-size('md');
  font-weight: 600;
  margin: 24px 0 16px;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
}

.porter-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 16px;
}

.porter-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: mix.radius('md');
  background-color: white;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.01);
  }
}

.porter-info {
  .porter-name {
    display: inline-block;
    background-color: rgba(66, 133, 244, 0.1);
    color: mix.color('primary');
    border-radius: 100px;
    padding: 4px 12px;
    font-size: mix.font-size('sm');
    font-weight: 500;
    white-space: nowrap;
    margin-bottom: 4px;
  }
  
  .porter-time {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
    margin-left: 12px;
  }
}

.porter-actions {
  display: flex;
  gap: 4px;
}

.empty-state {
  padding: 16px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: mix.radius('md');
  
  p {
    margin: 0;
  }
}

.coverage-status {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px;
  border-radius: mix.radius('md');
  margin-top: 16px;
  background-color: rgba(52, 168, 83, 0.1);
  
  &.has-gap {
    background-color: rgba(234, 67, 53, 0.1);
  }
  
  .status-text {
    font-weight: 500;
  }
}

.nested-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1001;
}

.nested-modal-container {
  background-color: white;
  border-radius: mix.radius('lg');
  width: 90%;
  max-width: 500px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &.btn-primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
  }
  
  &.btn-secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: color.scale(#f1f1f1, $lightness: -5%);
    }
  }
  
  &.btn-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#dc3545, $lightness: -10%);
    }
  }
  
  &.btn-sm {
    padding: 6px 12px;
    font-size: mix.font-size('sm');
  }
  
  &.btn--icon {
    padding: 4px;
    border-radius: 4px;
    background: transparent;
    
    &:hover {
      background-color: rgba(0, 0, 0, 0.05);
    }
    
    &.btn--danger:hover {
      background-color: rgba(234, 67, 53, 0.1);
    }
    
    .icon {
      font-size: 16px;
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.mt-2 {
  margin-top: 8px;
}
</style>
