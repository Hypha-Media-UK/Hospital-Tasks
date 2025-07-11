<template>
  <div 
    class="service-card" 
    :style="{ borderLeftColor: assignment.service.color || '#CCCCCC' }"
    @click="showEditModal = true"
  >
    <div class="service-card__content">
      <div class="service-card__header">
        <div class="service-card__name">
          {{ assignment.service.name }}
        </div>
        <div class="service-card__time">
          {{ formatTimeRange(assignment.start_time, assignment.end_time) }}
        </div>
      </div>
      
      <div class="service-card__porters">
        <!-- Gap at start if first porter starts after service start time -->
        <div v-if="sortedPorterAssignments.length > 0 && hasStartGap" class="gap-line gap-line--start">
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
                     'porter-scheduled-absence': isShiftAssignment && shiftsStore.isPorterOnScheduledAbsence(assignment.porter_id),
                     'pool-porter': isPoolPorter(assignment.porter_id),
                     'porter-outside-hours': isShiftAssignment && shiftsStore.isShiftInSetupMode(shiftsStore.currentShift) && isPorterOutsideContractedHours(assignment.porter_id)
                   }">
                {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
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
                <span v-else-if="isShiftAssignment && shiftsStore.isPorterOnScheduledAbsence(assignment.porter_id)"
                      class="absence-badge scheduled">ABS</span>
              </div>
            </div>

            <!-- Gap indicator between assignments (now a direct child of porter-assignments) -->
            <div v-if="index < sortedPorterAssignments.length - 1 && hasGapBetween(assignment, sortedPorterAssignments[index + 1])" 
                 v-for="gap in getGapsBetweenAssignments(assignment, sortedPorterAssignments[index + 1])"
                 :key="`gap-${assignment.id}-${gap.startTime}`"
                 class="gap-line">
              <div class="gap-line-time">{{ formatTime(gap.startTime) }} - {{ formatTime(gap.endTime) }}</div>
            </div>
          </template>
        </div>
        
        <!-- Gap at end if last porter ends before service end time -->
        <div v-if="sortedPorterAssignments.length > 0 && hasEndGap" class="gap-line gap-line--end">
          <div class="gap-line-time">{{ formatTime(sortedPorterAssignments[sortedPorterAssignments.length - 1].end_time) }} - {{ formatTime(assignment.end_time) }}</div>
        </div>
        
        <!-- Absent porters are now shown directly in the porter assignments list above -->
        
        <!-- Coverage warning removed as requested -->
        
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
    
    <!-- Edit Service Modal - Use different modal based on whether this is a shift assignment -->
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
        :service="assignment.service"
        :assignment="assignment"
        @close="showEditModal = false"
        @update="handleUpdate"
        @remove="handleRemove"
      />
    </template>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useShiftsStore } from '../../stores/shiftsStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';
import { useStaffStore } from '../../stores/staffStore';
import { getCurrentDateTime, getCurrentTimeInMinutes, isSameDay } from '../../utils/timezone';
import EditServiceModal from './EditServiceModal.vue';
import ShiftEditServiceModal from './ShiftEditServiceModal.vue';

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
    console.log(`Service ${props.assignment.service.name} porter assignments:`, assignments);
    return Array.isArray(assignments) ? assignments : [];
  } else {
    // Use the supportServicesStore getter for default settings
    const assignments = supportServicesStore.getPorterAssignmentsByServiceId(props.assignment.id);
    console.log(`Service ${props.assignment.service.name} porter assignments:`, assignments);
    return Array.isArray(assignments) ? assignments : [];
  }
});

