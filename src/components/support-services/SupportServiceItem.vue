<template>
  <div
    class="service-card"
    :style="{ borderLeftColor: serviceData.color || assignment.color || '#CCCCCC' }"
    @click="showEditModal = true"
  >
    <div class="service-card__header">
      <div class="service-card__name">
        {{ serviceData.name }}
      </div>
      <div class="service-card__time">
        {{ formatTimeRange(assignment.start_time, assignment.end_time) }}
      </div>
    </div>
      
      <div class="service-card__porters">
        <!-- Gap at start if first porter starts after service start time -->
        <div v-if="sortedPorterAssignments.length > 0 && hasStartGap" class="gap-line">
          <hr class="gap-line-hr" />
          <div class="gap-line-time">{{ formatTime(assignment.start_time) }} - {{ formatTime(sortedPorterAssignments[0].start_time) }}</div>
        </div>
        
        <div class="porter-assignments">
          <!-- Loop through each porter assignment -->
          <template v-for="(assignment, index) in sortedPorterAssignments" :key="assignment.id">
            <!-- Porter assignment -->
            <div class="porter-assignment">
              <div class="porter-name" 
                   :class="{
                     'porter-absent': getPorterAbsence(assignment.porter_id),
                     'porter-illness': getPorterAbsence(assignment.porter_id)?.absence_type === 'illness',
                     'porter-annual-leave': getPorterAbsence(assignment.porter_id)?.absence_type === 'annual_leave',
                     'porter-scheduled-absence': isShiftAssignment && staffStore.isPorterOnScheduledAbsence(assignment.porter_id),
                     'pool-porter': isPoolPorter(assignment.porter_id),
                     'porter-outside-hours': isShiftAssignment && shiftsStore.isShiftInSetupMode && shiftsStore.isShiftInSetupMode(shiftsStore.currentShift) && isPorterOutsideContractedHours(assignment.porter_id)
                   }">
                {{ assignment.porter?.first_name || assignment.staff?.first_name || 'Unknown' }} {{ assignment.porter?.last_name || assignment.staff?.last_name || 'Porter' }}
                <!-- Show time for available porters, absence badge for absent porters -->
                <span v-if="!getPorterAbsence(assignment.porter_id)" class="porter-time">
                  <template v-if="assignment.agreed_absence">
                    <span class="absence-text">{{ assignment.agreed_absence }}</span>
                  </template>
                  <template v-else>
                    {{ isPoolPorter(assignment.porter_id) ? 'Cover: ' : '' }}{{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
                  </template>
                </span>
                <span v-else-if="getPorterAbsence(assignment.porter_id)?.absence_type === 'illness'" 
                      class="absence-badge illness">ILL</span>
                <span v-else-if="getPorterAbsence(assignment.porter_id)?.absence_type === 'annual_leave'" 
                      class="absence-badge annual-leave">AL</span>
                <span v-else-if="isShiftAssignment && staffStore.isPorterOnScheduledAbsence(assignment.porter_id)"
                      class="absence-badge scheduled">ABS</span>
              </div>
            </div>

            <!-- Gap indicator between assignments (now a direct child of porter-assignments) -->
            <div v-if="index < sortedPorterAssignments.length - 1 && hasGapBetween(assignment, sortedPorterAssignments[index + 1])"
                 v-for="gap in getGapsBetweenAssignments(assignment, sortedPorterAssignments[index + 1])"
                 :key="`gap-${assignment.id}-${gap.startTime}`"
                 class="gap-line">
              <hr class="gap-line-hr" />
              <div class="gap-line-time">{{ formatTime(gap.startTime) }} - {{ formatTime(gap.endTime) }}</div>
            </div>
          </template>
        </div>
        
        <!-- Gap at end if last porter ends before service end time -->
        <div v-if="sortedPorterAssignments.length > 0 && hasEndGap" class="gap-line">
          <hr class="gap-line-hr" />
          <div class="gap-line-time">{{ formatTime(sortedPorterAssignments[sortedPorterAssignments.length - 1].end_time) }} - {{ formatTime(assignment.end_time) }}</div>
        </div>
        
        <!-- Absent porters are now shown directly in the porter assignments list above -->

        <div class="porter-count-wrapper">
          <span class="porter-count"
                :class="{
                  'no-porters': porterAssignments.length === 0 || availablePorters.length === 0,
                  'coverage-gap': hasCoverageGap
                }">
            {{ availablePorters.length }} {{ availablePorters.length === 1 ? 'Porter' : 'Porters' }}
            <span v-if="absentPorters.length > 0" class="absent-count">
              ({{ absentPorters.length }} absent)
            </span>
          </span>
        </div>
      </div>

  </div>

  <!-- Edit Service Modal - Teleported to body to avoid container constraints -->
  <Teleport to="body">
    <template v-if="showEditModal">
      <!-- For shift assignments -->
      <ShiftEditServiceModal
        v-if="isShiftAssignment"
        :assignment="assignment"
        @close="showEditModal = false"
        @update="handleUpdate"
        @remove="handleRemove"
      />
      <!-- For default settings assignments -->
      <EditServiceModal
        v-else
        :service="serviceData"
        :assignment="assignment"
        @close="showEditModal = false"
        @update="handleUpdate"
        @remove="handleRemove"
      />
    </template>
  </Teleport>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useShiftsStore } from '../../stores/shiftsStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';
