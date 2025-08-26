<template>
  <BaseModal
    :title="`Edit ${assignment.department.name} Coverage`"
    size="large"
    @close="$emit('close')"
  >
        <!-- Department Time settings -->
        <div class="modal-form-section time-settings">
          <div class="form-group">
            <label for="start-time">Start Time</label>
            <input
              type="time"
              id="start-time"
              v-model="formData.startTime"
              class="form-control"
            />
          </div>

          <div class="form-group">
            <label for="end-time">End Time</label>
            <input
              type="time"
              id="end-time"
              v-model="formData.endTime"
              class="form-control"
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
                class="form-control"
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
                class="form-control"
              />
            </div>
          </div>
        </div>
        
        <!-- Porter Assignments Section -->
        <div class="porter-assignments">
          <h4 class="section-title">Porter Assignments</h4>

          <div v-if="porterAssignments.length === 0" class="empty-state">
            No porters assigned to this department yet.
          </div>

          <div v-else class="porter-list">
            <div
              v-for="assignment in porterAssignments"
              :key="assignment.id"
              class="porter-item"
            >
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

              <button
                @click="removePorterAssignment(assignment.id)"
                class="btn btn--icon"
                title="Remove porter assignment"
              >
                <TrashIcon :size="16" />
              </button>
            </div>
          </div>
        </div>

    <template #footer>
      <button
        @click.stop="confirmRemove"
        class="btn btn--danger"
      >
        Remove Department
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
        :disabled="saving"
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
    />
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

// Form data for the department
const formData = ref({
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

// UI state
const saving = ref(false);
const showAbsenceModal = ref(false);
const selectedPorterId = ref(null);
const currentPorterAbsence = ref(null);


// Computed properties
const porterAssignments = computed(() => {
  return shiftsStore.getPorterAssignmentsByAreaId(props.assignment.id) || [];
});

const hasCoverageGap = computed(() => {
  return shiftsStore.hasAreaCoverageGap(props.assignment.id);
});



  // Initialize form data
onMounted(async () => {
  // Load department data
  formData.value = {
    startTime: props.assignment.start_time ? props.assignment.start_time.substring(0, 5) : '08:00',
    endTime: props.assignment.end_time ? props.assignment.end_time.substring(0, 5) : '16:00',
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
  
  // Load porters if not already loaded
  if (!staffStore.porters.length) {
    await staffStore.fetchPorters();
  }
});

// Check if there's a staffing shortage
const hasStaffingShortage = computed(() => {
  return shiftsStore.hasAreaStaffingShortage?.(props.assignment.id) || false;
});


// Methods
const saveChanges = async () => {
  saving.value = true;
  
  try {
    // Format times for storage (add seconds)
    const startTime = formData.value.startTime + ':00';
    const endTime = formData.value.endTime + ':00';
    
    // Create update data object with day-specific minimum porter counts
    const updateData = {
      start_time: startTime,
      end_time: endTime,
      minimum_porters: parseInt(sameForAllDaysValue.value) || 0
    };
    
    // Add day-specific minimum porter counts
    days.forEach((day, index) => {
      updateData[day.field] = parseInt(dayMinPorters.value[index]) || 0;
    });
    
    // Update department assignment - use shift-specific update method
    await shiftsStore.updateShiftAreaCover(props.assignment.id, updateData);
    
    emit('update', props.assignment.id, {
      start_time: startTime,
      end_time: endTime
    });
    
    emit('close');
  } catch (error) {
    console.error('Error saving changes:', error);
  } finally {
    saving.value = false;
  }
};

const confirmRemove = () => {
  if (confirm(`Are you sure you want to remove ${props.assignment.department.name} from coverage?`)) {
    emit('remove', props.assignment.id);
  }
};

// Open absence modal for a specific porter
const openAbsenceModal = (porterId) => {
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



const removePorterAssignment = async (assignmentId) => {
  if (confirm('Are you sure you want to remove this porter assignment?')) {
    try {
      // Use shift-specific method to remove porter assignment
      await shiftsStore.removeShiftAreaCoverPorter(assignmentId);
    } catch (error) {
      console.error('Error removing porter assignment:', error);
    }
  }
};

// Helper methods
const formatTime = (timeStr) => {
  if (!timeStr) return '';
  return timeStr.substring(0, 5); // Extract HH:MM from HH:MM:SS
};

</script>

<!-- Styles are now handled by the global CSS layers -->