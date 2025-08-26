<template>
  <BaseModal
    :title="`${service.name} Coverage`"
    size="large"
    @close="closeModal"
  >
        <div class="form-group">
          <label for="service-name">Service Name</label>
          <input
            type="text"
            id="service-name"
            v-model="localName"
            required
            placeholder="Service Name"
          />
        </div>

        <!-- Service Time settings -->
        <div class="modal-form-section time-settings">
          <div class="form-group">
            <label for="startTime">Start Time</label>
            <input
              type="time"
              id="startTime"
              v-model="localStartTime"
            />
          </div>

          <div class="form-group">
            <label for="endTime">End Time</label>
            <input
              type="time"
              id="endTime"
              v-model="localEndTime"
            />
          </div>
        </div>
        
        <!-- Minimum Porter Count by Day -->
        <div class="modal-form-section">
          <h4>Minimum Porter Count by Day</h4>
          
          <div class="day-toggle">
            <label class="toggle-label">
              <input type="checkbox" v-model="useSameForAllDays" @change="handleSameForAllDaysChange">
              <span class="toggle-text">Same for all days</span>
            </label>
          </div>
          
          <div v-if="useSameForAllDays" class="single-input-wrapper">
            <div class="min-porters-input">
              <input 
                type="number" 
                v-model="sameForAllDaysValue"
                min="0"
                class="number-input"
                @change="applySameValueToAllDays"
              />
              <div class="min-porters-description">
                Minimum number of porters required for all days
              </div>
            </div>
          </div>
          
          <div v-else class="days-grid">
            <div v-for="(day, index) in days" :key="day.code" class="day-input">
              <label :for="'min-porters-' + day.code">{{ day.code }}</label>
              <input 
                type="number" 
                :id="'min-porters-' + day.code"
                v-model="dayMinPorters[index]"
                min="0"
                class="number-input day-input"
              />
            </div>
          </div>
        </div>
        
        <!-- Multiple Porter assignments -->
        <div class="porter-assignments" v-if="serviceAssignment">
          <div class="section-title">
            Porters
            <span v-if="hasLocalCoverageGap" class="coverage-gap-indicator">
              Coverage Gap Detected
            </span>
          </div>
          
          <div v-if="localPorterAssignments.length === 0" class="empty-state">
            No porters assigned. Add a porter to provide coverage.
          </div>
          
          <div v-else class="porter-list">
            <div 
              v-for="(porterAssignment, index) in localPorterAssignments" 
              :key="porterAssignment.id || `new-${index}`"
              class="porter-assignment-item"
            >
              <div class="porter-pill">
                <span class="porter-name">
                  {{ porterAssignment.porter?.first_name || porterAssignment.staff?.first_name || 'Unknown' }} {{ porterAssignment.porter?.last_name || porterAssignment.staff?.last_name || 'Porter' }}
                </span>
              </div>
              
              <div class="porter-times">
                <div class="time-group">
                  <input 
                    type="time" 
                    v-model="porterAssignment.start_time_display" 
                  />
                </div>
                <span class="time-separator">to</span>
                <div class="time-group">
                  <input 
                    type="time" 
                    v-model="porterAssignment.end_time_display" 
                  />
                </div>
              </div>
              
              <button 
                class="btn btn--icon" 
                title="Remove porter assignment"
                @click.stop="removeLocalPorterAssignment(index)"
              >
                &times;
              </button>
            </div>
          </div>
          
          <div class="add-porter">
            <div v-if="!showAddPorter" class="add-porter-button">
              <button 
                class="btn btn--primary" 
                @click.stop="showAddPorter = true"
              >
                Add Porter
              </button>
            </div>
            
            <div v-else class="add-porter-form">
              <div class="form-row">
                <select v-model="newPorterAssignment.porter_id">
                  <option value="">-- Select Porter --</option>
                  <option 
                    v-for="porter in availablePorters" 
                    :key="porter.id" 
                    :value="porter.id"
                  >
                    {{ porter.first_name }} {{ porter.last_name }}
                  </option>
                </select>
                
                <div class="time-group">
                  <input 
                    type="time" 
                    v-model="newPorterAssignment.start_time"
                    placeholder="Start Time"
                  />
                </div>
                
                <div class="time-group">
                  <input 
                    type="time" 
                    v-model="newPorterAssignment.end_time"
                    placeholder="End Time"
                  />
                </div>
                
                <div class="action-buttons">
                  <button 
                    class="btn btn--small btn--primary" 
                    @click.stop="addLocalPorterAssignment"
                    :disabled="!newPorterAssignment.porter_id || !newPorterAssignment.start_time || !newPorterAssignment.end_time"
                  >
                    Add
                  </button>
                  <button 
                    class="btn btn--small btn--secondary" 
                    @click.stop="showAddPorter = false"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

    <template #footer>
      <button
        class="btn btn--primary"
        @click.stop="saveAllChanges"
        :disabled="!localName.trim()"
      >
        Update
      </button>
      <button
        class="btn btn--secondary"
        @click.stop="closeModal"
      >
        Cancel
      </button>
      <button
        class="btn btn--danger ml-auto"
        @click.stop="confirmDelete"
      >
        Delete Service
      </button>
    </template>
  </BaseModal>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStaffStore } from '../../stores/staffStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';
