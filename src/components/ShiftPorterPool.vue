<template>
  <div class="shift-porter-pool">
    <!-- Loading Overlay -->
    <div v-if="isLoading" class="loading-overlay">
      <div class="spinner"></div>
      <div class="loading-text">Loading shift data...</div>
    </div>
    
    <div v-if="shiftsStore.loading.porterPool" class="loading">
      Loading shift porters...
    </div>
    
    <div v-else-if="sortedPorterPool.length === 0 && supervisors.length === 0" class="empty-state">
      <p>No porters assigned to this shift yet. Click "Add Porter" to get started.</p>
      <button class="btn btn--primary" @click="openPorterSelector" style="margin-top: 16px;">
        Add Porter
      </button>
    </div>
    
    <!-- Supervisors Section -->
    <div v-if="supervisors.length > 0" class="supervisors-section">
      <h4 class="section-title">Supervisors</h4>
      <div class="porter-grid">
      <div v-for="entry in supervisors" :key="entry.id" class="porter-card supervisor-card"
           :class="{
             'available': isPorterAvailable(entry.porter_id),
             'assigned': hasActiveAssignments(entry.porter_id),
             'scheduled-absence': staffStore.isPorterOnScheduledAbsence(entry.porter_id),
             'not-yet-on-duty': getPorterDutyStatus(entry.porter_id) === 'not-yet-on-duty',
             'off-duty': getPorterDutyStatus(entry.porter_id) === 'off-duty'
           }"
             @click.stop="openAllocationModal(entry.porter)">
          <div class="porter-card__content">
            <div class="porter-card__name" 
                 :class="{ 
                   'porter-absent': isPorterAbsent(entry.porter_id),
                   'porter-illness': getPorterAbsenceType(entry.porter_id) === 'illness',
                   'porter-annual-leave': getPorterAbsenceType(entry.porter_id) === 'annual_leave',
                   'porter-scheduled-absence': staffStore.isPorterOnScheduledAbsence(entry.porter_id)
                 }">
              {{ entry.porter.first_name }} {{ entry.porter.last_name }}
              <span v-if="getPorterAbsenceType(entry.porter_id) === 'illness'" class="absence-badge illness">ILL</span>
              <span v-if="getPorterAbsenceType(entry.porter_id) === 'annual_leave'" class="absence-badge annual-leave">AL</span>
              <span v-if="staffStore.isPorterOnScheduledAbsence(entry.porter_id)" class="absence-badge scheduled">ABSENCE</span>
            </div>
            
            <div class="porter-card__assignments">
              <div v-if="getPorterAssignments(entry.porter_id).length > 0" class="assignments-list">
                <div v-for="assignment in getPorterAssignments(entry.porter_id)" :key="assignment.id" 
                     class="assignment-item clickable" 
                     :style="{ backgroundColor: getAssignmentBackgroundColor(assignment) }"
                     @click.stop="editAssignment(entry.porter, assignment)"
                     :title="'Click to edit assignment times'">
                  <span class="assignment-text">
                    {{ getAssignmentName(assignment) }}: {{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
                  </span>
                  <div class="assignment-actions">
                    <EditIcon :size="12" class="edit-icon" />
                    <TrashIcon :size="12" class="remove-icon" @click.stop="removeAssignment(entry.porter, assignment)" />
                  </div>
                </div>
              </div>
              <div v-else class="assignments-list">
                <div class="assignment-item" style="background-color: rgba(128, 128, 128, 0.15);">
                  Runner
                </div>
              </div>
            </div>
          </div>
          
          <!-- No remove button for supervisors -->
          <div class="porter-card__actions">
            <div class="supervisor-indicator" title="Supervisors cannot be manually removed">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M9 12l2 2 4-4"></path>
                <circle cx="12" cy="12" r="9"></circle>
              </svg>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Add Porter Button (always available when there are supervisors but no regular porters) -->
    <div v-if="supervisors.length > 0 && sortedPorterPool.length === 0" class="add-porter-section">
      <div class="add-porter-controls">
        <button class="btn btn--primary" @click="openPorterSelector">
          Add Porter
        </button>
      </div>
    </div>

    <!-- Regular Porters Section -->
    <div v-if="sortedPorterPool.length > 0" class="porters-section">
      <h4 v-if="supervisors.length > 0" class="section-title">Porters</h4>

      <!-- Filter controls with Add Porter button -->
      <div class="filter-controls">
        <div class="filter-left">
          <div class="filter-label">Sort by:</div>
          <div class="filter-options">
            <button
              class="filter-btn"
              :class="{ active: sortFilter === 'alphabetical' }"
              @click="sortFilter = 'alphabetical'"
            >
              A-Z
            </button>
            <button
              class="filter-btn"
              :class="{ active: sortFilter === 'available' }"
              @click="sortFilter = 'available'"
            >
              Available
            </button>
          </div>
        </div>

        <button class="btn btn--primary" @click="openPorterSelector">
          Add Porter
        </button>
      </div>
    
    <div v-if="sortedPorterPool.length > 0" class="porter-grid">
      <div v-for="entry in sortedPorterPool" :key="entry.id" class="porter-card"
           :class="{
             'available': isPorterAvailable(entry.porter_id),
             'assigned': hasActiveAssignments(entry.porter_id),
             'scheduled-absence': staffStore.isPorterOnScheduledAbsence(entry.porter_id),
             'not-yet-on-duty': getPorterDutyStatus(entry.porter_id) === 'not-yet-on-duty',
             'off-duty': getPorterDutyStatus(entry.porter_id) === 'off-duty'
           }"
           @click.stop="openAllocationModal(entry.porter)">
        <div class="porter-card__content">
          <div class="porter-card__name" 
               :class="{ 
                 'porter-absent': isPorterAbsent(entry.porter_id),
                 'porter-illness': getPorterAbsenceType(entry.porter_id) === 'illness',
                 'porter-annual-leave': getPorterAbsenceType(entry.porter_id) === 'annual_leave',
                 'porter-scheduled-absence': staffStore.isPorterOnScheduledAbsence(entry.porter_id)
               }">
            {{ entry.porter.first_name }} {{ entry.porter.last_name }}
            <span v-if="getPorterAbsenceType(entry.porter_id) === 'illness'" class="absence-badge illness">ILL</span>
            <span v-if="getPorterAbsenceType(entry.porter_id) === 'annual_leave'" class="absence-badge annual-leave">AL</span>
            <span v-if="staffStore.isPorterOnScheduledAbsence(entry.porter_id)" class="absence-badge scheduled">ABSENCE</span>
          </div>
          
          <div class="porter-card__assignments">
            <div v-if="getPorterAssignments(entry.porter_id).length > 0" class="assignments-list">
              <div v-for="assignment in getPorterAssignments(entry.porter_id)" :key="assignment.id" 
                   class="assignment-item clickable" 
                   :style="{ backgroundColor: getAssignmentBackgroundColor(assignment) }"
                   @click.stop="editAssignment(entry.porter, assignment)"
                   :title="'Click to edit assignment times'">
                <span class="assignment-text">
                  {{ getAssignmentName(assignment) }}: {{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
                </span>
                <div class="assignment-actions">
                  <EditIcon :size="12" class="edit-icon" />
                  <TrashIcon :size="12" class="remove-icon" @click.stop="removeAssignment(entry.porter, assignment)" />
                </div>
              </div>
            </div>
            <div v-else class="assignments-list">
              <div class="assignment-item" style="background-color: rgba(128, 128, 128, 0.15);">
                Runner
              </div>
            </div>
            
            <!-- Serviced Buildings Section -->
            <div v-if="locationsStore.porterServicedBuildings.length > 0" class="serviced-buildings-section">
              <div class="serviced-buildings-list">
                <button 
                  v-for="building in locationsStore.porterServicedBuildings" 
                  :key="building.id"
                  @click.stop="togglePorterBuildingAssignment(entry.porter_id, building.id)"
                  class="building-badge"
                  :class="{ 'assigned': isPorterAssignedToBuilding(entry.porter_id, building.id) }"
                  :title="`Click to ${isPorterAssignedToBuilding(entry.porter_id, building.id) ? 'unassign from' : 'assign to'} ${building.name}`"
                >
                  {{ building.abbreviation || building.name }}
                </button>
              </div>
              
              <div class="porter-card__actions">
                <button
                  @click.stop="removePorter(entry.id)"
                  class="btn btn--icon btn--danger"
                  title="Remove porter from shift"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M3 6h18"></path>
                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    </div>
    
    <!-- Allocation Modal -->
    <AllocatePorterModal 
      v-if="showAllocationModal" 
      :porter="selectedPorter"
      :shift-id="shiftId"
      :editing-assignment="editingAssignment"
      @close="showAllocationModal = false"
      @allocated="handlePorterAllocated"
    />
    
    <!-- Porter Selector Modal -->
    <div v-if="showPorterSelector" class="modal-overlay" @click.self="showPorterSelector = false">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">Add Porters to Shift</h3>
          <button class="modal-close" @click="showPorterSelector = false">&times;</button>
        </div>
        
        <div class="modal-body">
          <div v-if="availablePorters.length === 0" class="empty-state">
            No porters available to add. All porters are already assigned to this shift, are absent, or are assigned to departments in settings.
          </div>
          
          <div v-else class="porter-selector">
            <div class="select-all-container">
              <label class="checkbox-container">
                <input 
                  type="checkbox" 
                  :checked="isAllSelected" 
                  @change="toggleSelectAll"
                >
                <span class="checkmark"></span>
                <span class="select-all-text">Select All Porters</span>
              </label>
              <span v-if="selectedPorters.length > 0" class="selected-count">
                {{ selectedPorters.length }} porter{{ selectedPorters.length > 1 ? 's' : '' }} selected
              </span>
            </div>
            
            <div v-for="porter in availablePorters" :key="porter.id" class="porter-item">
              <label class="checkbox-container">
                <input 
                  type="checkbox" 
                  :value="porter.id" 
                  v-model="selectedPorters"
                >
                <span class="checkmark"></span>
              </label>
              <div class="porter-name">{{ porter.first_name }} {{ porter.last_name }}</div>
            </div>
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            class="btn btn--secondary" 
            @click="showPorterSelector = false"
          >
            Cancel
          </button>
          <button 
            class="btn btn--primary" 
            @click="addSelectedPorters"
            :disabled="selectedPorters.length === 0 || addingPorters"
          >
            {{ addingPorters ? 'Adding...' : 'Add Selected Porters' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useAreaCoverStore } from '../stores/areaCoverStore';
import { useSettingsStore } from '../stores/settingsStore';
import { useLocationsStore } from '../stores/locationsStore';
import { useSupportServicesStore } from '../stores/supportServicesStore';
import AllocatePorterModal from './AllocatePorterModal.vue';
import EditIcon from './icons/EditIcon.vue';
import TrashIcon from './icons/TrashIcon.vue';

// Event for opening allocation modal
const emits = defineEmits(['openAllocationModal']);

const props = defineProps({
  shiftId: {
    type: String,
    required: true
  }
});

const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const areaCoverStore = useAreaCoverStore();
const settingsStore = useSettingsStore();
const locationsStore = useLocationsStore();
const supportServicesStore = useSupportServicesStore();

const showPorterSelector = ref(false);
const showAllocationModal = ref(false);
const selectedPorter = ref(null);
const editingAssignment = ref(null);
const sortFilter = ref('alphabetical'); // Default to alphabetical sorting

// Force reactivity when sort filter changes
watch(sortFilter, () => {
  // This will trigger re-computation of sortedPorterPool
}, { immediate: true });

// Expose showPorterSelector method to parent
const openPorterSelector = () => {
  showPorterSelector.value = true;
};

// Expose necessary methods to parent
defineExpose({
  openPorterSelector
});

// Open allocation modal for a porter
const openAllocationModal = (porter) => {
  // Open the modal directly instead of emitting an event
  selectedPorter.value = porter;
  editingAssignment.value = null; // Clear any editing assignment
  showAllocationModal.value = true;
};

// Edit an assignment
const editAssignment = (porter, assignment) => {
  selectedPorter.value = porter;
  editingAssignment.value = assignment;
  showAllocationModal.value = true;
};

// Handle when a porter has been allocated
const handlePorterAllocated = (allocation) => {
  // If this was an absence allocation, we need to refresh porter absences
  if (allocation.type === 'absence') {
    shiftsStore.fetchShiftPorterAbsences(props.shiftId);
  }
  // No need to do anything else - the store and UI will update automatically for other allocations
};
const selectedPorters = ref([]);
const addingPorters = ref(false);
const isLoading = ref(true);


// Computed properties
const porterPool = computed(() => {
  return shiftsStore.shiftPorterPool || [];
});

// Separate supervisors and regular porters
const supervisors = computed(() => {
  if (!porterPool.value.length) return [];
  
  return porterPool.value
    .filter(p => p.is_supervisor)
    .sort((a, b) => {
      return `${a.porter.first_name} ${a.porter.last_name}`.localeCompare(
        `${b.porter.first_name} ${b.porter.last_name}`
      );
    });
});

const regularPorters = computed(() => {
  if (!porterPool.value.length) return [];
  
  return porterPool.value.filter(p => !p.is_supervisor);
});

// Sorted porter pool based on selected filter (excluding supervisors)
const sortedPorterPool = computed(() => {
  if (!regularPorters.value.length) return [];

  const porters = [...regularPorters.value];

  if (sortFilter.value === 'alphabetical') {
    // Sort alphabetically by name (first name + last name)
    return porters.sort((a, b) => {
      const aName = `${a.porter.first_name} ${a.porter.last_name}`;
      const bName = `${b.porter.first_name} ${b.porter.last_name}`;
      return aName.localeCompare(bName);
    });
  } else if (sortFilter.value === 'available') {
    // Sort by availability priority: Available > Allocated > Absent/Off-duty
    return porters.sort((a, b) => {
      // Get status for porter A
      const aAvailable = isPorterAvailable.value(a.porter_id);
      const aAssigned = hasActiveAssignments.value(a.porter_id);
      const aAbsent = isPorterAbsent(a.porter_id);
      const aDutyStatus = getPorterDutyStatus(a.porter_id);

      // Get status for porter B
      const bAvailable = isPorterAvailable.value(b.porter_id);
      const bAssigned = hasActiveAssignments.value(b.porter_id);
      const bAbsent = isPorterAbsent(b.porter_id);
      const bDutyStatus = getPorterDutyStatus(b.porter_id);

      // Determine priority levels (lower number = higher priority)
      const getPriority = (available, assigned, absent, dutyStatus) => {
        // Priority 1: Available (on duty, not assigned, not absent)
        if (available && !assigned && !absent && dutyStatus === 'on-duty') {
          return 1;
        }
        // Priority 2: Allocated (assigned to something but on duty)
        else if (assigned && !absent && dutyStatus === 'on-duty') {
          return 2;
        }
        // Priority 3: Unavailable (absent or off duty)
        else {
          return 3;
        }
      };

      const aPriority = getPriority(aAvailable, aAssigned, aAbsent, aDutyStatus);
      const bPriority = getPriority(bAvailable, bAssigned, bAbsent, bDutyStatus);

      // Sort by priority first
      if (aPriority !== bPriority) {
        return aPriority - bPriority;
      }

      // For porters with the same priority, sort alphabetically
      const aName = `${a.porter.first_name} ${a.porter.last_name}`;
      const bName = `${b.porter.first_name} ${b.porter.last_name}`;
      return aName.localeCompare(bName);
    });
  }

  // Fallback - just return original order
  return porters;
});

const availablePorters = computed(() => {
  // Get all porters
  const allPorters = staffStore.porters || [];
  
  // Get porters already in the pool
  const poolPorterIds = porterPool.value.map(p => p.porter_id);
  
  // Get porters assigned to departments in settings
  // Get assignments for all shift types
  const weekDayAssignments = areaCoverStore.getAssignmentsByShiftType('week_day') || [];
  const weekNightAssignments = areaCoverStore.getAssignmentsByShiftType('week_night') || [];
  const weekendDayAssignments = areaCoverStore.getAssignmentsByShiftType('weekend_day') || [];
  const weekendNightAssignments = areaCoverStore.getAssignmentsByShiftType('weekend_night') || [];
  
  // Get all porter assignments
  const departmentPorterIds = [];
  
  // Check each area assignment for assigned porters
  for (const assignment of [...weekDayAssignments, ...weekNightAssignments, 
                            ...weekendDayAssignments, ...weekendNightAssignments]) {
    // Get porter assignments for this area assignment
    const porterAssignments = areaCoverStore.getPorterAssignmentsByAreaId(assignment.id) || [];
    // Add porter IDs to the list
    for (const pa of porterAssignments) {
      if (pa.porter_id) {
        departmentPorterIds.push(pa.porter_id);
      }
    }
  }
  
  // Get porters already assigned to departments in THIS shift
  const shiftDepartmentPorterIds = shiftsStore.shiftAreaCoverPorterAssignments
    .map(a => a.porter_id);
    
  // Get porters already assigned to services in THIS shift
  const shiftServicePorterIds = shiftsStore.shiftSupportServicePorterAssignments
    .map(a => a.porter_id);
  
  // Combine all excluded porter IDs
  const excludedPorterIds = [...new Set([...poolPorterIds, ...departmentPorterIds, ...shiftDepartmentPorterIds, ...shiftServicePorterIds])];
  
  // Filter out porters who are absent
  const today = new Date();
  return allPorters.filter(p => {
    // First check if porter is in excluded list
    if (excludedPorterIds.includes(p.id)) {
      return false;
    }
    
    // Then check if porter is absent
    if (staffStore.isPorterAbsent(p.id, today)) {
      return false;
    }
    
    return true;
  });
});

// Check if all porters are selected
const isAllSelected = computed(() => {
  return availablePorters.value.length > 0 && 
         selectedPorters.value.length === availablePorters.value.length;
});

// Check if a porter is absent
const isPorterAbsent = (porterId) => {
  const today = new Date();
  return staffStore.isPorterAbsent(porterId, today);
};

// Get the absence type for a porter (illness or annual_leave)
const getPorterAbsenceType = (porterId) => {
  const today = new Date();
  const absence = staffStore.getPorterAbsenceDetails(porterId, today);
  return absence ? absence.absence_type : null;
};

// Get scheduled absences for a porter
const getPorterAbsences = (porterId) => {
  return shiftsStore.getPorterAbsences(porterId);
};

// Remove a scheduled absence
const removeAbsence = async (absenceId) => {
  if (confirm('Are you sure you want to remove this absence?')) {
    await shiftsStore.removePorterAbsence(absenceId);
  }
};

// Methods
const addPorter = async (porterId) => {
  await shiftsStore.addPorterToShift(props.shiftId, porterId);
  showPorterSelector.value = false;
};

// Add multiple selected porters at once
const addSelectedPorters = async () => {
  if (selectedPorters.value.length === 0 || addingPorters.value) return;
  
  addingPorters.value = true;
  
  try {
    // Process each porter sequentially
    for (const porterId of selectedPorters.value) {
      await shiftsStore.addPorterToShift(props.shiftId, porterId);
    }
    
    // Reset selection and close modal
    selectedPorters.value = [];
    showPorterSelector.value = false;
  } catch (error) {
    // Error handling without console logging
  } finally {
    addingPorters.value = false;
  }
};

// Toggle select all porters
const toggleSelectAll = () => {
  if (isAllSelected.value) {
    // Deselect all
    selectedPorters.value = [];
  } else {
    // Select all
    selectedPorters.value = availablePorters.value.map(porter => porter.id);
  }
};

const removePorter = async (porterPoolId) => {
  if (confirm('Are you sure you want to remove this porter from the shift?')) {
    await shiftsStore.removePorterFromShift(porterPoolId);
  }
};

// Remove an assignment
const removeAssignment = async (porter, assignment) => {
  const assignmentName = getAssignmentName(assignment);
  const confirmMessage = `Are you sure you want to remove the ${assignmentName} assignment?`;
  
  if (!confirm(confirmMessage)) return;
  
  try {
    if (assignment.shift_area_cover_assignment_id) {
      // Area cover assignment
      await shiftsStore.removeShiftAreaCoverPorter(assignment.id);
    } else if (assignment.shift_support_service_assignment_id) {
      // Service assignment
      await shiftsStore.removeShiftSupportServicePorter(assignment.id);
    } else if (assignment.isAbsence) {
      // Absence assignment
      await shiftsStore.removePorterAbsence(assignment.id);
    }
  } catch (error) {
    console.error('Error removing assignment:', error);
  }
};

const getPorterAssignments = (porterId) => {
  // Get area cover assignments for this porter in this shift
  const areaCoverAssignments = shiftsStore.shiftAreaCoverPorterAssignments.filter(
    a => a.porter_id === porterId
  );
  
  // Get service assignments for this porter in this shift
  const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments.filter(
    a => a.porter_id === porterId
  );
  
  // Get scheduled absences for this porter in this shift
  const absenceAssignments = shiftsStore.shiftPorterAbsences.filter(
    a => a.porter_id === porterId
  ).map(absence => ({
    ...absence,
    isAbsence: true // Add a flag to identify this as an absence
  }));
  
  // Return all types of assignments
  return [...areaCoverAssignments, ...serviceAssignments, ...absenceAssignments];
};

// Helper function to convert time string (HH:MM:SS) to minutes
const timeToMinutes = (timeStr) => {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
};

// Check if current time is within a time range, handling overnight ranges
const isTimeInRange = (currentTimeMinutes, startTimeMinutes, endTimeMinutes) => {
  // Handle overnight ranges (where end time is less than start time)
  if (endTimeMinutes < startTimeMinutes) {
    // Current time is either after start time or before end time
    return currentTimeMinutes >= startTimeMinutes || currentTimeMinutes <= endTimeMinutes;
  } else {
    // Normal case: current time is between start and end times
    return currentTimeMinutes >= startTimeMinutes && currentTimeMinutes <= endTimeMinutes;
  }
};

// Get the duty status of a porter based on contracted hours using timezone helpers
const getPorterDutyStatus = (porterId) => {
  // Get the porter from the store
  const porter = staffStore.porters.find(p => p.id === porterId);
  if (!porter) {
    return 'on-duty'; // Default to on duty if porter not found
  }
  
  // If no contracted hours set, assume porter is on duty
  if (!porter.contracted_hours_start || !porter.contracted_hours_end) {
    return 'on-duty';
  }
  
  // Get current time in minutes using browser time
  const now = new Date();
  const currentTimeInMinutes = (now.getHours() * 60) + now.getMinutes();
  
  // Convert contracted hours to minutes
  const startTimeMinutes = timeToMinutes(porter.contracted_hours_start);
  const endTimeMinutes = timeToMinutes(porter.contracted_hours_end);
  
  // Check if current time is within contracted hours
  if (isTimeInRange(currentTimeInMinutes, startTimeMinutes, endTimeMinutes)) {
    return 'on-duty';
  }
  
  // Determine if we're before start time or after end time
  if (endTimeMinutes < startTimeMinutes) {
    // Overnight shift (e.g., 22:00 to 06:00)
    if (currentTimeInMinutes > endTimeMinutes && currentTimeInMinutes < startTimeMinutes) {
      // We're in the gap between end and start (e.g., 07:00 when shift is 22:00-06:00)
      // Need to determine if we're closer to the end (off-duty) or start (not-yet-on-duty)
      const timeFromEnd = currentTimeInMinutes - endTimeMinutes;
      const timeToStart = startTimeMinutes - currentTimeInMinutes;
      
      // If we're closer to the end time, consider it "off-duty"
      // If we're closer to the start time, consider it "not-yet-on-duty"
      const result = timeFromEnd <= timeToStart ? 'off-duty' : 'not-yet-on-duty';
      return result;
    }
  } else {
    // Normal shift (e.g., 10:00 to 22:00)
    if (currentTimeInMinutes < startTimeMinutes) {
      // We're before the start time, but need to determine if this is:
      // 1. Before today's shift starts (not-yet-on-duty)
      // 2. After yesterday's shift ended (off-duty)
      
      // Calculate time until today's shift starts
      const timeUntilStart = startTimeMinutes - currentTimeInMinutes;
      
      // Calculate time since yesterday's shift ended
      // Yesterday's end time would be endTimeMinutes, but we need to account for the day boundary
      const timeSinceYesterdayEnd = currentTimeInMinutes + (24 * 60 - endTimeMinutes);
      
      // Use a threshold-based approach:
      // PRIORITIZE upcoming shifts over past shifts
      // If their next shift starts in less than 4 hours, they're "not-yet-on-duty"
      // If they've been off duty for more than 4 hours, they're "off-duty"
      const THRESHOLD_HOURS = 4;
      const THRESHOLD_MINUTES = THRESHOLD_HOURS * 60;
      
      // FIRST: Check if their next shift starts within the threshold - prioritize upcoming work
      if (timeUntilStart <= THRESHOLD_MINUTES) {
        return 'not-yet-on-duty';
      }
      
      // SECOND: If they've been off duty for more than the threshold, they're "off-duty"
      if (timeSinceYesterdayEnd > THRESHOLD_MINUTES) {
        return 'off-duty';
      }
      
      // Fallback: if both conditions don't match, default to off-duty
      return 'off-duty';
    } else if (currentTimeInMinutes > endTimeMinutes) {
      return 'off-duty';
    }
  }
  
  // Fallback
  return 'on-duty';
};

// Check if a porter is currently on duty (for backward compatibility)
const isPorterOnDuty = (porterId) => {
  return getPorterDutyStatus(porterId) === 'on-duty';
};

// Check if a porter is available (on duty, not absent, no active assignments)
const isPorterAvailable = computed(() => {
  return (porterId) => {
    // Check if porter is absent
    if (isPorterAbsent(porterId)) {
      return false;
    }

    // Check if porter has scheduled absence
    if (staffStore.isPorterOnScheduledAbsence(porterId)) {
      return false;
    }

    // Check if porter is on duty
    if (getPorterDutyStatus(porterId) !== 'on-duty') {
      return false;
    }

    // Check if porter has active assignments
    if (hasActiveAssignments.value(porterId)) {
      return false;
    }

    // If all checks pass, porter is available
    return true;
  };
});

// Check if a porter has any active assignments at the current time
const hasActiveAssignments = computed(() => {
  return (porterId) => {
    // Use browser time to get current time in minutes
    const now = new Date();
    const currentTimeInMinutes = (now.getHours() * 60) + now.getMinutes();

    // Get all assignments for this porter
    const assignments = getPorterAssignments(porterId);

    // Check if any assignment is currently active
    return assignments.some(assignment => {
      const startTimeMinutes = timeToMinutes(assignment.start_time);
      const endTimeMinutes = timeToMinutes(assignment.end_time);

      // Assignment is active if current time is between start and end times
      return isTimeInRange(currentTimeInMinutes, startTimeMinutes, endTimeMinutes);
    });
  };
});

// Get the background color for an assignment item
const getAssignmentBackgroundColor = (assignment) => {
  // Check if this is an absence
  if (assignment.isAbsence) {
    return 'rgba(234, 67, 53, 0.15)'; // Light red for absences
  }
  
  // Check if this is an area cover assignment or service assignment
  if (assignment.shift_area_cover_assignment_id) {
    // Area cover assignment
    const color = assignment.shift_area_cover_assignment?.color || '#4285F4';
    return `${color}25`; // 25 is hex for 15% opacity
  } else if (assignment.shift_support_service_assignment_id) {
    // Service assignment
    // Get the service assignment from the store
    const serviceAssignment = shiftsStore.shiftSupportServiceAssignments.find(
      s => s.id === assignment.shift_support_service_assignment_id
    );
    const color = serviceAssignment?.color || '#4285F4';
    return `${color}25`; // 25 is hex for 15% opacity
  }
  
  // Default color
  return 'rgba(66, 133, 244, 0.15)'; // Light blue
};

// Format time (e.g., "09:30") in 24-hour format
// Get the assignment name (department or service)
const getAssignmentName = (assignment) => {
  // Check if this is an absence
  if (assignment.isAbsence) {
    return `Absence: ${assignment.absence_reason || 'Scheduled'}`;
  }
  
  // Check if this is an area cover assignment
  if (assignment.shift_area_cover_assignment_id) {
    // First try to get from the direct relationship
    if (assignment.shift_area_cover_assignment?.department?.name) {
      return assignment.shift_area_cover_assignment.department.name;
    }
    
    // Fallback: find the area cover assignment in the store
    const areaAssignment = shiftsStore.shiftAreaCoverAssignments.find(
      a => a.id === assignment.shift_area_cover_assignment_id
    );
    
    if (areaAssignment?.department?.name) {
      return areaAssignment.department.name;
    }
    
    // Last fallback: try to get department from locations store
    if (areaAssignment?.department_id) {
      const department = locationsStore.departments.find(
        d => d.id === areaAssignment.department_id
      );
      if (department?.name) {
        return department.name;
      }
    }
    
    return 'Unknown Department';
  } else if (assignment.shift_support_service_assignment_id) {
    // Service assignment - find the service assignment
    const serviceAssignment = shiftsStore.shiftSupportServiceAssignments.find(
      s => s.id === assignment.shift_support_service_assignment_id
    );
    
    if (serviceAssignment?.service?.name) {
      return serviceAssignment.service.name;
    }
    
    // Fallback: try to get service from support services store
    if (serviceAssignment?.service_id) {
      const service = supportServicesStore.services.find(
        s => s.id === serviceAssignment.service_id
      );
      if (service?.name) {
        return service.name;
      }
    }
    
    return 'Unknown Service';
  }
  
  // Default
  return 'Unknown Assignment';
};

const formatTime = (timeStr) => {
  // Use browser's built-in formatting for 24-hour time
  try {
    // Handle both time-only strings (HH:MM:SS) and full datetime strings
    let date;
    if (timeStr.includes('T')) {
      // Full datetime string
      date = new Date(timeStr);
    } else {
      // Time-only string - create a date with today's date
      date = new Date(`2025-01-01T${timeStr}`);
    }
    
    if (isNaN(date.getTime())) {
      return timeStr; // Return original if parsing fails
    }
    
    return date.toLocaleTimeString('en-GB', { 
      hour12: false,
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch (error) {
    return timeStr; // Return original if error occurs
  }
};

// Porter-building assignment functions
const togglePorterBuildingAssignment = async (porterId, buildingId) => {
  await shiftsStore.togglePorterBuildingAssignment(porterId, buildingId, props.shiftId);
};

const isPorterAssignedToBuilding = (porterId, buildingId) => {
  return shiftsStore.isPorterAssignedToBuilding(porterId, buildingId);
};

// Reset selected porters when modal is closed
watch(showPorterSelector, (isOpen) => {
  if (!isOpen) {
    selectedPorters.value = [];
  }
});

// Lifecycle hooks
onMounted(async () => {
  isLoading.value = true;
  
  try {
    // Load core data first
    if (!staffStore.porters.length) {
      await staffStore.fetchPorters();
    }
    
    // Initialize area cover store to ensure department data is available
    await areaCoverStore.initialize();
    
    // Load locations data to ensure departments are available
    if (!locationsStore.departments.length) {
      await locationsStore.fetchDepartments();
    }
    
    // Load support services data
    if (!supportServicesStore.services.length) {
      await supportServicesStore.fetchServices();
    }
    
    // Load shift-specific data in sequence
    await shiftsStore.fetchShiftPorterPool(props.shiftId);

    // Load porter building assignments
    await shiftsStore.fetchShiftPorterBuildingAssignments(props.shiftId);

    // Load shift area cover assignments with full relationships
    await shiftsStore.fetchShiftAreaCover(props.shiftId);
    
    // Load shift support service assignments with full relationships
    await shiftsStore.fetchShiftSupportServices(props.shiftId);
    
    // Load porter absences for this shift
    await shiftsStore.fetchShiftPorterAbsences(props.shiftId);
    
    // Load porter-building assignments for this shift
    await shiftsStore.fetchShiftPorterBuildingAssignments(props.shiftId);
    
  } catch (error) {
    console.error('Error loading shift porter pool data:', error);
  } finally {
    // Delay slightly to ensure computed values update and relationships are resolved
    setTimeout(() => {
      isLoading.value = false;
    }, 500);
  }
});
</script>

<!-- Styles are now handled by the global CSS layers -->