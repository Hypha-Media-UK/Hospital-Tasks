<template>
  <div class="modal-overlay" @click.self="closeModal">
    <div class="sitrep-modal">
      <div class="modal-header">
        <h2>Situation Report (SitRep)</h2>
        <div class="modal-actions">
          <button @click="printSheet" class="btn btn-primary">
            Print
          </button>
          <button @click="closeModal" class="close-button">&times;</button>
        </div>
      </div>
      
      <div class="modal-body">
        <div class="sitrep-sheet">
          <div class="sheet-header">
            <h2>Situation Report</h2>
            <p class="sheet-info">
              {{ getShiftTypeDisplayName() }} | {{ formatShortDate(shift.start_time) }}
            </p>
          </div>
          
          <div class="sheet-content">
            <!-- Shift Summary -->
            <div class="shift-summary">
              <div class="summary-stats">
                <div class="stat-item">
                  <span class="stat-label">Total Porters:</span>
                  <span class="stat-value">{{ sortedPorters.length }}</span>
                </div>
                <div class="stat-item">
                  <span class="stat-label">Shift Duration:</span>
                  <span class="stat-value">{{ formatShiftDuration() }}</span>
                </div>
                <div class="stat-item">
                  <span class="stat-label">Supervisor:</span>
                  <span class="stat-value">{{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}</span>
                </div>
              </div>
            </div>
            
            <!-- Time ruler -->
            <div class="time-ruler-container">
              <div class="porter-name-spacer"></div>
              <div class="time-ruler">
                <div 
                  v-for="hour in timelineHours" 
                  :key="hour.label"
                  :class="['time-marker', { 'main-hour': hour.isMainHour, 'shift-time': hour.isShiftTime }]"
                  :style="{ left: getHourPosition(hour) + '%' }"
                >
                  {{ hour.label }}
                </div>
              </div>
            </div>
            
            <!-- Porter timeline grid -->
            <div class="sitrep-grid">
              <div v-for="porter in sortedPorters" :key="porter.id" class="porter-row">
                <div class="porter-name">
                  <div class="porter-name-text">
                    {{ porter.porter.first_name }} {{ porter.porter.last_name }}
                  </div>
                  <div class="porter-hours">
                    {{ formatPorterHours(porter.porter_id) }}
                  </div>
                </div>
                <div class="porter-timeline">
                  <div 
                    v-for="block in getPorterGanttBlocks(porter.porter_id)" 
                    :key="block.id"
                    :class="['timeline-block', `block-${block.type}`]"
                    :style="{
                      left: block.leftPercent + '%',
                      width: block.widthPercent + '%'
                    }"
                    :title="block.tooltip"
                  >
                    <span class="block-label">{{ block.label }}</span>
                  </div>
                </div>
              </div>
            </div>
            
            <div class="legend">
              <div class="legend-item">
                <div class="legend-box available"></div>
                <span>Available</span>
              </div>
              <div class="legend-item">
                <div class="legend-box allocated"></div>
                <span>Allocated to Department/Service</span>
              </div>
              <div class="legend-item">
                <div class="legend-box off-duty"></div>
                <span>Off Duty</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useSettingsStore } from '../stores/settingsStore';
import { useLocationsStore } from '../stores/locationsStore';