import { useStaffStore } from '../../stores/staffStore';
import EditServiceModal from './EditServiceModal.vue';
import ShiftEditServiceModal from './ShiftEditServiceModal.vue';

// Helper function to check if two dates are on the same day
const isSameDay = (date1, date2) => {
  const d1 = new Date(date1);
  const d2 = new Date(date2);
  return d1.getFullYear() === d2.getFullYear() &&
         d1.getMonth() === d2.getMonth() &&
         d1.getDate() === d2.getDate();
};

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['update', 'remove']);

const shiftsStore = useShiftsStore();
const supportServicesStore = useSupportServicesStore();
const staffStore = useStaffStore();
const showEditModal = ref(false);

// Handle different data structures for service data
const serviceData = computed(() => {
  // For default service cover assignments, service data is in support_services
  // For shift assignments, service data is in service
  const service = props.assignment.support_services || props.assignment.service || {};
  
  // Add fallback for missing properties
  return {
    name: service.name || 'Unknown Service',
    description: service.description || '',
    color: service.color || props.assignment.color || '#CCCCCC',
    ...service
  };
});

// Function to check if a porter is in the porter pool
const isPoolPorter = (porterId) => {
  // Get the porter pool for the current shift
  const porterPool = shiftsStore.shiftPorterPool || [];
  // Check if the porter exists in the pool
  return porterPool.some(entry => entry.porter_id === porterId);
};

// Get porter assignments for this service
const porterAssignments = computed(() => {
  // Check if this is a shift-specific assignment or a default assignment
  if (isShiftAssignment.value) {
    // Use the shiftsStore getter for shift-specific assignments
    const assignments = shiftsStore.getPorterAssignmentsByServiceId(props.assignment.id);
    return Array.isArray(assignments) ? assignments : [];
  } else {
    // Use the supportServicesStore getter for default settings
    const assignments = supportServicesStore.getPorterAssignmentsByServiceId(props.assignment.id);
    return Array.isArray(assignments) ? assignments : [];
  }
});

// Get all available (non-absent and currently active) porters
const availablePorters = computed(() => {
  const shift = shiftsStore.currentShift;
  const isSetupMode = shiftsStore.isShiftInSetupMode ? shiftsStore.isShiftInSetupMode(shift) : false;
  
  if (isShiftAssignment.value && isSetupMode) {
    // In setup mode for shift assignments: show ALL assigned porters regardless of absence status or contracted hours
    // This allows users to see all porters and make adjustments before the shift starts
    return porterAssignments.value;
  } else {
    // In active mode or for default settings: apply existing time-based filtering
    const today = new Date();
    const currentTimeInMinutes = (today.getHours() * 60) + today.getMinutes();
    
    return porterAssignments.value.filter(assignment => {
      // First check if porter is absent
      if (staffStore.isPorterAbsent(assignment.porter_id, today)) {
        return false;
      }
      
      // Check if porter has a scheduled absence (only for shift assignments)
      if (isShiftAssignment.value && staffStore.isPorterOnScheduledAbsence(assignment.porter_id)) {
        return false;
      }
      
      // Then check if this is a future allocation
      if (assignment.start_time) {
        // Convert start time to minutes for comparison
        const [startHours, startMinutes] = assignment.start_time.split(':').map(Number);
        const startTimeInMinutes = (startHours * 60) + startMinutes;
        
        // Only include porters whose allocation time has started
        return startTimeInMinutes <= currentTimeInMinutes;
      }
      
      return true;
    });
  }
});

