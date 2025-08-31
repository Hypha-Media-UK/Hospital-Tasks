<template>
  <div class="modal-overlay" @click.stop="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">
          Edit {{ assignment.service.name }} Coverage
        </h3>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        
        <div class="time-range-container">
          <div class="form-group">
            <label for="edit-start-time">Start Time</label>
            <input 
              type="time"
              id="edit-start-time"
              v-model="editForm.startTime"
              class="form-control"
              required
            />
          </div>
          
          <div class="form-group">
            <label for="edit-end-time">End Time</label>
            <input 
              type="time"
              id="edit-end-time"
              v-model="editForm.endTime"
              class="form-control"
              required
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
        
        <!-- Porter Assignments Section -->
        <div class="porter-assignments">
          <h4 class="section-title">Porter Assignments</h4>
          
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
                <div 
                  class="porter-name" 
                  :class="{
                    'porter-absent': staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date()),
                    'porter-illness': staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date())?.absence_type === 'illness',
                    'porter-annual-leave': staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date())?.absence_type === 'annual_leave'
                  }"
                  @click="openAbsenceModal(assignment.porter_id)"
                >
                  {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
                  <span v-if="staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date())?.absence_type === 'illness'" 
                        class="absence-badge illness">ILL</span>
                  <span v-if="staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date())?.absence_type === 'annual_leave'" 
                        class="absence-badge annual-leave">AL</span>
                </div>
                <div class="porter-time">
                  {{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
                </div>
              </div>
              
              <div class="porter-actions">
                <button 
                  @click.stop="removePorterAssignment(assignment.id)"
                  class="btn btn--icon btn--danger"
                  title="Remove porter assignment"
                >
                  <TrashIcon />
                </button>
              </div>
            </div>
          </div>
          
        </div>
      </div>
      
      <div class="modal-footer">
        <button 
          @click.stop="confirmDelete" 
          class="btn btn--danger"
        >
          Remove Service
        </button>
        <button 
          @click.stop="$emit('close')" 
          class="btn btn--secondary"
        >
          Cancel
        </button>
        <button 
          @click.stop="saveChanges" 
          class="btn btn--primary ml-auto"
          :disabled="saving || !isFormValid"
        >
          {{ saving ? 'Saving...' : 'Save Changes' }}
        </button>
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
    ></PorterAbsenceModal>
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useShiftsStore } from '../../stores/shiftsStore';
import { useStaffStore } from '../../stores/staffStore';
import PorterAbsenceModal from '../PorterAbsenceModal.vue';
import TrashIcon from '../icons/TrashIcon.vue';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'update', 'remove']);

const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();

// Form state
const editForm = ref({
  startTime: '',
  endTime: '',
  minimumPorters: 1
});

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
const saving = ref(false);
const showAbsenceModal = ref(false);
const selectedPorterId = ref(null);
const currentPorterAbsence = ref(null);

// Computed
const isFormValid = computed(() => {
  return editForm.value.startTime && editForm.value.endTime;
});

// Get porter assignments for this service
const porterAssignments = computed(() => {
  return shiftsStore.getPorterAssignmentsByServiceId(props.assignment.id) || [];
});

// Check if there's a coverage gap
const hasCoverageGap = computed(() => {
  return shiftsStore.hasServiceCoverageGap(props.assignment.id);
});

// Check if there's a staffing shortage
const hasStaffingShortage = computed(() => {
  return shiftsStore.hasServiceStaffingShortage?.(props.assignment.id) || false;
});


// Initialize form with assignment data
onMounted(() => {
  // Format time from HH:MM:SS to HH:MM for input
  const formatTime = (timeStr) => {
    if (!timeStr) return '';
    return timeStr.substring(0, 5); // Gets only HH:MM part
  };
  
  editForm.value = {
    startTime: formatTime(props.assignment.start_time) || '',
    endTime: formatTime(props.assignment.end_time) || '',
    minimumPorters: props.assignment.minimum_porters || 1
  };
  
  // Initialize minimum porter count (for backwards compatibility)
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
});

