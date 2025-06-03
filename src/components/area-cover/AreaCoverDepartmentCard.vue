<template>
  <div 
    class="department-card" 
    :style="{ borderLeftColor: assignment.color || '#4285F4' }"
    @click="showEditModal = true"
  >
    <div class="department-card__content">
      <div class="department-card__name">
        {{ assignment.department.name }}
      </div>
      <div class="department-card__time">
        {{ formatTimeRange(assignment.start_time, assignment.end_time) }}
      </div>
      
      <div class="department-card__porters">
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

        <!-- Gap at start if first porter starts after department start time -->
        <div v-if="sortedPorterAssignments.length > 0 && hasStartGap" class="gap-line gap-line--start">
          <div class="gap-line-time">{{ formatTime(assignment.start_time) }} - {{ formatTime(sortedPorterAssignments[0].start_time) }}</div>
        </div>
        
        <div class="porter-assignments">
          <div v-for="(assignment, index) in sortedPorterAssignments" :key="assignment.id" class="porter-assignment">
            <div class="porter-name">
              {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
              <span class="porter-time">{{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}</span>
            </div>

            <!-- Gap indicator between assignments -->
            <div v-if="index < sortedPorterAssignments.length - 1 && hasGapBetween(assignment, sortedPorterAssignments[index + 1])" 
                class="gap-line"
                v-for="gap in getGapsBetweenAssignments(assignment, sortedPorterAssignments[index + 1])"
                :key="gap.startTime">
              <div class="gap-line-time">{{ formatTime(gap.startTime) }} - {{ formatTime(gap.endTime) }}</div>
            </div>
          </div>
        </div>

        <!-- Gap at end if last porter ends before department end time -->
        <div v-if="sortedPorterAssignments.length > 0 && hasEndGap" class="gap-line gap-line--end">
          <div class="gap-line-time">{{ formatTime(sortedPorterAssignments[sortedPorterAssignments.length - 1].end_time) }} - {{ formatTime(assignment.end_time) }}</div>
        </div>
        
        <!-- Show absent porters section -->
        <div v-if="absentPorters.length > 0" class="absent-porters-section">
          <div class="absent-porters-title">Absent Porters:</div>
          <div v-for="porter in absentPorters" :key="porter.id" class="absent-porter-item">
            <span class="absent-porter-name" 
                  :class="{'illness': getPorterAbsence(porter.porter_id)?.absence_type === 'illness',
                          'annual-leave': getPorterAbsence(porter.porter_id)?.absence_type === 'annual_leave'}">
              {{ porter.porter.first_name }} {{ porter.porter.last_name }}
              <span v-if="getPorterAbsence(porter.porter_id)?.absence_type === 'illness'" class="absence-badge">ILL</span>
              <span v-if="getPorterAbsence(porter.porter_id)?.absence_type === 'annual_leave'" class="absence-badge">AL</span>
            </span>
          </div>
        </div>
        
        <!-- Show department coverage gap warning if no available porters -->
        <div v-if="availablePorters.length === 0 && porterAssignments.length > 0" class="coverage-warning">
          All assigned porters are absent!
        </div>
      </div>
    </div>
    
    <!-- Edit Department Modal -->
    <EditDepartmentModal 
      v-if="showEditModal" 
      :assignment="assignment"
      @close="showEditModal = false"
      @update="handleUpdate"
      @remove="handleRemove"
    />
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useAreaCoverStore } from '../../stores/areaCoverStore';
import { useStaffStore } from '../../stores/staffStore';
import EditDepartmentModal from './EditDepartmentModal.vue';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['update', 'remove']);

const areaCoverStore = useAreaCoverStore();
const staffStore = useStaffStore();
const showEditModal = ref(false);

// Get porter assignments for this area
const porterAssignments = computed(() => {
  return areaCoverStore.getPorterAssignmentsByAreaId(props.assignment.id);
});

// Check if there's a coverage gap
const hasCoverageGap = computed(() => {
  try {
    return areaCoverStore.hasCoverageGap(props.assignment.id);
  } catch (error) {
    console.error('Error checking coverage gap:', error);
    return false;
  }
});

// Check if there's a staffing shortage
const hasStaffingShortage = computed(() => {
  try {
    return areaCoverStore.hasStaffingShortage(props.assignment.id);
  } catch (error) {
    console.error('Error checking staffing shortage:', error);
    return false;
  }
});