import BaseModal from '../shared/BaseModal.vue';

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

const emit = defineEmits(['close', 'update', 'delete', 'update-assignment', 'remove']);

const staffStore = useStaffStore();
const supportServicesStore = useSupportServicesStore();

// Local state for all editable properties
const localName = ref('');
const localStartTime = ref('');
const localEndTime = ref('');
const localMinPorters = ref(1);
const localPorterAssignments = ref([]);
const showAddPorter = ref(false);
const removedPorterIds = ref([]);

// Day-specific minimum porter counts
const days = [
  { code: 'Mo', name: 'Monday', field: 'minimum_porters_mon' },
  { code: 'Tu', name: 'Tuesday', field: 'minimum_porters_tue' },
  { code: 'We', name: 'Wednesday', field: 'minimum_porters_wed' },
  { code: 'Th', name: 'Thursday', field: 'minimum_porters_thu' },
  { code: 'Fr', name: 'Friday', field: 'minimum_porters_fri' },
  { code: 'Sa', name: 'Saturday', field: 'minimum_porters_sat' },
  { code: 'Su', name: 'Sunday', field: 'minimum_porters_sun' }
];
const useSameForAllDays = ref(true);
const sameForAllDaysValue = ref(1);
const dayMinPorters = ref([1, 1, 1, 1, 1, 1, 1]); // Default values for each day

// Handle "Same for all days" toggle change
const handleSameForAllDaysChange = () => {
  if (useSameForAllDays.value) {
    // When toggling to "same for all days", use the first day's value
    sameForAllDaysValue.value = dayMinPorters.value[0] || 1;
    applySameValueToAllDays();
  }
};

// Apply the same value to all days
const applySameValueToAllDays = () => {
  if (useSameForAllDays.value) {
    dayMinPorters.value = Array(7).fill(parseInt(sameForAllDaysValue.value) || 0);
  }
};

const newPorterAssignment = ref({
  porter_id: '',
  start_time: '',
  end_time: ''
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

// Computed property for determining what porters are available
const availablePorters = computed(() => {
  // Get all porters
  const allPorters = staffStore.sortedPorters || [];
  
  // Filter out porters that are already in our local assignments
  const assignedPorterIds = localPorterAssignments.value.map(pa => pa.porter_id);
  return allPorters.filter(porter => !assignedPorterIds.includes(porter.id));
});

// Check for coverage gaps with local data
const hasLocalCoverageGap = computed(() => {
  if (localPorterAssignments.value.length === 0) return true;
  
  // Convert service times to minutes for easier comparison
  const serviceStart = timeToMinutes(localStartTime.value + ':00');
  const serviceEnd = timeToMinutes(localEndTime.value + ':00');
  
  // First check if any single porter covers the entire time period
  const fullCoverageExists = localPorterAssignments.value.some(assignment => {
    const porterStart = timeToMinutes(assignment.start_time_display + ':00');
    const porterEnd = timeToMinutes(assignment.end_time_display + ':00');
    return porterStart <= serviceStart && porterEnd >= serviceEnd;
  });
  
  // If at least one porter provides full coverage, there's no gap
  if (fullCoverageExists) {
    return false;
  }
  
  // Sort porter assignments by start time
  const sortedAssignments = [...localPorterAssignments.value].sort((a, b) => {
    return timeToMinutes(a.start_time_display + ':00') - timeToMinutes(b.start_time_display + ':00');
  });
  
  // Check for gap at the beginning
  if (timeToMinutes(sortedAssignments[0].start_time_display + ':00') > serviceStart) {
    return true;
  }
  
  // Check for gaps between porter assignments
  for (let i = 0; i < sortedAssignments.length - 1; i++) {
    const currentEnd = timeToMinutes(sortedAssignments[i].end_time_display + ':00');
    const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time_display + ':00');
    
    if (nextStart > currentEnd) {
      return true;
    }
  }
  
  // Check for gap at the end
  const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time_display + ':00');
  if (lastEnd < serviceEnd) {
    return true;
  }
  
  return false;
});

