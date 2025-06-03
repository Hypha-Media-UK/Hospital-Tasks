<template>
  <div class="modal-overlay" @click.stop="closeModal">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">Edit {{ assignment.department.name }}</h3>
        <button class="modal-close" @click.stop="closeModal">&times;</button>
      </div>
      
      <div class="modal-body">
        <div class="department-info">
          <div class="department-header">
            <div class="department-title">
              <div class="department-name">{{ assignment.department.name }}</div>
              <div class="department-building">{{ assignment.department.building?.name || 'Unknown Building' }}</div>
            </div>
            <input 
              type="color" 
              id="color" 
              v-model="localColor" 
              class="color-picker"
            />
          </div>
        </div>
        
        <!-- Department Time settings -->
        <div class="time-settings">
          <div class="time-group">
            <label for="startTime">Start Time</label>
            <input 
              type="time" 
              id="startTime" 
              v-model="localStartTime" 
            />
          </div>
          
          <div class="time-group">
            <label for="endTime">End Time</label>
            <input 
              type="time" 
              id="endTime" 
              v-model="localEndTime" 
            />
          </div>
        </div>
        
        <!-- Minimum Porter Count by Day -->
        <div class="min-porters-setting">
          <label class="section-label">Minimum Porter Count by Day</label>
          
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
        <div class="porter-assignments">
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
                <span 
                  class="porter-name" 
                  :class="{
                    'porter-absent': getPorterAbsence(porterAssignment.porter_id),
                    'porter-illness': getPorterAbsence(porterAssignment.porter_id)?.absence_type === 'illness',
                    'porter-annual-leave': getPorterAbsence(porterAssignment.porter_id)?.absence_type === 'annual_leave'
                  }"
                  @click="openAbsenceModalForPorter(porterAssignment.porter_id)"
                >
                  {{ porterAssignment.porter.first_name }} {{ porterAssignment.porter.last_name }}
                  <span v-if="getPorterAbsence(porterAssignment.porter_id)?.absence_type === 'illness'" class="absence-badge illness">ILL</span>
                  <span v-if="getPorterAbsence(porterAssignment.porter_id)?.absence_type === 'annual_leave'" class="absence-badge annual-leave">AL</span>
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
      </div>
      
      <div class="modal-footer">
        <div class="modal-footer-left">
          <button 
            class="btn btn--danger" 
            @click.stop="confirmRemove"
          >
            Remove
          </button>
        </div>
        <div class="modal-footer-right">
          <button 
            class="btn btn--secondary" 
            @click.stop="closeModal"
          >
            Cancel
          </button>
          <button 
            class="btn btn--primary" 
            @click.stop="saveAllChanges"
          >
            Update
          </button>
        </div>
      </div>
    </div>
  </div>
  
  <Teleport to="body">
    <PorterAbsenceModal
      v-if="showAbsenceModal && selectedPorterId"
      :porter-id="selectedPorterId"
      :absence="currentPorterAbsence"
      @close="showAbsenceModal = false"
      @save="handleAbsenceSave"
    />
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted, reactive } from 'vue';
import { useAreaCoverStore } from '../../stores/areaCoverStore';
import { useStaffStore } from '../../stores/staffStore';
import PorterAbsenceModal from '../PorterAbsenceModal.vue';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'update', 'remove']);

const areaCoverStore = useAreaCoverStore();
const staffStore = useStaffStore();

// Local state for all editable properties
const localStartTime = ref('');
const localEndTime = ref('');
const localColor = ref('#4285F4');
const localMinPorters = ref(1);
const localPorterAssignments = ref([]);
const showAddPorter = ref(false);
const removedPorterIds = ref([]);
const showAbsenceModal = ref(false);
const selectedPorterId = ref(null);
const currentPorterAbsence = ref(null);

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

// Computed property for determining what porters are available
const availablePorters = computed(() => {
  // Get all porters
  const allPorters = staffStore.sortedPorters || [];
  
  // Filter out porters that are already in our local assignments
  const assignedPorterIds = localPorterAssignments.value.map(pa => pa.porter_id);
  
  // Get current date for absence check
  const today = new Date();
  
  return allPorters.filter(porter => {
    // Filter out porters that are already assigned
    if (assignedPorterIds.includes(porter.id)) {
      return false;
    }
    
    // Filter out porters that are absent
    if (staffStore.isPorterAbsent(porter.id, today)) {
      return false;
    }
    
    return true;
  });
});

