<template>
  <div class="modal-overlay" @click.stop="closeModal">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">Edit {{ assignment.service.name }}</h3>
        <button class="modal-close" @click.stop="closeModal">&times;</button>
      </div>
      
      <div class="modal-body">
        <div class="service-info">
          <div class="service-header">
            <div class="service-title">
              <div class="service-name">{{ assignment.service.name }}</div>
              <div v-if="assignment.service.description" class="service-description">
                {{ assignment.service.description }}
              </div>
            </div>
            <input 
              type="color" 
              id="color" 
              v-model="localColor" 
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
                <span class="porter-name">
                  {{ porterAssignment.porter.first_name }} {{ porterAssignment.porter.last_name }}
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
</template>

<script setup>
import { ref, computed, onMounted, reactive } from 'vue';
import { useShiftsStore } from '../../stores/shiftsStore';
import { useStaffStore } from '../../stores/staffStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'update', 'remove']);

const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const supportServicesStore = useSupportServicesStore();

// Determine if this is a shift-specific assignment or a default assignment
const isShiftAssignment = computed(() => !!props.assignment.shift_id);

// Local state for all editable properties
const localStartTime = ref('');
const localEndTime = ref('');
const localColor = ref('#4285F4');
const localPorterAssignments = ref([]);
const showAddPorter = ref(false);
const removedPorterIds = ref([]);

const newPorterAssignment = ref({
  porter_id: '',
  start_time: '',
  end_time: ''
});

// Computed property for determining what porters are available
const availablePorters = computed(() => {
  // Get all porters from the staff store
  const allPorters = staffStore.sortedPorters || [];
  
  // Filter out porters that are already in our local assignments
  const assignedPorterIds = localPorterAssignments.value
    .filter(pa => !pa.isRemoved)
    .map(pa => pa.porter_id);
  
  return allPorters.filter(porter => !assignedPorterIds.includes(porter.id));
});

// Check for coverage gaps with local data
const hasLocalCoverageGap = computed(() => {
  if (localPorterAssignments.value.length === 0) return true;
  
  // Only consider non-removed assignments
  const activeAssignments = localPorterAssignments.value.filter(pa => !pa.isRemoved);
  if (activeAssignments.length === 0) return true;
  
  // Convert service times to minutes for easier comparison
  const serviceStart = timeToMinutes(localStartTime.value + ':00');
  const serviceEnd = timeToMinutes(localEndTime.value + ':00');
  
  // First check if any single porter covers the entire time period
  const fullCoverageExists = activeAssignments.some(assignment => {
    const porterStart = timeToMinutes(assignment.start_time_display + ':00');
    const porterEnd = timeToMinutes(assignment.end_time_display + ':00');
    return porterStart <= serviceStart && porterEnd >= serviceEnd;
  });
  
  // If at least one porter provides full coverage, there's no gap
  if (fullCoverageExists) {
    return false;
  }
  
  // Sort porter assignments by start time
  const sortedAssignments = [...activeAssignments].sort((a, b) => {
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
    // Mark as removed instead of actually removing (for UI only)
    assignment.isRemoved = true;
  } else {
    // For new assignments that haven't been saved yet, just remove from array
    localPorterAssignments.value.splice(index, 1);
  }
};

const saveAllChanges = async () => {
  try {
    // 1. Update service assignment (times, color)
    if (isShiftAssignment.value) {
      // For shift-specific assignments
      await shiftsStore.updateShiftSupportService(props.assignment.id, {
        start_time: localStartTime.value + ':00',
        end_time: localEndTime.value + ':00',
        color: localColor.value
      });
    } else {
      // For default service settings
      await supportServicesStore.updateServiceAssignment(props.assignment.id, {
        start_time: localStartTime.value + ':00',
        end_time: localEndTime.value + ':00',
        color: localColor.value
      });
    }
    
    // 2. Process porter assignments - removals
    for (const porterId of removedPorterIds.value) {
      if (isShiftAssignment.value) {
        // For shift-specific assignments
        await shiftsStore.removeShiftSupportServicePorter(porterId);
      } else {
        // For default service settings
        await supportServicesStore.removePorterAssignment(porterId);
      }
    }
    
    // 3. Process porter assignments - additions and updates
    for (const assignment of localPorterAssignments.value) {
      // Skip removed assignments
      if (assignment.isRemoved) continue;
      
      if (assignment.isNew) {
        // Add new assignment
        if (isShiftAssignment.value) {
          // For shift-specific assignments
          await shiftsStore.addShiftSupportServicePorter(
            props.assignment.id,
            assignment.porter_id,
            assignment.start_time,
            assignment.end_time
          );
        } else {
          // For default service settings
          await supportServicesStore.addPorterToServiceAssignment(
            props.assignment.id,
            assignment.porter_id,
            assignment.start_time,
            assignment.end_time
          );
        }
      } else {
        // Update existing assignment
        if (isShiftAssignment.value) {
          // For shift-specific assignments
          await shiftsStore.updateShiftSupportServicePorter(assignment.id, {
            start_time: assignment.start_time_display + ':00',
            end_time: assignment.end_time_display + ':00'
          });
        } else {
          // For default service settings
          await supportServicesStore.updatePorterAssignment(assignment.id, {
            start_time: assignment.start_time_display + ':00',
            end_time: assignment.end_time_display + ':00'
          });
        }
      }
    }
    
    // Emit the update event
    emit('update', props.assignment.id, {
      start_time: localStartTime.value + ':00',
      end_time: localEndTime.value + ':00',
      color: localColor.value
    });
    
    // Close the modal
    closeModal();
  } catch (error) {
    console.error('Error saving changes:', error);
    alert('Failed to save changes. Please try again.');
  }
};

const confirmRemove = () => {
  if (confirm(`Are you sure you want to remove ${props.assignment.service.name} from coverage?`)) {
    emit('remove', props.assignment.id);
  }
};

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

// Initialize component state from props
const initializeState = async () => {
  // Initialize times
  if (props.assignment.start_time) {
    localStartTime.value = props.assignment.start_time.slice(0, 5);
  }
  
  if (props.assignment.end_time) {
    localEndTime.value = props.assignment.end_time.slice(0, 5);
  }
  
  // Initialize color
  localColor.value = props.assignment.color || '#4285F4';
  
  // Initialize porter assignments - use the appropriate store based on assignment type
  let assignments = [];
  
  if (isShiftAssignment.value) {
    // For shift-specific assignments
    assignments = shiftsStore.getPorterAssignmentsByServiceId(props.assignment.id) || [];
  } else {
    // For default service settings
    assignments = supportServicesStore.getPorterAssignmentsByServiceId(props.assignment.id) || [];
  }
  
  localPorterAssignments.value = assignments.map(pa => ({
    ...pa,
    start_time_display: pa.start_time ? pa.start_time.slice(0, 5) : '',
    end_time_display: pa.end_time ? pa.end_time.slice(0, 5) : '',
    isRemoved: false
  }));
  
  // Clear the removed porters list
  removedPorterIds.value = [];
};

// Fetch porters if not already loaded
onMounted(async () => {
  if (staffStore.porters.length === 0) {
    await staffStore.fetchPorters();
  }
  
  await initializeState();
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

// Service info
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
      font-weight: 600;
      font-size: mix.font-size('lg');
    }
    
    .service-description {
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
      background-color: color.adjust(#f1f1f1, $lightness: -5%);
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