const props = defineProps({
  shift: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close']);

const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const settingsStore = useSettingsStore();
const locationsStore = useLocationsStore();

// Generate Gantt chart timeline - only shift hours with simple hour format
const timelineHours = computed(() => {
  if (!props.shift) return [];
  
  const hours = [];
  
  // Get shift defaults from settings to determine proper shift duration
  const shiftDefaults = settingsStore.shiftDefaults[props.shift.shift_type];
  if (!shiftDefaults) return [];
  
  // Parse start and end times from shift defaults
  const [startHour] = shiftDefaults.startTime.split(':').map(Number);
  const [endHour] = shiftDefaults.endTime.split(':').map(Number);
  
  // Handle overnight shifts (e.g., 20:00 to 08:00)
  const isOvernightShift = endHour < startHour;
  
  let currentHour = startHour;
  let hourCount = 0;
  const maxHours = 24; // Safety limit
  
  while (hourCount < maxHours) {
    // Format label as simple hour number without :00 suffix
    const label = currentHour.toString();
    
    hours.push({
      hour: currentHour,
      label: label,
      isShiftTime: true
    });
    
    // Check if we've reached the end
    if (currentHour === endHour && hourCount > 0) {
      break;
    }
    
    // Move to next hour
    currentHour = (currentHour + 1) % 24;
    hourCount++;
    
    // For non-overnight shifts, stop when we reach end hour
    if (!isOvernightShift && currentHour === endHour) {
      break;
    }
  }
  
  return hours;
});

// Get porter pool data
const porterPool = computed(() => {
  return shiftsStore.shiftPorterPool || [];
});

// Sort porters by building allocation, then by availability
// Exclude the shift supervisor from the porter list
const sortedPorters = computed(() => {
  if (!porterPool.value.length) return [];
  
  // Filter out the shift supervisor - they shouldn't appear in the porter timeline
  const porters = [...porterPool.value].filter(porter => {
    // Exclude if this porter is the shift supervisor
    if (props.shift.supervisor_id && porter.porter_id === props.shift.supervisor_id) {
      return false;
    }
    
    // Also exclude if marked as supervisor in the porter pool
    if (porter.is_supervisor) {
      return false;
    }
    
    return true;
  });
  
  return porters.sort((a, b) => {
    // Get building assignments for both porters
    const aBuildingAssignments = shiftsStore.getPorterBuildingAssignments(a.porter_id);
    const bBuildingAssignments = shiftsStore.getPorterBuildingAssignments(b.porter_id);
    
    // Get building names for sorting
    const aBuildings = aBuildingAssignments.map(buildingId => 
      locationsStore.buildings.find(b => b.id === buildingId)?.name || ''
    ).filter(Boolean).sort();
    
    const bBuildings = bBuildingAssignments.map(buildingId => 
      locationsStore.buildings.find(b => b.id === buildingId)?.name || ''
    ).filter(Boolean).sort();
    
    // Primary sort: By building assignment status
    // 1. Porters with building assignments first
    // 2. Unassigned porters last
    const aHasBuildings = aBuildings.length > 0;
    const bHasBuildings = bBuildings.length > 0;
    
    if (aHasBuildings !== bHasBuildings) {
      return bHasBuildings ? 1 : -1; // Building-assigned porters first
    }
    
    // Secondary sort: By building name (alphabetical)
    if (aHasBuildings && bHasBuildings) {
      const aPrimaryBuilding = aBuildings[0];
      const bPrimaryBuilding = bBuildings[0];
      
      if (aPrimaryBuilding !== bPrimaryBuilding) {
        return aPrimaryBuilding.localeCompare(bPrimaryBuilding);
      }
    }
    
    // Tertiary sort: By unavailability time (latest first - those available longest)
    const aUnavailableTime = getPorterUnavailableTime(a.porter_id);
    const bUnavailableTime = getPorterUnavailableTime(b.porter_id);
    
    if (aUnavailableTime !== bUnavailableTime) {
      return bUnavailableTime - aUnavailableTime; // Descending order (latest first)
    }
    
    // Final sort: Alphabetical by name for ties
    const aName = `${a.porter.first_name} ${a.porter.last_name}`;
    const bName = `${b.porter.first_name} ${b.porter.last_name}`;
    return aName.localeCompare(bName);
  });
});

// Calculate when a porter becomes unavailable (earliest of allocation start or contracted end)
const getPorterUnavailableTime = (porterId) => {
  const porter = staffStore.porters.find(p => p.id === porterId);
  if (!porter) return 0;
  
  // Get shift timeline bounds
  const shiftStartMinutes = timeToMinutesWithNightShift(`${timelineHours.value[0]?.hour || 0}:00`);
  const shiftEndMinutes = timeToMinutesWithNightShift(`${timelineHours.value[timelineHours.value.length - 1]?.hour || 23}:00`);

  // Get porter's contracted end time
  const contractedEndMinutes = porter.contracted_hours_end ?
    timeToMinutesWithNightShift(porter.contracted_hours_end) : shiftEndMinutes;

  // Get porter's first allocation start time
  const allocations = getPorterAllocations(porterId);
  const firstAllocationMinutes = allocations.length > 0 ?
    Math.min(...allocations.map(a => timeToMinutesWithNightShift(a.start_time))) : Infinity;
  
  // Return the earliest time they become unavailable
  // If no allocations, they become unavailable at contracted end time
  // If they have allocations, they become unavailable at the earlier of first allocation or contracted end
  if (firstAllocationMinutes === Infinity) {
    return contractedEndMinutes; // No allocations, unavailable at contracted end
  } else {
    return Math.min(firstAllocationMinutes, contractedEndMinutes); // Earliest of allocation or contracted end
  }
};

// Get all allocations for a porter (departments and services)
const getPorterAllocations = (porterId) => {
  const departmentAssignments = shiftsStore.shiftAreaCoverPorterAssignments?.filter(a => a.porter_id === porterId) || [];
  const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments?.filter(a => a.porter_id === porterId) || [];
  
  return [...departmentAssignments, ...serviceAssignments];
};

import { timeToMinutes } from '../utils/timeUtils';

// Helper functions
const timeToMinutesWithNightShift = (timeStr) => {
  const isNightShift = props.shift && props.shift.shift_type.includes('night');
  return timeToMinutes(timeStr, { handleNightShift: isNightShift });
};

// Format date as "29th May 2025"
const formatShortDate = (dateString) => {
  if (!dateString) return '';
  
  const date = new Date(dateString);
  
  // Get day with ordinal suffix (1st, 2nd, 3rd, etc.)
  const day = date.getDate();
  const suffix = getDayOrdinalSuffix(day);
  
  // Format date in the requested format
  const formatter = new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  });
  
  const parts = formatter.formatToParts(date);
  const month = parts.find(part => part.type === 'month').value;
  const year = parts.find(part => part.type === 'year').value;
  
  return `${day}${suffix} ${month} ${year}`;
};