// Check for coverage gaps with local data
const hasLocalCoverageGap = computed(() => {
  if (localPorterAssignments.value.length === 0) return true;
  
  // Convert department times to minutes for easier comparison
  const departmentStart = timeToMinutes(localStartTime.value + ':00');
  const departmentEnd = timeToMinutes(localEndTime.value + ':00');
  
  // Filter out porters who are absent
  const availablePorters = localPorterAssignments.value.filter(assignment => {
    // Check if porter is absent
    return !staffStore.isPorterAbsent(assignment.porter_id, new Date());
  });
  
  // If all porters are absent, there's definitely a gap
  if (availablePorters.length === 0) return true;
  
  // First check if any single non-absent porter covers the entire time period
  const fullCoverageExists = availablePorters.some(assignment => {
    const porterStart = timeToMinutes(assignment.start_time_display + ':00');
    const porterEnd = timeToMinutes(assignment.end_time_display + ':00');
    return porterStart <= departmentStart && porterEnd >= departmentEnd;
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
  if (timeToMinutes(sortedAssignments[0].start_time_display + ':00') > departmentStart) {
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
  if (lastEnd < departmentEnd) {
    return true;
  }
  
  return false;
});

// Methods
const closeModal = () => {
  emit('close');
};

// Get porter absence details
const getPorterAbsence = (porterId) => {
  const today = new Date();
  return staffStore.getPorterAbsenceDetails(porterId, today);
};

// Open absence modal for a specific porter
const openAbsenceModalForPorter = (porterId) => {
  if (!porterId) return;
  
  selectedPorterId.value = porterId;
  const today = new Date();
  currentPorterAbsence.value = staffStore.getPorterAbsenceDetails(porterId, today);
  showAbsenceModal.value = true;
};

// Handle absence save
const handleAbsenceSave = () => {
  // Refresh the absence data
  currentPorterAbsence.value = null;
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
      area_cover_assignment_id: props.assignment.id,
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
    // Create an update object with basic properties
    const updateData = {
      start_time: localStartTime.value + ':00',
      end_time: localEndTime.value + ':00',
      color: localColor.value,
      minimum_porters: parseInt(sameForAllDaysValue.value) || 0
    };
    
    // Add day-specific minimum porter counts
    days.forEach((day, index) => {
      updateData[day.field] = parseInt(dayMinPorters.value[index]) || 0;
    });
    
    // Update area cover assignment
    await areaCoverStore.updateDepartment(props.assignment.id, updateData);
    
    // 2. Remove porter assignments that were deleted
    for (const porterId of removedPorterIds.value) {
      await areaCoverStore.removePorterAssignment(porterId);
    }
    
    // 3. Process porter assignments
    for (const assignment of localPorterAssignments.value) {
      if (assignment.isNew) {
        // Add new assignment
        await areaCoverStore.addPorterAssignment(
          props.assignment.id,
          assignment.porter_id,
          assignment.start_time,
          assignment.end_time
        );
      } else {
        // Update existing assignment
        await areaCoverStore.updatePorterAssignment(assignment.id, {
          start_time: assignment.start_time_display + ':00',
          end_time: assignment.end_time_display + ':00'
        });
      }
    }
    
    // Close the modal
    closeModal();
  } catch (error) {
    console.error('Error saving changes:', error);
    alert('Failed to save changes. Please try again.');
  }
};

const confirmRemove = () => {
  if (confirm(`Are you sure you want to remove ${props.assignment.department.name} from coverage?`)) {
    emit('remove', props.assignment.id);
  }
};

// Initialize component state from props
const initializeState = () => {
  // Initialize times
  if (props.assignment.start_time) {
    localStartTime.value = props.assignment.start_time.slice(0, 5);
  }
  
  if (props.assignment.end_time) {
    localEndTime.value = props.assignment.end_time.slice(0, 5);
  }
  
  // Initialize color
  localColor.value = props.assignment.color || '#4285F4';
  
  // Initialize minimum porter count (for backwards compatibility)
  localMinPorters.value = props.assignment.minimum_porters || 1;
  sameForAllDaysValue.value = props.assignment.minimum_porters || 1;
  
  // Initialize day-specific minimum porter counts
  const hasAnyDaySpecificValues = 
    props.assignment.minimum_porters_mon !== undefined || 
    props.assignment.minimum_porters_tue !== undefined ||
    props.assignment.minimum_porters_wed !== undefined ||
    props.assignment.minimum_porters_thu !== undefined ||
    props.assignment.minimum_porters_fri !== undefined ||
    props.assignment.minimum_porters_sat !== undefined ||
    props.assignment.minimum_porters_sun !== undefined;
  
  if (hasAnyDaySpecificValues) {
    dayMinPorters.value = days.map(day => 
      props.assignment[day.field] !== undefined ? props.assignment[day.field] : props.assignment.minimum_porters || 1
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
    const defaultValue = props.assignment.minimum_porters || 1;
    sameForAllDaysValue.value = defaultValue;
    dayMinPorters.value = Array(7).fill(defaultValue);
  }
  
  // Initialize porter assignments
  const assignments = areaCoverStore.getPorterAssignmentsByAreaId(props.assignment.id);
  localPorterAssignments.value = assignments.map(pa => ({
    ...pa,
    start_time_display: pa.start_time ? pa.start_time.slice(0, 5) : '',
    end_time_display: pa.end_time ? pa.end_time.slice(0, 5) : ''
  }));
  
  // Clear the removed porters list
  removedPorterIds.value = [];
};

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

// Fetch porters if not already loaded
onMounted(async () => {
  if (staffStore.porters.length === 0) {
    await staffStore.fetchPorters();
  }
  
  initializeState();
});
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

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
    // Left side of footer
  }
  
  &-right {
    display: flex;
    gap: 12px;
  }
}

// Section title
.section-title {
  font-weight: 600;
  font-size: mix.font-size('md');
  margin-bottom: 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

// Department info
.department-info {
  margin-bottom: 12px;
  
  .department-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    
    .department-title {
      flex: 1;
    }
    
    .department-name {
      font-weight: 600;
      font-size: mix.font-size('lg');
    }
    
    .department-building {
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.6);
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

// Minimum porter settings
.min-porters-setting {
  display: flex;
  flex-direction: column;
  gap: 12px;
  
  .section-label {
    font-size: mix.font-size('sm');
    font-weight: 500;
    color: rgba(0, 0, 0, 0.7);
  }
  
  .day-toggle {
    margin-bottom: 4px;
    
    .toggle-label {
      display: flex;
      align-items: center;
      cursor: pointer;
      
      .toggle-text {
        margin-left: 8px;
        font-size: mix.font-size('sm');
      }
    }
  }
  
  .min-porters-input {
    display: flex;
    align-items: center;
    gap: 12px;
    
    .number-input {
      width: 60px;
      padding: 6px 8px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('md');
      text-align: center;
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
      }
    }
    
    .min-porters-description {
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.6);
    }
  }
  
  .days-grid {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 8px;
    
    @media (max-width: 600px) {
      grid-template-columns: repeat(4, 1fr);
    }
    
    @media (max-width: 400px) {
      grid-template-columns: repeat(2, 1fr);
    }
    
    .day-input {
      display: flex;
      flex-direction: column;
      align-items: center;
      
      label {
        font-weight: 500;
        margin-bottom: 4px;
        font-size: mix.font-size('sm');
      }
      
      input {
        width: 100%;
        padding: 6px 4px;
        text-align: center;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('sm');
        font-size: mix.font-size('md');
      }
    }
  }
}

// Color settings
.color-settings {
  display: flex;
  flex-direction: column;
  gap: 4px;
  
  label {
    font-size: mix.font-size('sm');
    font-weight: 500;
    color: rgba(0, 0, 0, 0.7);
  }
  
  input[type="color"] {
    height: 32px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: mix.radius('sm');
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
}

// Porter assignments
.porter-assignments {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.empty-state {
  padding: 12px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
  background-color: rgba(0, 0, 0, 0.03);
  border-radius: mix.radius('md');
}

.porter-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.porter-assignment-item {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: mix.radius('md');
  background-color: white;
  
  .porter-pill {
    min-width: 120px;
    margin-right: auto;
    
    .porter-name {
      display: inline-block;
      background-color: rgba(66, 133, 244, 0.1);
      color: mix.color('primary');
      border-radius: 100px;
      padding: 4px 12px;
      font-size: mix.font-size('sm');
      font-weight: 500;
      white-space: nowrap;
      cursor: pointer;
      position: relative;
      
      &.porter-absent {
        opacity: 0.9;
      }
      
      &.porter-illness {
        background-color: rgba(234, 67, 53, 0.15);
        color: #d32f2f;
      }
      
      &.porter-annual-leave {
        background-color: rgba(251, 192, 45, 0.2);
        color: #f57c00;
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
  }
  
  .porter-times {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-right: 8px;
    
    .time-group {
      input[type="time"] {
        padding: 4px 6px;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('sm');
        font-size: mix.font-size('sm');
      }
    }
    
    .time-separator {
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.6);
    }
  }
  
  .btn--icon {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    padding: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: rgba(0, 0, 0, 0.05);
    color: rgba(0, 0, 0, 0.6);
    
    &:hover {
      background-color: rgba(234, 67, 53, 0.1);
      color: #EA4335;
    }
  }
}

.add-porter {
  margin-top: 8px;
}

.add-porter-button {
  display: flex;
  justify-content: flex-end;
}

.add-porter-form {
  padding: 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: mix.radius('md');
  background-color: rgba(0, 0, 0, 0.02);
  
  .form-row {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    align-items: center;
    
    select {
      flex: 1;
      min-width: 150px;
      padding: 6px 8px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('sm');
    }
    
    .time-group {
      width: 90px;
      
      input[type="time"] {
        width: 100%;
        padding: 6px 8px;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('sm');
        font-size: mix.font-size('sm');
      }
    }
    
    .action-buttons {
      display: flex;
      gap: 8px;
    }
  }
  
  @media (max-width: 600px) {
    .form-row {
      flex-direction: column;
      align-items: stretch;
      
      select, .time-group {
        width: 100%;
      }
      
      .action-buttons {
        margin-top: 8px;
        justify-content: flex-end;
      }
    }
  }
}

// Coverage gap indicator
.coverage-gap-indicator {
  background-color: rgba(234, 67, 53, 0.1);
  color: #EA4335;
  font-size: mix.font-size('xs');
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 100px;
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.adjust(mix.color('primary'), $lightness: -5%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: #e5e5e5;
    }
  }
  
  &--danger {
    background-color: rgba(234, 67, 53, 0.1);
    color: #EA4335;
    
    &:hover:not(:disabled) {
      background-color: rgba(234, 67, 53, 0.2);
    }
  }
  
  &--small {
    padding: 4px 8px;
    font-size: mix.font-size('sm');
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