// Save changes
async function saveChanges() {
  if (!isFormValid.value || saving.value) return;
  
  saving.value = true;
  
  try {
    // Prepare update object with basic properties
    const updates = {
      start_time: editForm.value.startTime + ':00', // Add seconds for database format
      end_time: editForm.value.endTime + ':00',
      minimum_porters: parseInt(sameForAllDaysValue.value) || 0
    };
    
    // Add day-specific minimum porter counts
    days.forEach((day, index) => {
      updates[day.field] = parseInt(dayMinPorters.value[index]) || 0;
    });
    
    // Emit update event
    emit('update', props.assignment.id, updates);
    
    // Close the modal after successful save
    emit('close');
  } catch (error) {
    console.error('Error saving service assignment:', error);
  } finally {
    saving.value = false;
  }
}

// Delete service assignment
function confirmDelete() {
  if (confirm(`Are you sure you want to remove "${props.assignment.service.name}" from this shift?`)) {
    emit('remove', props.assignment.id);
  }
}


async function removePorterAssignment(assignmentId) {
  if (confirm('Are you sure you want to remove this porter assignment?')) {
    await shiftsStore.removeShiftSupportServicePorter(assignmentId);
  }
}

// Helper methods
function formatTime(timeStr) {
  if (!timeStr) return '';
  return timeStr.substring(0, 5); // Extract HH:MM from HH:MM:SS
}

// Open absence modal for a specific porter
function openAbsenceModal(porterId) {
  if (!porterId) return;
  
  selectedPorterId.value = porterId;
  const today = new Date();
  currentPorterAbsence.value = staffStore.getPorterAbsenceDetails(porterId, today);
  showAbsenceModal.value = true;
}

// Handle absence save
function handleAbsenceSave() {
  // Refresh the absence data
  currentPorterAbsence.value = null;
}

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
}

.time-range-container {
  display: flex;
  gap: 16px;
  
  .form-group {
    flex: 1;
    margin-bottom: 16px;
  }
}

// Minimum porter settings
.min-porters-setting {
  margin-bottom: 20px;
  
  .section-label {
    display: block;
    margin-bottom: 12px;
    font-weight: 500;
  }
  
  .day-toggle {
    margin-bottom: 8px;
    
    .toggle-label {
      display: flex;
      align-items: center;
      cursor: pointer;
      
      .toggle-text {
        margin-left: 8px;
        font-size: 0.9rem;
      }
    }
  }
  
  .min-porters-input {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-top: 8px;
    
    .number-input {
      width: 60px;
      padding: 6px 8px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      font-size: 1rem;
      text-align: center;
    }
    
    .min-porters-description {
      font-size: 0.9rem;
      color: rgba(0, 0, 0, 0.6);
    }
  }
  
  .days-grid {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 8px;
    margin-top: 8px;
    
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
        font-size: 0.8rem;
      }
      
      input {
        width: 100%;
        padding: 6px 4px;
        text-align: center;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('sm');
        font-size: 0.9rem;
      }
    }
  }
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
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.2);
    }
  }
  
  .static-field {
    padding: 8px 12px;
    background-color: rgba(0, 0, 0, 0.05);
    border-radius: mix.radius('md');
    font-weight: 500;
  }
}

// Button styles
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
  max-width: 550px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
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

.button-container {
  display: flex;
  justify-content: flex-end;
  width: 100%;
}

.porter-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: mix.radius('md');
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.04);
  }
}

.porter-info {
  display: flex;
  align-items: center;
  gap: 12px;
  
  .porter-name {
    font-weight: 500;
    font-size: mix.font-size('sm');
    cursor: pointer;
    position: relative;
    display: inline-block;
    border-radius: mix.radius('sm');
    padding: 2px 6px;
    
    &.porter-absent {
      opacity: 0.9;
    }
    
    &.porter-illness {
      color: #d32f2f;
      background-color: rgba(234, 67, 53, 0.1);
    }
    
    &.porter-annual-leave {
      color: #f57c00;
      background-color: rgba(251, 192, 45, 0.1);
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
  
  .porter-time {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
    background-color: rgba(0, 0, 0, 0.05);
    padding: 2px 6px;
    border-radius: mix.radius('sm');
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

.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  /* Make SVG icons black */
  :deep(svg) {
    color: #000;
  }
  
  &--primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: rgba(66, 133, 244, 0.8);
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
    background-color: #EA4335;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#EA4335, $lightness: -10%);
    }
  }
  
  &--sm {
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