// Get all available (non-absent and currently active) porters
const availablePorters = computed(() => {
  const shift = shiftsStore.currentShift;
  const isSetupMode = shiftsStore.isShiftInSetupMode(shift);
  
  if (isShiftAssignment.value && isSetupMode) {
    // In setup mode for shift assignments: show ALL assigned porters regardless of absence status or contracted hours
    // This allows users to see all porters and make adjustments before the shift starts
    return porterAssignments.value;
  } else {
    // In active mode or for default settings: apply existing time-based filtering
    const today = new Date();
    const currentHours = today.getHours();
    const currentMinutes = today.getMinutes();
    const currentTimeInMinutes = (currentHours * 60) + currentMinutes;
    
    return porterAssignments.value.filter(assignment => {
      // First check if porter is absent
      if (staffStore.isPorterAbsent(assignment.porter_id, today)) {
        return false;
      }
      
      // Check if porter has a scheduled absence (only for shift assignments)
      if (isShiftAssignment.value && shiftsStore.isPorterOnScheduledAbsence(assignment.porter_id)) {
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
  const now = getCurrentDateTime();
  
  // Only check contracted hours if we're on the actual shift date
  if (!isSameDay(shift.start_time, now)) {
    return false; // Different date, don't apply contracted hours check
  }
  
  const currentTimeInMinutes = getCurrentTimeInMinutes();
  
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
      console.log(`Service ${props.assignment.id} coverage gaps:`, gaps);
      return gaps.hasGap;
    } else {
      return supportServicesStore.hasCoverageGap ? 
        supportServicesStore.hasCoverageGap(props.assignment.id) : 
        false;
    }
  } catch (error) {
    console.error('Error checking coverage gap:', error);
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
    console.error('Error checking staffing shortage:', error);
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
    console.error('Error getting coverage gaps:', error);
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
    console.log(`Checking gap between ${current.end_time} and ${next.start_time}`);
    console.log('Coverage gaps object:', coverageGaps.value);
    
    // Make sure coverageGaps.value.gaps exists and is an array
    if (coverageGaps.value && Array.isArray(coverageGaps.value.gaps)) {
      // There's a gap, check if it matches any known gaps
      coverageGaps.value.gaps.forEach(gap => {
        const gapStart = timeToMinutes(gap.startTime);
        const gapEnd = timeToMinutes(gap.endTime);
        
        console.log(`Comparing gap: ${gap.startTime} - ${gap.endTime}`);
        
        // If this gap matches the one between these assignments
        if (Math.abs(gapStart - currentEnd) < 5 && Math.abs(gapEnd - nextStart) < 5) {
          console.log('Found matching gap!');
          gaps.push(gap);
        }
      });
    } else {
      console.log('No gaps array found in coverageGaps.value');
    }
    
    // If no coverage gap found, but there's still a time gap, add a generic one
    if (gaps.length === 0) {
      console.log('Adding generic gap');
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
  return timeStr.substring(0, 5); // Extract HH:MM part
};

// Helper function to format time range
function formatTimeRange(startTime, endTime) {
  if (!startTime || !endTime) return '';
  
  // Format times (assumes HH:MM format)
  const formatTime = (time) => {
    if (typeof time === 'string') {
      // Handle 24-hour time format string (e.g., "14:30:00")
      return time.substring(0, 5); // Get HH:MM part
    }
    return '';
  };
  
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

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.service-card {
  background-color: white;
  border-radius: mix.radius('md');
  border-left: 4px solid #4285F4; // Default color, will be overridden by inline style
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  transition: box-shadow 0.2s ease;
  cursor: pointer;
  position: relative;
  
  &:hover {
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
    background-color: rgba(0, 0, 0, 0.01);
  }
  
  &:before {
    content: '';
    position: absolute;
    top: 0;
    right: 0;
    width: 0;
    height: 0;
    border-style: solid;
    z-index: 1;
  }
  
  &.has-gap:before {
    border-width: 0 24px 24px 0;
    border-color: transparent #EA4335 transparent transparent;
  }
  
  &.understaffed:before {
    border-width: 0 24px 24px 0;
    border-color: transparent #F4B400 transparent transparent;
  }
  
  &__content {
    padding: 12px 16px;
  }
  
  &__header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    margin-bottom: 12px; /* Increased from 4px to 12px as requested */
  }
  
  &__name {
    font-weight: 600;
    font-size: mix.font-size('md');
  }
  
  &__time {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.7);
    padding: 2px 6px;
    background-color: rgba(0, 0, 0, 0.05);
    border-radius: mix.radius('sm');
  }
  

  &__porters {
    margin-top: 8px;
    position: relative;
    padding-bottom: 36px; /* Add space for the absolutely positioned porter count */
    
    .porter-count-wrapper {
      position: absolute;
      bottom: 0;
      left: 0;
      right: 0;
      margin-top: 0;
      padding-top: 12px;
    }
    
    .porter-count {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background-color: rgba(66, 133, 244, 0.1);
      color: mix.color('primary');
      border-radius: 100px;
      padding: 2px 8px;
      font-size: mix.font-size('xs');
      font-weight: 500;
      
      &.no-porters {
        background-color: #EA4335; /* Red background */
        color: white; /* White text */
      }
      
      &.coverage-gap {
        background-color: rgba(234, 67, 53, 0.2);
        color: #d32f2f;
      }
      
      .absent-count {
        font-size: mix.font-size('2xs');
        color: #d32f2f;
        margin-left: 4px;
      }
    }
    
    /* Generic styles for all gap lines */
    .gap-line {
      margin: 12px 0 0 0; /* Top margin only, no bottom margin */
      position: relative;
      padding-left: 12px;
      padding-top: 4px;
      padding-bottom: 0; /* Removed bottom padding */
      border-top: 1px solid rgba(234, 67, 53, 0.2); /* Using pale red consistently for all gap lines */
      
      .gap-line-indicator {
        position: absolute;
        left: 0;
        top: 50%;
        transform: translateY(-50%);
        width: 4px;
        height: 20px; /* Fixed height for better visibility */
        background-color: rgba(234, 67, 53, 0.3); /* Using pale red consistently for all gap indicators */
        border-radius: 2px;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2); /* Add shadow for better visibility */
      }
      
      .gap-line-time {
        position: absolute;
        top: -12px;
        right: 0;
        font-size: 0.6rem; /* Further reduced font size */
        color: #d32f2f; /* Red text color */
        padding: 2px 6px;
        background-color: #fef6f5; /* Fully opaque light red */
        border: 1px solid rgba(234, 67, 53, 0.2);
        border-radius: mix.radius('sm');
        display: inline-block;
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
        z-index: 5;
      }
    }
    
    /* Specific styles for start/end gap lines - these are outside .porter-assignments */
    .gap-line--start, 
    .gap-line--end {
      margin: 16px 0 0 0; /* Increased top margin, removed bottom margin */
      padding-top: 6px;
      border-top: 1px solid rgba(234, 67, 53, 0.2) !important; /* Pale red line for start/end gaps */
      
      .gap-line-indicator {
        background-color: rgba(234, 67, 53, 0.3) !important; /* Pale red for start/end gaps */
      }
    }
    
    /* Direct styling for the time text in start/end gap lines */
    .gap-line--start .gap-line-time, 
    .gap-line--end .gap-line-time {
      position: absolute !important;
      top: -12px !important;
      right: 0 !important;
      font-size: 0.6rem !important; /* Further reduced font size */
      font-weight: normal !important;
      line-height: 1.2 !important;
      color: #d32f2f !important; /* Red text color */
      padding: 2px 6px !important;
      background-color: #fef6f5 !important; /* Fully opaque light red */
      border: 1px solid rgba(234, 67, 53, 0.2) !important;
      border-radius: 4px !important;
      display: inline-block !important;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1) !important;
      z-index: 5 !important;
    }
    
    .porter-assignments {
      margin-top: 0; /* Removed margin-top as requested */
      
      /* Apply margin styles to all direct children */
      > * {
        margin-bottom: 3px;
      }
      
      /* Add top margin to all children except the first one */
      > *:not(:first-child) {
        margin-top: 3px;
      }
      
      /* Add extra space above gap-line elements to prevent overlap */
      > .gap-line {
        margin-top: 15px !important; /* Increased to 15px as requested */
        padding-top: 8px; /* Additional padding at top */
        padding-bottom: 0; /* Removing bottom padding as requested */
      }
      
      /* Special case if the last child is also the first child */
      > *:first-child:last-child {
        margin-bottom: 3px;
        margin-top: 0;
      }
      
      .porter-assignment {
        font-size: mix.font-size('xs');
        margin-bottom: 0; /* Removed to balance spacing with gap-line */
        
        .porter-name {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 4px 8px;
          background-color: rgba(0, 0, 0, 0.02);
          border-radius: mix.radius('sm');
          
          &.porter-illness {
            color: #d32f2f;
            background-color: rgba(234, 67, 53, 0.1);
          }
          
          &.porter-annual-leave {
            color: #f57c00;
            background-color: rgba(251, 192, 45, 0.1);
          }
          
          &.porter-scheduled-absence {
            color: #ea4335;
            background-color: rgba(234, 67, 53, 0.1);
          }
          
          &.pool-porter {
            background-color: #FFF8ED;  /* Extremely pale orange background */
            font-style: italic;
          }
          
          &.porter-outside-hours {
            color: #999999;  /* Light grey text */
            background-color: rgba(153, 153, 153, 0.1);  /* Very light grey background */
            opacity: 0.7;  /* Make it more subtle */
            text-decoration: line-through;  /* Add strikethrough */
          }
          
          .porter-time {
            color: rgba(0, 0, 0, 0.5);
            font-size: mix.font-size('2xs');
            
            .absence-text {
              color: #f57c00;
              font-style: italic;
              background-color: rgba(245, 124, 0, 0.1);
              padding: 2px 6px;
              border-radius: 4px;
              display: inline-block;
            }
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
            
            &.scheduled {
              background-color: #ea4335;
              color: white;
            }
          }
        }
      }
    }
    
    .absent-porters-section {
      margin-top: 16px;
      padding: 8px;
      background-color: rgba(0, 0, 0, 0.02);
      border-radius: mix.radius('sm');
      
      .absent-porters-title {
        font-size: mix.font-size('xs');
        font-weight: 500;
        margin-bottom: 8px;
        color: #d32f2f;
      }
      
      .absent-porter-item {
        margin-bottom: 4px;
        
        .absent-porter-name {
          font-size: mix.font-size('xs');
          padding: 2px 6px;
          border-radius: mix.radius('sm');
          display: inline-block;
          
          &.illness {
            color: #d32f2f;
            background-color: rgba(234, 67, 53, 0.1);
          }
          
          &.annual-leave {
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
      }
    }
    
    .coverage-warning {
      margin-top: 12px;
      padding: 8px;
      background-color: rgba(234, 67, 53, 0.1);
      color: #d32f2f;
      border-radius: mix.radius('sm');
      font-size: mix.font-size('xs');
      font-weight: 500;
      text-align: center;
    }
  }
}
</style>