// Methods
const closeModal = () => {
  emit('close');
};

const addLocalPorterAssignment = () => {
  if (!newPorterAssignment.value.porter_id || 
      !newPorterAssignment.value.start_time || 
      !newPorterAssignment.value.end_time) {
    return;
  }
  
  // Find the porter in the list
  const porter = staffStore.porters.find(p => p.id === newPorterAssignment.value.porter_id);
  
  if (porter) {
    // Add to local state with a temporary ID
    localPorterAssignments.value.push({
      id: `temp-${Date.now()}`,
      service_assignment_id: serviceAssignment.value.id,
      porter_id: newPorterAssignment.value.porter_id,
      start_time: newPorterAssignment.value.start_time + ':00',
      end_time: newPorterAssignment.value.end_time + ':00',
      start_time_display: newPorterAssignment.value.start_time,
      end_time_display: newPorterAssignment.value.end_time,
      porter: porter,
      isNew: true
    });
  }
  
  // Reset form
  newPorterAssignment.value = {
    porter_id: '',
    start_time: '',
    end_time: ''
  };
  
  showAddPorter.value = false;
};

const removeLocalPorterAssignment = (index) => {
  const assignment = localPorterAssignments.value[index];
  
  // If it's an existing assignment (has a real DB ID), track it for deletion
  if (assignment.id && !assignment.isNew) {
    removedPorterIds.value.push(assignment.id);
  }
  
  // Remove from local array
  localPorterAssignments.value.splice(index, 1);
};

const saveAllChanges = async () => {
  try {
    // 1. Update the service
    const updatedService = {
      id: props.service.id,
      name: localName.value.trim(),
      description: props.service.description || null
    };
    
    // Emit update event for the service
    emit('update', updatedService);
    
    // 2. Update service assignment (times, color, minimum porters)
    if (serviceAssignment.value) {
      // Create an update object with basic properties
      const updateData = {
        start_time: localStartTime.value + ':00',
        end_time: localEndTime.value + ':00',
        minimum_porters: parseInt(sameForAllDaysValue.value) || 0
      };
      
      // Add day-specific minimum porter counts
      days.forEach((day, index) => {
        updateData[day.field] = parseInt(dayMinPorters.value[index]) || 0;
      });
      
      await supportServicesStore.updateServiceAssignment(serviceAssignment.value.id, updateData);
    
      // 3. Remove porter assignments that were deleted
      for (const porterId of removedPorterIds.value) {
        await supportServicesStore.removePorterAssignment(porterId);
      }
      
      // 4. Process porter assignments
      for (const assignment of localPorterAssignments.value) {
        if (assignment.isNew) {
          // Add new assignment
          await supportServicesStore.addPorterToServiceAssignment(
            serviceAssignment.value.id,
            assignment.porter_id,
            assignment.start_time,
            assignment.end_time
          );
        } else {
          // Update existing assignment
          await supportServicesStore.updatePorterAssignment(assignment.id, {
            start_time: assignment.start_time_display + ':00',
            end_time: assignment.end_time_display + ':00'
          });
        }
      }
    }
    
    // Close the modal
    closeModal();
  } catch (error) {
    alert('Failed to save changes. Please try again.');
  }
};