// Get all absent porters
const absentPorters = computed(() => {
  const today = new Date();
  return porterAssignments.value.filter(assignment => {
    return staffStore.isPorterAbsent(assignment.porter_id, today);
  });
});

// Get porter absence details
const getPorterAbsence = (porterId) => {
  const today = new Date();
  return staffStore.getPorterAbsenceDetails(porterId, today);
};

// Check if this is a shift-specific assignment
const isShiftAssignment = computed(() => {
  return !!props.assignment.shift_id;
});

// Check if a porter is outside their contracted hours
const isPorterOutsideContractedHours = (porterId) => {
  const porter = staffStore.getStaffById(porterId);
  if (!porter || !porter.contracted_hours_start || !porter.contracted_hours_end) {
    return false; // No contracted hours defined, so not outside
  }
  
  const shift = shiftsStore.currentShift;
  if (!shift) return false;
  
  // Get the shift date and current date for comparison
  const now = new Date();
  
  // Only check contracted hours if we're on the actual shift date
  if (!isSameDay(shift.start_time, now)) {
    return false; // Different date, don't apply contracted hours check
  }
  
  const currentTimeInMinutes = (now.getHours() * 60) + now.getMinutes();
  
  // Convert contracted hours to minutes
  const [startHours, startMinutes] = porter.contracted_hours_start.split(':').map(Number);
  const [endHours, endMinutes] = porter.contracted_hours_end.split(':').map(Number);
  const contractedStartMinutes = (startHours * 60) + startMinutes;
  const contractedEndMinutes = (endHours * 60) + endMinutes;
  
  // Handle overnight shifts (end time is next day)
  if (contractedEndMinutes < contractedStartMinutes) {
    // Overnight shift: porter is available from start time to midnight, then midnight to end time
    return !(currentTimeInMinutes >= contractedStartMinutes || currentTimeInMinutes <= contractedEndMinutes);
  } else {
    // Regular shift: porter is available from start time to end time
    return !(currentTimeInMinutes >= contractedStartMinutes && currentTimeInMinutes <= contractedEndMinutes);
  }
};

// Check if there's a coverage gap
const hasCoverageGap = computed(() => {
  try {
    // Use the appropriate store's coverage gap checker based on assignment type
    if (isShiftAssignment.value) {
      // This is the key issue - we need to directly use the getter function
      // Using methods and getters differently in Pinia
      const gaps = shiftsStore.getServiceCoverageGaps(props.assignment.id);
      return gaps.hasGap;
    } else {
      return supportServicesStore.hasCoverageGap ? 
        supportServicesStore.hasCoverageGap(props.assignment.id) : 
        false;
    }
  } catch (error) {
    return false;
  }
});

// Check if there's a staffing shortage
const hasStaffingShortage = computed(() => {
  try {
    // Use the appropriate store's staffing shortage checker based on assignment type
    if (isShiftAssignment.value) {
      return false; // Not implemented for shift services yet
    } else {
      return supportServicesStore.hasStaffingShortage(props.assignment.id);
    }
  } catch (error) {
    return false;
  }
});

// Sort porter assignments by start time (all porters, not just available ones)
const sortedPorterAssignments = computed(() => {
  return [...porterAssignments.value].sort((a, b) => {
    const aStart = timeToMinutes(a.start_time);
    const bStart = timeToMinutes(b.start_time);
    return aStart - bStart;
  });
});