// Get all available (non-absent) porters
const availablePorters = computed(() => {
  const today = new Date();
  return porterAssignments.value.filter(assignment => {
    return !staffStore.isPorterAbsent(assignment.porter_id, today);
  });
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

// Sort porter assignments by start time (only available porters)
const sortedPorterAssignments = computed(() => {
  return [...availablePorters.value].sort((a, b) => {
    const aStart = timeToMinutes(a.start_time);
    const bStart = timeToMinutes(b.start_time);
    return aStart - bStart;
  });
});

// Get coverage gaps with detailed information
const coverageGaps = computed(() => {
  try {
    return areaCoverStore.getCoverageGaps ? 
      areaCoverStore.getCoverageGaps(props.assignment.id) : 
      { hasGap: false, gaps: [] };
  } catch (error) {
    console.error('Error getting coverage gaps:', error);
    return { hasGap: false, gaps: [] };
  }
});

// Get staffing shortages with detailed information
const staffingShortages = computed(() => {
  try {
    return areaCoverStore.getStaffingShortages ? 
      areaCoverStore.getStaffingShortages(props.assignment.id) : 
      { hasShortage: false, shortages: [] };
  } catch (error) {
    console.error('Error getting staffing shortages:', error);
    return { hasShortage: false, shortages: [] };
  }
});

// Check if there's a gap at the start of the assignment
const hasStartGap = computed(() => {
  if (sortedPorterAssignments.value.length === 0) return true;
  
  const departmentStart = timeToMinutes(props.assignment.start_time);
  const firstPorterStart = timeToMinutes(sortedPorterAssignments.value[0].start_time);
  
  return firstPorterStart > departmentStart;
});

// Check if there's a gap at the end of the assignment
const hasEndGap = computed(() => {
  if (sortedPorterAssignments.value.length === 0) return true;
  
  const departmentEnd = timeToMinutes(props.assignment.end_time);
  const lastPorterEnd = timeToMinutes(sortedPorterAssignments.value[sortedPorterAssignments.value.length - 1].end_time);
  
  return lastPorterEnd < departmentEnd;
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
    // There's a gap, check if it matches any known gaps
    coverageGaps.value.gaps.forEach(gap => {
      const gapStart = timeToMinutes(gap.startTime);
      const gapEnd = timeToMinutes(gap.endTime);
      
      // If this gap matches the one between these assignments
      if (Math.abs(gapStart - currentEnd) < 5 && Math.abs(gapEnd - nextStart) < 5) {
        gaps.push(gap);
      }
    });
    
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

.department-card {
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
    position: relative;
    min-height: 80px;
  }
  
  &__name {
    font-weight: 600;
    font-size: mix.font-size('md');
    margin-bottom: 4px;
  }
  
  &__footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: auto;
    padding-top: 8px;
    position: absolute;
    bottom: 12px;
    left: 16px;
    right: 16px;
    width: calc(100% - 32px);
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
    
    .porter-count-wrapper {
      margin-bottom: 10px;
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
      margin: 8px 0;
      position: relative;
      padding-left: 12px;
      padding-top: 4px;
      padding-bottom: 4px;
      border-top: 1px solid #F4B400; /* Default orange for time discrepancies */
      
      .gap-line-indicator {
        position: absolute;
        left: 0;
        top: 50%;
        transform: translateY(-50%);
        width: 4px;
        height: 20px; /* Fixed height for better visibility */
        background-color: #F4B400; /* Default orange for time discrepancies */
        border-radius: 2px;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2); /* Add shadow for better visibility */
      }
      
      .gap-line-time {
        font-size: mix.font-size('2xs');
        color: rgba(0, 0, 0, 0.5);
        padding: 2px 6px;
        background-color: rgba(234, 67, 53, 0.05);
        border-radius: mix.radius('sm');
        display: inline-block;
      }
    }
    
    /* Specific styles for start/end gap lines - these are outside .porter-assignments */
    .gap-line--start, 
    .gap-line--end {
      margin: 10px 0;
      padding-top: 6px;
      border-top: 2px solid #EA4335 !important; /* Thicker red line for start/end gaps */
      background-color: rgba(234, 67, 53, 0.05); /* Light red background for better visibility */
      
      .gap-line-indicator {
        background-color: #EA4335 !important; /* Red for start/end gaps */
      }
    }
    
    /* Direct styling for the time text in start/end gap lines */
    .gap-line--start .gap-line-time, 
    .gap-line--end .gap-line-time {
      font-size: 0.75rem !important; /* Explicit small font size */
      font-weight: normal !important;
      line-height: 1.2 !important;
      color: rgba(0, 0, 0, 0.5) !important;
      padding: 2px 6px !important;
      background-color: rgba(234, 67, 53, 0.05) !important;
      border-radius: 4px !important;
      display: inline-block !important;
    }
    
    .porter-assignments {
      margin-top: 12px;
      
      .porter-assignment {
        font-size: mix.font-size('xs');
        margin-bottom: 8px;
        
        .porter-name {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 4px 8px;
          background-color: rgba(0, 0, 0, 0.02);
          border-radius: mix.radius('sm');
          
          .porter-time {
            color: rgba(0, 0, 0, 0.5);
            font-size: mix.font-size('2xs');
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
