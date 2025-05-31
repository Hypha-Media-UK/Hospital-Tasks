<template>
  <div 
    class="service-card" 
    :style="{ borderLeftColor: assignment.color || '#4285F4' }"
    @click="showEditModal = true"
    :class="{ 
      'has-coverage-gap': hasCoverageGap,
      'has-staffing-shortage': hasStaffingShortage 
    }"
  >
    <div class="service-card__content">
      <div class="service-card__name">
        {{ assignment.service.name }}
      </div>
      <div class="service-card__time">
        {{ formatTimeRange(assignment.start_time, assignment.end_time) }}
      </div>
      
      <div v-if="(isShiftAssignment || !isShiftAssignment) && porterAssignments.length > 0" class="service-card__porters">
        <div class="porter-count-wrapper">
          <span class="porter-count" :class="{ 
            'has-coverage-gap': hasCoverageGap,
            'has-staffing-shortage': hasStaffingShortage 
          }">
            {{ porterAssignments.length }} {{ porterAssignments.length === 1 ? 'Porter' : 'Porters' }}
            <span v-if="hasCoverageGap" class="gap-indicator">Gap</span>
            <span v-if="hasStaffingShortage" class="shortage-indicator">Understaffed</span>
          </span>
        </div>
        
        <div class="porter-assignments">
          <div v-for="(assignment, index) in sortedPorterAssignments" :key="assignment.id" class="porter-assignment">
            <div class="porter-name">
              {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
              <span class="porter-time">{{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}</span>
            </div>

            <!-- Gap indicator between assignments -->
            <div v-if="coverageGaps.gaps.length > 0 && index < sortedPorterAssignments.length - 1" 
                class="gap-line"
                v-for="gap in getGapsBetweenAssignments(assignment, sortedPorterAssignments[index + 1])"
                :key="gap.startTime">
              <div class="gap-line-indicator" :class="{ 'gap-type-shortage': gap.type === 'shortage' }"></div>
              <div class="gap-line-time">{{ formatTime(gap.startTime) }} - {{ formatTime(gap.endTime) }}</div>
            </div>
          </div>
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
const showEditModal = ref(false);

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

// Check if this is a shift-specific assignment
const isShiftAssignment = computed(() => {
  return !!props.assignment.shift_id;
});

// Check if there's a coverage gap
const hasCoverageGap = computed(() => {
  try {
    // Use the appropriate store's coverage gap checker based on assignment type
    if (isShiftAssignment.value) {
      return shiftsStore.hasServiceCoverageGap(props.assignment.id);
    } else {
      return supportServicesStore.hasCoverageGap(props.assignment.id);
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

// Sort porter assignments by start time
const sortedPorterAssignments = computed(() => {
  return [...porterAssignments.value].sort((a, b) => {
    const aStart = timeToMinutes(a.start_time);
    const bStart = timeToMinutes(b.start_time);
    return aStart - bStart;
  });
});

// Get coverage gaps with detailed information
const coverageGaps = computed(() => {
  if (isShiftAssignment.value) {
    // Use shiftsStore's getServiceCoverageGaps if it exists, otherwise return empty
    return shiftsStore.getServiceCoverageGaps ? 
      shiftsStore.getServiceCoverageGaps(props.assignment.id) : 
      { hasGap: false, gaps: [] };
  } else {
    // Use supportServicesStore's getCoverageGaps if it exists, otherwise return empty
    return supportServicesStore.getCoverageGaps ? 
      supportServicesStore.getCoverageGaps(props.assignment.id) : 
      { hasGap: false, gaps: [] };
  }
});

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
  
  &.has-coverage-gap {
    &::after {
      content: '';
      position: absolute;
      top: 0;
      right: 0;
      width: 0;
      height: 0;
      border-style: solid;
      border-width: 0 12px 12px 0;
      border-color: transparent #EA4335 transparent transparent;
    }
  }
  
  &.has-staffing-shortage {
    &::before {
      content: '';
      position: absolute;
      top: 0;
      left: 12px;
      width: 0;
      height: 0;
      border-style: solid;
      border-width: 0 12px 12px 0;
      border-color: transparent #F4B400 transparent transparent;
      transform: rotate(90deg);
    }
  }
  
  &__content {
    padding: 12px 16px;
  }
  
  &__name {
    font-weight: 600;
    font-size: mix.font-size('md');
    margin-bottom: 4px;
  }
  
  &__time {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.7);
    padding: 2px 6px;
    background-color: rgba(0, 0, 0, 0.05);
    border-radius: mix.radius('sm');
  }
  
  &__description {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
    margin-bottom: 8px;
  }
  
  &__porters {
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
      
      &.has-coverage-gap {
        background-color: rgba(234, 67, 53, 0.1);
        color: #EA4335;
      }
      
      .gap-indicator, .shortage-indicator {
        background-color: #EA4335;
        color: white;
        font-size: mix.font-size('2xs');
        padding: 1px 4px;
        border-radius: 100px;
      }
      
      .shortage-indicator {
        background-color: #F4B400;
      }
      
      &.has-staffing-shortage {
        background-color: rgba(244, 180, 0, 0.1);
        color: #F4B400;
      }
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
      
      .gap-line {
        margin: 4px 0;
        position: relative;
        padding-left: 12px;
        
        .gap-line-indicator {
          position: absolute;
          left: 0;
          top: 50%;
          transform: translateY(-50%);
          width: 4px;
          height: 20px; /* Fixed height for better visibility */
          background-color: #EA4335;
          border-radius: 2px;
          border: 1px solid rgba(0, 0, 0, 0.1); /* Add border for better visibility */
          box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2); /* Add shadow for better visibility */
          
          &.gap-type-shortage {
            background-color: #F4B400;
          }
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
    }
  }
}
</style>