// Helper to get the correct ordinal suffix for a day
const getDayOrdinalSuffix = (day) => {
  if (day > 3 && day < 21) return 'th';
  switch (day % 10) {
    case 1: return 'st';
    case 2: return 'nd';
    case 3: return 'rd';
    default: return 'th';
  }
};

// Get display name for shift type
const getShiftTypeDisplayName = () => {
  if (!props.shift) return 'Shift';
  
  // Simplify shift type display to just "Day Shift" or "Night Shift"
  if (props.shift.shift_type.includes('day')) {
    return 'Day Shift';
  } else if (props.shift.shift_type.includes('night')) {
    return 'Night Shift';
  } else {
    return 'Shift';
  }
};

// Format shift duration
const formatShiftDuration = () => {
  if (!timelineHours.value.length) return 'Unknown';
  
  const hours = timelineHours.value.length;
  return `${hours} hours`;
};

// Format porter hours (contracted hours)
const formatPorterHours = (porterId) => {
  const porter = staffStore.porters.find(p => p.id === porterId);
  if (!porter || !porter.contracted_hours_start || !porter.contracted_hours_end) {
    return 'All hours';
  }
  
  return `${porter.contracted_hours_start} - ${porter.contracted_hours_end}`;
};

// Get hour position as percentage for time ruler
const getHourPosition = (hour) => {
  if (!timelineHours.value.length) return 0;
  
  const hourIndex = timelineHours.value.findIndex(h => h.hour === hour.hour);
  if (hourIndex >= 0) {
    // Position at the start of each hour column
    return (hourIndex / timelineHours.value.length) * 100;
  }
  
  return 0;
};

