<template>
  <BaseModal
    :title="`${assignment.department.name} Coverage`"
    size="large"
    @close="closeModal"
  >

    <!-- Department Time settings -->
    <div class="modal-form-section time-settings">
      <div class="form-group">
        <label for="startTime">Start Time</label>
        <input
          type="time"
          id="startTime"
          v-model="localStartTime"
          class="form-control"
        />
      </div>

      <div class="form-group">
        <label for="endTime">End Time</label>
        <input
          type="time"
          id="endTime"
          v-model="localEndTime"
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

    <!-- Porter Assignments -->
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
                class="form-control"
              />
            </div>
            <span class="time-separator">to</span>
            <div class="time-group">
              <input
                type="time"
                v-model="porterAssignment.end_time_display"
                class="form-control"
              />
            </div>
          </div>

          <button
            class="btn btn--icon"
            title="Remove porter assignment"
            @click.stop="removeLocalPorterAssignment(index)"
          >
            <TrashIcon :size="16" />
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
            <select v-model="newPorterAssignment.porter_id" class="form-control">
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
                class="form-control"
              />
            </div>

            <div class="time-group">
              <input
                type="time"
                v-model="newPorterAssignment.end_time"
                placeholder="End Time"
                class="form-control"
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
        @click.stop="confirmRemove"
      >
        Remove Department
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
import { ref, computed, onMounted, reactive } from 'vue';
import { useAreaCoverStore } from '../../stores/areaCoverStore';
import { useStaffStore } from '../../stores/staffStore';
import { useSettingsStore } from '../../stores/settingsStore';
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

const areaCoverStore = useAreaCoverStore();
const staffStore = useStaffStore();
const settingsStore = useSettingsStore();

// Local state for all editable properties
const localStartTime = ref('');
const localEndTime = ref('');
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

// Helper function to convert time string to minutes
const timeToMinutes = (timeStr) => {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
};

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
  // Initialize times - handle both Date objects and strings
  if (props.assignment.start_time) {
    localStartTime.value = formatTimeForInput(props.assignment.start_time);
  }
  
  if (props.assignment.end_time) {
    localEndTime.value = formatTimeForInput(props.assignment.end_time);
  }
  
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
  
  // Initialize porter assignments - use unique assignments to avoid duplicates
  const assignments = areaCoverStore.getUniquePorterAssignmentsByAreaId(props.assignment.id);
  localPorterAssignments.value = assignments.map(pa => ({
    ...pa,
    start_time_display: pa.start_time ? formatTimeForInput(pa.start_time) : '',
    end_time_display: pa.end_time ? formatTimeForInput(pa.end_time) : ''
  }));
  
  // Clear the removed porters list
  removedPorterIds.value = [];
};


// Helper function to format time for input fields
function formatTimeForInput(timeValue) {
  if (!timeValue) return '';
  
  // Handle Date objects (from MySQL/Prisma) - these are TIME fields stored as Date objects
  if (timeValue instanceof Date) {
    // Extract just the time part (date part is irrelevant, usually 1970-01-01)
    const hours = String(timeValue.getHours()).padStart(2, '0');
    const minutes = String(timeValue.getMinutes()).padStart(2, '0');
    return `${hours}:${minutes}`;
  }
  
  // Handle ISO datetime strings (e.g., "1970-01-01T08:00:00.000Z")
  if (typeof timeValue === 'string' && timeValue.includes('T')) {
    const date = new Date(timeValue);
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${hours}:${minutes}`;
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