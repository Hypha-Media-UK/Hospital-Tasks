<template>
  <BaseModal
    :title="`Edit ${assignment.service.name} Coverage`"
    size="large"
    @close="$emit('close')"
  >
        
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

    <template #footer>
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
    </template>
  </BaseModal>
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
import BaseModal from '../shared/BaseModal.vue';
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

<!-- Styles are now handled by the global CSS layers -->