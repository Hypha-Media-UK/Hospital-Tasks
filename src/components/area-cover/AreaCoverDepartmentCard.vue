<template>
  <div
    class="department-card"
    :style="{ borderLeftColor: assignment.department.color || '#CCCCCC' }"
    @click="showEditModal = true"
  >
    <div class="department-card__header">
      <div class="department-card__name">
        {{ assignment.department.name }}
      </div>
      <div class="department-card__time">
        {{ formatTimeRange(assignment.start_time, assignment.end_time) }}
      </div>
    </div>
      
      <div class="department-card__porters">
        <!-- Gap at start if first porter starts after department start time -->
        <div v-if="sortedPorterAssignments.length > 0 && hasStartGap" class="gap-line">
          <hr class="gap-line-hr" />
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
              <hr class="gap-line-hr" />
              <div class="gap-line-time">{{ formatTime(gap.startTime) }} - {{ formatTime(gap.endTime) }}</div>
            </div>
          </div>
        </div>

        <!-- Gap at end if last porter ends before department end time -->
        <div v-if="sortedPorterAssignments.length > 0 && hasEndGap" class="gap-line">
          <hr class="gap-line-hr" />
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

  <!-- Edit Department Modal - Teleported to body to avoid container constraints -->
  <Teleport to="body">
    <EditDepartmentModal
      v-if="showEditModal"
      :assignment="assignment"
      @close="showEditModal = false"
      @update="handleUpdate"
      @remove="handleRemove"
    />
  </Teleport>
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

// Get unique porter assignments for this area (removes duplicates)
const porterAssignments = computed(() => {
  return areaCoverStore.getUniquePorterAssignmentsByAreaId(props.assignment.id);
});

// Check if there's a coverage gap (temporarily disabled)
const hasCoverageGap = computed(() => {
  return false; // Temporarily disabled to focus on core functionality
});

// Check if there's a staffing shortage (temporarily disabled)
const hasStaffingShortage = computed(() => {
  return false; // Temporarily disabled to focus on core functionality
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
    return areaCoverStore.getCoverageGaps(props.assignment.id);
  } catch (error) {
    console.error('Error getting coverage gaps:', error);
    return { hasGap: false, gaps: [] };
  }
});

// Get staffing shortages with detailed information
const staffingShortages = computed(() => {
  try {
    return areaCoverStore.getStaffingShortages(props.assignment.id);
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