const confirmDelete = () => {
  if (confirm(`Are you sure you want to delete "${props.service.name}"?`)) {
    emit('delete', props.service.id);
  }
};

// Initialize component state from props
const initializeState = () => {
  // Initialize name
  localName.value = props.service.name || '';
  
  // Initialize times - handle both Date objects and strings
  if (serviceAssignment.value && serviceAssignment.value.start_time) {
    localStartTime.value = formatTimeForInput(serviceAssignment.value.start_time);
  } else {
    localStartTime.value = '08:00';
  }
  
  if (serviceAssignment.value && serviceAssignment.value.end_time) {
    localEndTime.value = formatTimeForInput(serviceAssignment.value.end_time);
  } else {
    localEndTime.value = '16:00';
  }
  
  // Initialize minimum porter count (for backwards compatibility)
  localMinPorters.value = serviceAssignment.value ? serviceAssignment.value.minimum_porters || 1 : 1;
  sameForAllDaysValue.value = serviceAssignment.value ? serviceAssignment.value.minimum_porters || 1 : 1;
  
  // Initialize day-specific minimum porter counts
  const hasAnyDaySpecificValues = 
    serviceAssignment.value && (
    serviceAssignment.value.minimum_porters_mon !== undefined || 
    serviceAssignment.value.minimum_porters_tue !== undefined ||
    serviceAssignment.value.minimum_porters_wed !== undefined ||
    serviceAssignment.value.minimum_porters_thu !== undefined ||
    serviceAssignment.value.minimum_porters_fri !== undefined ||
    serviceAssignment.value.minimum_porters_sat !== undefined ||
    serviceAssignment.value.minimum_porters_sun !== undefined);
  
  if (hasAnyDaySpecificValues) {
    dayMinPorters.value = days.map(day => 
      serviceAssignment.value[day.field] !== undefined ? serviceAssignment.value[day.field] : serviceAssignment.value.minimum_porters || 1
    );
    
    // Check if all days have the same value
    const allSameValue = dayMinPorters.value.every(val => val === dayMinPorters.value[0]);
    useSameForAllDays.value = allSameValue;
    if (allSameValue) {
      sameForAllDaysValue.value = dayMinPorters.value[0];
    }
  } else {
    // Default to same value for all days if no day-specific values exist
    useSameForAllDays.value = true;
    const defaultValue = serviceAssignment.value ? serviceAssignment.value.minimum_porters || 1 : 1;
    sameForAllDaysValue.value = defaultValue;
    dayMinPorters.value = Array(7).fill(defaultValue);
  }
  
  // Initialize porter assignments
  if (serviceAssignment.value) {
    const assignments = supportServicesStore.getPorterAssignmentsByServiceId(serviceAssignment.value.id);
    localPorterAssignments.value = assignments.map(pa => ({
      ...pa,
      start_time_display: pa.start_time ? formatTimeForInput(pa.start_time) : '',
      end_time_display: pa.end_time ? formatTimeForInput(pa.end_time) : ''
    }));
  } else {
    localPorterAssignments.value = [];
  }
  
  // Clear the removed porters list
  removedPorterIds.value = [];
};

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

// Helper function to format time for input fields (handles Date objects and strings)
function formatTimeForInput(timeValue) {
  if (!timeValue) return '';
  
  // Handle Date objects (from MySQL/Prisma)
  if (timeValue instanceof Date) {
    return timeValue.toTimeString().substring(0, 5); // Extract HH:MM from time string
  }
  
  // Handle ISO datetime strings (e.g., "1970-01-01T08:00:00.000Z")
  if (typeof timeValue === 'string' && timeValue.includes('T')) {
    const date = new Date(timeValue);
    return date.toTimeString().substring(0, 5); // Extract HH:MM from time string
  }
  
  // Handle simple time strings (e.g., "08:00:00" or "08:00")
  if (typeof timeValue === 'string') {
    return timeValue.substring(0, 5); // Extract HH:MM part
  }
  
  return '';
}

// Fetch porters if not already loaded
onMounted(async () => {
  if (staffStore.porters.length === 0) {
    await staffStore.fetchPorters();
  }
  
  initializeState();
});
</script>

<!-- Styles are now handled by the global CSS layers -->