// Generate Gantt chart blocks for a porter
const getPorterGanttBlocks = (porterId) => {
  const blocks = [];
  const porter = staffStore.porters.find(p => p.id === porterId);
  
  if (!porter || !timelineHours.value.length) {
    return blocks;
  }
  
  const totalHours = timelineHours.value.length;
  
  // Get porter's contracted hours
  const contractedStartHour = porter.contracted_hours_start ? 
    parseInt(porter.contracted_hours_start.split(':')[0]) : timelineHours.value[0].hour;
  const contractedEndHour = porter.contracted_hours_end ? 
    parseInt(porter.contracted_hours_end.split(':')[0]) : timelineHours.value[timelineHours.value.length - 1].hour;
  
  // Get all assignments for this porter
  const departmentAssignments = shiftsStore.shiftAreaCoverPorterAssignments?.filter(a => a.porter_id === porterId) || [];
  const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments?.filter(a => a.porter_id === porterId) || [];
  
  // Combine all assignments
  const allAssignments = [];
  
  // Add department assignments
  departmentAssignments.forEach((assignment, index) => {
    const areaCover = shiftsStore.shiftAreaCoverAssignments?.find(a => a.id === assignment.shift_area_cover_assignment_id);
    if (areaCover) {
      const startHour = parseInt(assignment.start_time.split(':')[0]);
      const endHour = parseInt(assignment.end_time.split(':')[0]);
      
      allAssignments.push({
        id: `dept-${index}`,
        startHour,
        endHour,
        label: areaCover.department?.name || 'Department',
        type: 'allocated'
      });
    }
  });
  
  // Add service assignments
  serviceAssignments.forEach((assignment, index) => {
    const service = shiftsStore.shiftSupportServiceAssignments?.find(a => a.id === assignment.shift_support_service_assignment_id);
    if (service) {
      const startHour = parseInt(assignment.start_time.split(':')[0]);
      const endHour = parseInt(assignment.end_time.split(':')[0]);
      
      allAssignments.push({
        id: `service-${index}`,
        startHour,
        endHour,
        label: service.service?.name || 'Service',
        type: 'allocated'
      });
    }
  });
  
  // Sort assignments by start time
  allAssignments.sort((a, b) => a.startHour - b.startHour);
  
  // Helper function to find hour index in timeline
  const findHourIndex = (hour) => {
    return timelineHours.value.findIndex(h => h.hour === hour);
  };
  
  // Create blocks for the entire timeline
  let currentHour = timelineHours.value[0].hour;
  
  timelineHours.value.forEach((hour, index) => {
    const hourValue = hour.hour;
    
    // Check if porter is on duty during this hour
    const isOnDuty = (hourValue >= contractedStartHour && hourValue < contractedEndHour) ||
                     (contractedEndHour < contractedStartHour && (hourValue >= contractedStartHour || hourValue < contractedEndHour));
    
    // Check if porter has an assignment during this hour
    const assignment = allAssignments.find(a => 
      (hourValue >= a.startHour && hourValue < a.endHour) ||
      (a.endHour < a.startHour && (hourValue >= a.startHour || hourValue < a.endHour))
    );
    
    let blockType, label;
    
    if (assignment) {
      blockType = 'allocated';
      label = assignment.label;
    } else if (isOnDuty) {
      blockType = 'available';
      label = '';
    } else {
      blockType = 'off-duty';
      label = 'Off Duty';
    }
    
    blocks.push({
      id: `hour-${index}`,
      leftPercent: (index / totalHours) * 100,
      widthPercent: (1 / totalHours) * 100,
      type: blockType,
      label: label,
      tooltip: `${hourValue}:00 - ${blockType === 'allocated' ? label : blockType}`
    });
  });
  
  return blocks;
};

// Historical absence data for SitRep
const historicalAbsences = ref([]);

// Fetch all historical absences for this shift
const fetchHistoricalAbsences = async () => {
  try {
    const { supabase } = await import('../services/supabase');
    
    const { data, error } = await supabase
      .from('shift_porter_absences')
      .select(`
        *,
        porter:porter_id(id, first_name, last_name)
      `)
      .eq('shift_id', props.shift.id);
    
    if (error) {
      return;
    }
    
    historicalAbsences.value = data || [];
  } catch (error) {
    // Error handling without console logging
  }
};

// Close the modal
const closeModal = () => {
  emit('close');
};

// Print the sheet
const printSheet = () => {
  window.print();
};

// Load data when component mounts
onMounted(async () => {
  await fetchHistoricalAbsences();
});
</script>