// Get coverage gaps with detailed information
const coverageGaps = computed(() => {
  try {
    if (isShiftAssignment.value) {
      // Always use the getter directly since it will return the appropriate object
      // with the gaps information
      return shiftsStore.getServiceCoverageGaps(props.assignment.id);
    } else {
      // For support services store, use the getCoverageGaps method if it exists
      return supportServicesStore.getCoverageGaps ? 
        supportServicesStore.getCoverageGaps(props.assignment.id) : 
        { hasGap: false, gaps: [] };
    }
  } catch (error) {
    return { hasGap: false, gaps: [] };
  }
});

// Check if there's a gap at the start of the assignment
const hasStartGap = computed(() => {
  if (sortedPorterAssignments.value.length === 0) return true;
  
  const serviceStart = timeToMinutes(props.assignment.start_time);
  const firstPorterStart = timeToMinutes(sortedPorterAssignments.value[0].start_time);
  
  return firstPorterStart > serviceStart;
});

// Check if there's a gap at the end of the assignment
const hasEndGap = computed(() => {
  if (sortedPorterAssignments.value.length === 0) return true;
  
  const serviceEnd = timeToMinutes(props.assignment.end_time);
  const lastPorterEnd = timeToMinutes(sortedPorterAssignments.value[sortedPorterAssignments.value.length - 1].end_time);
  
  return lastPorterEnd < serviceEnd;
});

// Helper function to check if there's a gap between two assignments
const hasGapBetween = (current, next) => {
  const currentEnd = timeToMinutes(current.end_time);
  const nextStart = timeToMinutes(next.start_time);
  
  return nextStart > currentEnd;
};

// Helper to convert time string to minutes
const timeToMinutes = (timeStr) => {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
};

// Helper to find gaps between two assignments
const getGapsBetweenAssignments = (current, next) => {
  const gaps = [];
  
  // Check if there's a gap between these two assignments
  const currentEnd = timeToMinutes(current.end_time);
  const nextStart = timeToMinutes(next.start_time);
  
  if (nextStart > currentEnd) {
    
    // Make sure coverageGaps.value.gaps exists and is an array
    if (coverageGaps.value && Array.isArray(coverageGaps.value.gaps)) {
      // There's a gap, check if it matches any known gaps
      coverageGaps.value.gaps.forEach(gap => {
        const gapStart = timeToMinutes(gap.startTime);
        const gapEnd = timeToMinutes(gap.endTime);
        
        
        // If this gap matches the one between these assignments
        if (Math.abs(gapStart - currentEnd) < 5 && Math.abs(gapEnd - nextStart) < 5) {
          gaps.push(gap);
        }
      });
    } else {
    }
    
    // If no coverage gap found, but there's still a time gap, add a generic one
    if (gaps.length === 0) {
      gaps.push({
        startTime: current.end_time,
        endTime: next.start_time,
        type: 'gap'
      });
    }
  }
  
  return gaps;
};

// Format time for display (HH:MM)
const formatTime = (timeStr) => {
  if (!timeStr) return '';
  
  // Handle Date objects (from MySQL/Prisma)
  if (timeStr instanceof Date) {
    return timeStr.toTimeString().substring(0, 5); // Extract HH:MM from time string
  }
  
  // Handle ISO datetime strings (e.g., "1970-01-01T08:00:00.000Z")
  if (typeof timeStr === 'string' && timeStr.includes('T')) {
    const date = new Date(timeStr);
    return date.toTimeString().substring(0, 5); // Extract HH:MM from time string
  }
  
  // Handle simple time strings (e.g., "08:00:00" or "08:00")
  if (typeof timeStr === 'string') {
    return timeStr.substring(0, 5); // Extract HH:MM part
  }
  
  return '';
};

// Helper function to format time range
function formatTimeRange(startTime, endTime) {
  if (!startTime || !endTime) return '';
  
  return `${formatTime(startTime)} - ${formatTime(endTime)}`;
}

// Forward events from modal to parent
const handleUpdate = (assignmentId, updates) => {
  emit('update', assignmentId, updates);
};

const handleRemove = (assignmentId) => {
  emit('remove', assignmentId);
  showEditModal.value = false;
};
</script>

<!-- Styles are now handled by the global CSS layers -->