<style lang="scss" scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.sitrep-modal {
  background-color: white;
  border-radius: 8px;
  width: 95%;
  max-width: 1200px;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e0e0e0;
  
  h2 {
    margin: 0;
    font-size: 1.25rem;
  }
  
  .modal-actions {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }
  
  .close-button {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0;
    line-height: 1;
    margin-left: 0.5rem;
  }
}

.modal-body {
  padding: 1.5rem;
}

.sitrep-sheet {
  font-family: 'Arial', sans-serif;
  
  .sheet-header {
    text-align: center;
    margin-bottom: 2rem;
    
    h2 {
      margin: 0 0 0.5rem 0;
      font-size: 1.5rem;
      font-weight: bold;
    }
    
    .sheet-info {
      margin: 0;
      font-size: 1rem;
      color: #666;
    }
  }
}

.shift-summary {
  margin-bottom: 2rem;
  
  .summary-stats {
    display: flex;
    justify-content: space-around;
    flex-wrap: wrap;
    gap: 1rem;
    
    .stat-item {
      text-align: center;
      
      .stat-label {
        display: block;
        font-weight: bold;
        margin-bottom: 0.25rem;
      }
      
      .stat-value {
        display: block;
        font-size: 1.1rem;
      }
    }
  }
}

.time-ruler-container {
  display: flex;
  margin-bottom: 1rem;
  
  .porter-name-spacer {
    width: 200px;
    flex-shrink: 0;
  }
  
  .time-ruler {
    flex: 1;
    position: relative;
    height: 30px;
    border-bottom: 2px solid #333;
    
    .time-marker {
      position: absolute;
      font-size: 0.8rem;
      font-weight: bold;
      transform: translateX(-50%);
      
      &.shift-time {
        color: #333;
      }
    }
  }
}

.sitrep-grid {
  .porter-row {
    display: flex;
    border-bottom: 1px solid #e0e0e0;
    min-height: 40px;
    
    .porter-name {
      width: 200px;
      flex-shrink: 0;
      padding: 0.5rem;
      display: flex;
      flex-direction: column;
      justify-content: center;
      border-right: 1px solid #e0e0e0;
      
      .porter-name-text {
        font-weight: bold;
        font-size: 0.9rem;
      }
      
      .porter-hours {
        font-size: 0.8rem;
        color: #666;
        margin-top: 0.25rem;
      }
    }
    
    .porter-timeline {
      flex: 1;
      position: relative;
      min-height: 40px;
      
      .timeline-block {
        position: absolute;
        top: 2px;
        bottom: 2px;
        border-radius: 3px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 0.7rem;
        font-weight: bold;
        color: white;
        text-shadow: 1px 1px 1px rgba(0, 0, 0, 0.5);
        
        &.block-available {
          background-color: #4CAF50;
        }
        
        &.block-allocated {
          background-color: #2196F3;
        }
        
        &.block-off-duty {
          background-color: #9E9E9E;
        }
        
        .block-label {
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
          padding: 0 4px;
        }
      }
    }
  }
}

.legend {
  display: flex;
  justify-content: center;
  gap: 2rem;
  margin-top: 2rem;
  flex-wrap: wrap;
  
  .legend-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    
    .legend-box {
      width: 20px;
      height: 15px;
      border-radius: 3px;
      
      &.available {
        background-color: #4CAF50;
      }
      
      &.allocated {
        background-color: #2196F3;
      }
      
      &.off-duty {
        background-color: #9E9E9E;
      }
    }
    
    span {
      font-size: 0.9rem;
    }
  }
}

.btn {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
  
  &-primary {
    background-color: #4285F4;
    color: white;
    
    &:hover {
      background-color: #3367D6;
    }
  }
}

// Print styles
@media print {
  .modal-overlay {
    position: static;
    background: none;
    
    .sitrep-modal {
      box-shadow: none;
      max-height: none;
      width: 100%;
      max-width: none;
    }
    
    .modal-header {
      display: none;
    }
    
    .modal-body {
      padding: 0;
    }
  }
  
  .sitrep-sheet {
    font-size: 12px;
    
    .porter-name {
      width: 150px !important;
    }
    
    .porter-name-spacer {
      width: 150px !important;
    }
  }
}
</style>
