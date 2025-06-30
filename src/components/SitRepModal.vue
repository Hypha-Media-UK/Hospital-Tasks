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
  const shiftStartMinutes = timeToMinutes(`${timelineHours.value[0]?.hour || 0}:00`);
  const shiftEndMinutes = timeToMinutes(`${timelineHours.value[timelineHours.value.length - 1]?.hour || 23}:00`);
  
  // Get porter's contracted end time
  const contractedEndMinutes = porter.contracted_hours_end ? 
    timeToMinutes(porter.contracted_hours_end) : shiftEndMinutes;
  
  // Get porter's first allocation start time
  const allocations = getPorterAllocations(porterId);
  const firstAllocationMinutes = allocations.length > 0 ? 
    Math.min(...allocations.map(a => timeToMinutes(a.start_time))) : Infinity;
  
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

// Calculate porter availability percentage across the shift
const calculatePorterAvailability = (porterId) => {
  let availableHours = 0;
  
  timelineHours.value.forEach(hour => {
    const status = getPorterStatusForHour(porterId, hour);
    if (status === 'available') {
      availableHours++;
    }
  });
  
  return timelineHours.value.length > 0 ? (availableHours / timelineHours.value.length) : 0;
};

// Get porter status for a specific hour with detailed unavailability reasons
const getPorterStatusForHour = (porterId, hour) => {
  // Check if porter is on duty during this hour
  if (!isPorterOnDutyDuringHour(porterId, hour)) {
    return 'off-duty';
  }
  
  // Check for scheduled absences
  if (isPorterAbsentDuringHour(porterId, hour)) {
    return 'absent';
  }
  
  // Check for department assignments
  const departmentAssignment = getDepartmentAssignmentForHour(porterId, hour);
  if (departmentAssignment) {
    return 'allocated';
  }
  
  // Check for service assignments
  const serviceAssignment = getServiceAssignmentForHour(porterId, hour);
  if (serviceAssignment) {
    return 'allocated';
  }
  
  return 'available';
};

// Get detailed unavailability reason for a porter at a specific hour
const getUnavailabilityReason = (porterId, hour) => {
  // Check if porter is off duty (outside contracted hours)
  if (!isPorterOnDutyDuringHour(porterId, hour)) {
    return 'Off Duty';
  }
  
  // Check for scheduled absences and return the reason using historical data
  const absences = historicalAbsences.value.filter(a => a.porter_id === porterId);
  const activeAbsence = absences.find(absence => {
    const absenceStart = timeToMinutes(absence.start_time);
    const absenceEnd = timeToMinutes(absence.end_time);
    return isTimeRangeOverlapping(hour.startMinutes, hour.endMinutes, absenceStart, absenceEnd);
  });
  
  if (activeAbsence) {
    return activeAbsence.absence_reason || 'Absent';
  }
  
  return '';
};

// Check if porter is on duty during a specific hour based on contracted hours
const isPorterOnDutyDuringHour = (porterId, hour) => {
  const porter = staffStore.porters.find(p => p.id === porterId);
  if (!porter || !porter.contracted_hours_start || !porter.contracted_hours_end) {
    return true; // Assume on duty if no contracted hours set
  }
  
  const startMinutes = timeToMinutes(porter.contracted_hours_start);
  const endMinutes = timeToMinutes(porter.contracted_hours_end);
  
  // Use the same logic as the porter pool for consistency
  // Check if hour overlaps with contracted hours, handling overnight shifts properly
  if (endMinutes < startMinutes) {
    // Overnight shift (e.g., 22:00 to 06:00)
    return hour.startMinutes >= startMinutes || hour.endMinutes <= endMinutes;
  } else {
    // Normal shift (e.g., 10:00 to 22:00)
    return hour.startMinutes < endMinutes && hour.endMinutes > startMinutes;
  }
};

// Check if porter is absent during a specific hour using historical data
const isPorterAbsentDuringHour = (porterId, hour) => {
  const absences = historicalAbsences.value.filter(a => a.porter_id === porterId);
  
  return absences.some(absence => {
    const absenceStart = timeToMinutes(absence.start_time);
    const absenceEnd = timeToMinutes(absence.end_time);
    return isTimeRangeOverlapping(hour.startMinutes, hour.endMinutes, absenceStart, absenceEnd);
  });
};

// Get department assignment for a specific hour
const getDepartmentAssignmentForHour = (porterId, hour) => {
  const assignments = shiftsStore.shiftAreaCoverPorterAssignments.filter(a => a.porter_id === porterId);
  
  return assignments.find(assignment => {
    const assignmentStart = timeToMinutes(assignment.start_time);
    const assignmentEnd = timeToMinutes(assignment.end_time);
    return isTimeRangeOverlapping(hour.startMinutes, hour.endMinutes, assignmentStart, assignmentEnd);
  });
};

// Get service assignment for a specific hour
const getServiceAssignmentForHour = (porterId, hour) => {
  const assignments = shiftsStore.shiftSupportServicePorterAssignments.filter(a => a.porter_id === porterId);
  
  return assignments.find(assignment => {
    const assignmentStart = timeToMinutes(assignment.start_time);
    const assignmentEnd = timeToMinutes(assignment.end_time);
    return isTimeRangeOverlapping(hour.startMinutes, hour.endMinutes, assignmentStart, assignmentEnd);
  });
};

// Get CSS class for a cell
const getCellClass = (porterId, hour) => {
  const status = getPorterStatusForHour(porterId, hour);
  return `cell-${status}`;
};

// Get content for a cell
const getCellContent = (porterId, hour) => {
  const status = getPorterStatusForHour(porterId, hour);
  
  if (status === 'allocated') {
    // Check for department assignment first
    const departmentAssignment = getDepartmentAssignmentForHour(porterId, hour);
    if (departmentAssignment) {
      const assignment = shiftsStore.shiftAreaCoverAssignments.find(
        a => a.id === departmentAssignment.shift_area_cover_assignment_id
      );
      return assignment?.department?.name || 'Department';
    }
    
    // Check for service assignment
    const serviceAssignment = getServiceAssignmentForHour(porterId, hour);
    if (serviceAssignment) {
      const assignment = shiftsStore.shiftSupportServiceAssignments.find(
        a => a.id === serviceAssignment.shift_support_service_assignment_id
      );
      return assignment?.service?.name || 'Service';
    }
  } else if (status === 'off-duty' || status === 'absent') {
    // For unavailable periods, return the reason
    return getUnavailabilityReason(porterId, hour);
  }
  
  return ''; // Empty for available
};

// Helper functions
const timeToMinutes = (timeStr) => {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  let totalMinutes = (hours * 60) + minutes;
  
  // For night shifts, adjust times after midnight to ensure consistent calculation
  // This ensures that times like 02:00 (2 AM) are treated as being after 20:00 (8 PM) from the previous day
  if (props.shift && props.shift.shift_type.includes('night') && hours < 12) {
    totalMinutes += 24 * 60; // Add 24 hours worth of minutes
  }
  
  return totalMinutes;
};

const isTimeRangeOverlapping = (start1, end1, start2, end2) => {
  // Simple overlap check - works for both day and night shifts with adjusted minutes
  return start1 < end2 && end1 > start2;
};

const formatHour = (date) => {
  return date.toLocaleTimeString('en-GB', { 
    hour: '2-digit', 
    minute: '2-digit',
    hour12: false 
  });
};

const formatTimeForComparison = (date) => {
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
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

// Close the modal
const closeModal = () => {
  emit('close');
};

// Print the sheet
const printSheet = () => {
  window.print();
};

// Enhanced Gantt chart functionality - compute allocation spans for each porter including unavailable periods
const porterAllocationSpans = computed(() => {
  const spans = new Map();
  
  sortedPorters.value.forEach(porter => {
    const porterSpans = [];
    let currentSpan = null;
    
    timelineHours.value.forEach((hour, index) => {
      const status = getPorterStatusForHour(porter.porter_id, hour);
      const content = getCellContent(porter.porter_id, hour);
      const unavailabilityReason = getUnavailabilityReason(porter.porter_id, hour);
      
      // Determine if this hour can be merged with the previous span
      let canMerge = false;
      let spanContent = content;
      
      if (status === 'allocated' && content) {
        // For allocated hours, merge if same department/service
        canMerge = currentSpan && currentSpan.content === content && currentSpan.status === status;
        spanContent = content;
      } else if (status === 'off-duty' || status === 'absent') {
        // For unavailable hours, merge if same reason
        canMerge = currentSpan && currentSpan.unavailabilityReason === unavailabilityReason && currentSpan.status === status;
        spanContent = unavailabilityReason;
      } else {
        // Available hours don't merge
        canMerge = false;
        spanContent = '';
      }
      
      if (canMerge) {
        // Extend current span
        currentSpan.endIndex = index;
        currentSpan.colspan++;
      } else {
        // End current span if exists
        if (currentSpan) {
          porterSpans.push(currentSpan);
        }
        
        // Start new span
        currentSpan = {
          startIndex: index,
          endIndex: index,
          colspan: 1,
          content: spanContent,
          status: status,
          unavailabilityReason: unavailabilityReason
        };
      }
    });
    
    // Don't forget the last span
    if (currentSpan) {
      porterSpans.push(currentSpan);
    }
    
    spans.set(porter.porter_id, porterSpans);
  });
  
  return spans;
});

// Check if a cell should be rendered (not part of a previous span)
const shouldRenderCell = (porterId, hourIndex) => {
  const spans = porterAllocationSpans.value.get(porterId);
  if (!spans) return true;
  
  // Find the span that contains this hour index
  const span = spans.find(s => s.startIndex <= hourIndex && s.endIndex >= hourIndex);
  if (!span) return true;
  
  // Only render if this is the start of the span
  return span.startIndex === hourIndex;
};

// Get the colspan for a cell
const getCellSpan = (porterId, hourIndex) => {
  const spans = porterAllocationSpans.value.get(porterId);
  if (!spans) return 1;
  
  // Find the span that starts at this hour index
  const span = spans.find(s => s.startIndex === hourIndex);
  return span ? span.colspan : 1;
};

// Get the time range for a span (for display in merged cells)
const getSpanTimeRange = (porterId, hourIndex) => {
  const spans = porterAllocationSpans.value.get(porterId);
  if (!spans) return '';
  
  // Find the span that starts at this hour index
  const span = spans.find(s => s.startIndex === hourIndex);
  if (!span || span.colspan <= 1) return '';
  
  const startHour = timelineHours.value[span.startIndex];
  const endHour = timelineHours.value[span.endIndex];
  
  return `${startHour.startTime} - ${endHour.endTime}`;
};

// Historical absence data for SitRep (not cleaned up)
const historicalAbsences = ref([]);

// Fetch all historical absences for this shift (including expired ones)
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
      console.error('Error fetching historical absences:', error);
      return;
    }
    
    historicalAbsences.value = data || [];
    console.log(`Loaded ${historicalAbsences.value.length} historical absences for SitRep`);
  } catch (error) {
    console.error('Error in fetchHistoricalAbsences:', error);
  }
};

// Calculate total shift duration in minutes
const totalShiftMinutes = computed(() => {
  if (!timelineHours.value.length) return 0;
  
  const firstHour = timelineHours.value[0];
  const lastHour = timelineHours.value[timelineHours.value.length - 1];
  
  return lastHour.endMinutes - firstHour.startMinutes;
});

// Get hour position as percentage for time ruler - aligned with gantt bars
const getHourPosition = (hour) => {
  if (!timelineHours.value.length) return 0;
  
  const hourIndex = timelineHours.value.findIndex(h => h.hour === hour.hour);
  if (hourIndex >= 0) {
    // Position at the start of each hour column, accounting for the full timeline
    return (hourIndex / timelineHours.value.length) * 100;
  }
  
  return 0;
};

// Convert time string to minutes from shift start
const getMinutesFromShiftStart = (timeStr) => {
  if (!timelineHours.value.length) return 0;
  
  const timeMinutes = timeToMinutes(timeStr);
  const shiftStartMinutes = timelineHours.value[0].startMinutes;
  
  return timeMinutes - shiftStartMinutes;
};

// Generate accurate Gantt chart blocks for a porter including off-duty periods
const getPorterGanttBlocks = (porterId) => {
  const blocks = [];
  const porter = staffStore.porters.find(p => p.id === porterId);
  
  if (!porter || !timelineHours.value.length) {
    return blocks;
  }
  
  // Use hour-based calculations to match the time ruler positioning
  const totalHours = timelineHours.value.length;
  const shiftStartHour = timelineHours.value[0].hour;
  const shiftEndHour = timelineHours.value[timelineHours.value.length - 1].hour;
  
  // Get porter's contracted hours
  const contractedStartHour = porter.contracted_hours_start ? 
    parseInt(porter.contracted_hours_start.split(':')[0]) : shiftStartHour;
  const contractedEndHour = porter.contracted_hours_end ? 
    parseInt(porter.contracted_hours_end.split(':')[0]) : shiftEndHour;
  
  // Get all assignments for this porter with precise times
  const departmentAssignments = shiftsStore.shiftAreaCoverPorterAssignments?.filter(a => a.porter_id === porterId) || [];
  const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments?.filter(a => a.porter_id === porterId) || [];
  
  // Combine all assignments with detailed info
  const allAssignments = [];
  
  // Add department assignments
  departmentAssignments.forEach((assignment, index) => {
    const areaCover = shiftsStore.shiftAreaCoverAssignments?.find(a => a.id === assignment.shift_area_cover_assignment_id);
    if (areaCover) {
      allAssignments.push({
        id: `dept-${index}`,
        startMinutes: timeToMinutes(assignment.start_time),
        endMinutes: timeToMinutes(assignment.end_time),
        startTime: assignment.start_time,
        endTime: assignment.end_time,
        label: areaCover.department?.name || 'Department',
        type: 'allocated',
        color: areaCover.color || '#999'
      });
    }
  });
  
  // Add service assignments
  serviceAssignments.forEach((assignment, index) => {
    const service = shiftsStore.shiftSupportServiceAssignments?.find(a => a.id === assignment.shift_support_service_assignment_id);
    if (service) {
      allAssignments.push({
        id: `service-${index}`,
        startMinutes: timeToMinutes(assignment.start_time),
        endMinutes: timeToMinutes(assignment.end_time),
        startTime: assignment.start_time,
        endTime: assignment.end_time,
        label: service.service?.name || 'Service',
        type: 'allocated',
        color: service.color || '#999'
      });
    }
  });
  
  // Sort assignments by start time
  allAssignments.sort((a, b) => a.startMinutes - b.startMinutes);
  
  // Helper function to find hour index in timeline
  const findHourIndex = (hour) => {
    return timelineHours.value.findIndex(h => h.hour === hour);
  };
  
  // 1. Add off-duty block before contracted hours (if any)
  const contractedStartIndex = findHourIndex(contractedStartHour);
  const shiftStartIndex = 0;
  
  if (contractedStartIndex > shiftStartIndex) {
    const leftPercent = (shiftStartIndex / totalHours) * 100;
    const widthPercent = ((contractedStartIndex - shiftStartIndex) / totalHours) * 100;
    
    if (widthPercent > 0) {
      blocks.push({
        id: `${porterId}-off-duty-before`,
        type: 'off-duty',
        leftPercent: leftPercent,
        widthPercent: widthPercent,
        label: 'Off Duty',
        tooltip: `Off Duty: ${shiftStartHour}:00 - ${contractedStartHour}:00`
      });
    }
  }
  
  // 2. Process assignments using hour-based positioning
  allAssignments.forEach((assignment, index) => {
    const startHour = parseInt(assignment.startTime.split(':')[0]);
    const endHour = parseInt(assignment.endTime.split(':')[0]);
    
    const startIndex = findHourIndex(startHour);
    const endIndex = findHourIndex(endHour);
    
    if (startIndex >= 0 && endIndex >= 0) {
      const leftPercent = (startIndex / totalHours) * 100;
      const widthPercent = ((endIndex - startIndex) / totalHours) * 100;
      
      if (widthPercent > 0) {
        blocks.push({
          id: `${porterId}-assignment-${assignment.id}`,
          type: 'allocated',
          leftPercent: leftPercent,
          widthPercent: widthPercent,
          label: assignment.label,
          tooltip: `${assignment.label}: ${assignment.startTime.substring(0, 5)} - ${assignment.endTime.substring(0, 5)}`,
          color: assignment.color
        });
      }
    }
  });
  
  // 3. Add availability blocks for gaps between assignments and remaining time
  let currentHourIndex = Math.max(0, contractedStartIndex >= 0 ? contractedStartIndex : 0);
  const contractedEndIndex = findHourIndex(contractedEndHour);
  const effectiveEndIndex = contractedEndIndex >= 0 ? contractedEndIndex : totalHours;
  
  // Sort assignments by hour index for gap detection
  const sortedByHour = allAssignments
    .map(a => ({
      ...a,
      startIndex: findHourIndex(parseInt(a.startTime.split(':')[0])),
      endIndex: findHourIndex(parseInt(a.endTime.split(':')[0]))
    }))
    .filter(a => a.startIndex >= 0 && a.endIndex >= 0)
    .sort((a, b) => a.startIndex - b.startIndex);
  
  if (sortedByHour.length > 0) {
    // Process gaps between assignments
    sortedByHour.forEach((assignment, index) => {
      // Add availability block before this assignment if there's a gap
      if (currentHourIndex < assignment.startIndex) {
        const leftPercent = (currentHourIndex / totalHours) * 100;
        const widthPercent = ((assignment.startIndex - currentHourIndex) / totalHours) * 100;
        
        if (widthPercent > 0) {
          // Check if porter is assigned to any buildings for this time period
          const buildingAssignments = shiftsStore.getPorterBuildingAssignments(porterId);
          const assignedBuildings = buildingAssignments.map(buildingId => 
            locationsStore.buildings.find(b => b.id === buildingId)
          ).filter(Boolean);
          
          let label = 'Available';
          let tooltip = `Available: ${timelineHours.value[currentHourIndex]?.hour}:00 - ${timelineHours.value[assignment.startIndex]?.hour}:00`;
          
          if (assignedBuildings.length > 0) {
            // Use the first building's full name
            label = assignedBuildings[0].name;
            tooltip = `${assignedBuildings[0].name}: ${timelineHours.value[currentHourIndex]?.hour}:00 - ${timelineHours.value[assignment.startIndex]?.hour}:00`;
          }
          
          blocks.push({
            id: `${porterId}-available-${index}`,
            type: 'available',
            leftPercent: leftPercent,
            widthPercent: widthPercent,
            label: label,
            tooltip: tooltip
          });
        }
      }
      
      currentHourIndex = assignment.endIndex;
    });
    
    // Add final availability block if there's time remaining after last assignment
    if (currentHourIndex < effectiveEndIndex) {
      const leftPercent = (currentHourIndex / totalHours) * 100;
      const widthPercent = ((effectiveEndIndex - currentHourIndex) / totalHours) * 100;
      
      if (widthPercent > 0) {
        // Check if porter is assigned to any buildings for this time period
        const buildingAssignments = shiftsStore.getPorterBuildingAssignments(porterId);
        const assignedBuildings = buildingAssignments.map(buildingId => 
          locationsStore.buildings.find(b => b.id === buildingId)
        ).filter(Boolean);
        
        let label = 'Available';
        let tooltip = `Available: ${timelineHours.value[currentHourIndex]?.hour}:00 - ${contractedEndIndex >= 0 ? contractedEndHour : shiftEndHour}:00`;
        
        if (assignedBuildings.length > 0) {
          // Use the first building's full name
          label = assignedBuildings[0].name;
          tooltip = `${assignedBuildings[0].name}: ${timelineHours.value[currentHourIndex]?.hour}:00 - ${contractedEndIndex >= 0 ? contractedEndHour : shiftEndHour}:00`;
        }
        
        blocks.push({
          id: `${porterId}-available-final`,
          type: 'available',
          leftPercent: leftPercent,
          widthPercent: widthPercent,
          label: label,
          tooltip: tooltip
        });
      }
    }
  } else {
    // No assignments - create full availability block (this handles the case where assignments were removed)
    const startIndex = contractedStartIndex >= 0 ? contractedStartIndex : 0;
    const endIndex = contractedEndIndex >= 0 ? contractedEndIndex : totalHours;
    
    if (startIndex < endIndex) {
      const leftPercent = (startIndex / totalHours) * 100;
      const widthPercent = ((endIndex - startIndex) / totalHours) * 100;
      
      if (widthPercent > 0) {
        // Check if porter is assigned to any buildings for this time period
        const buildingAssignments = shiftsStore.getPorterBuildingAssignments(porterId);
        const assignedBuildings = buildingAssignments.map(buildingId => 
          locationsStore.buildings.find(b => b.id === buildingId)
        ).filter(Boolean);
        
        let label = 'Available';
        let tooltip = `Available: ${contractedStartIndex >= 0 ? contractedStartHour : shiftStartHour}:00 - ${contractedEndIndex >= 0 ? contractedEndHour : shiftEndHour}:00`;
        
        if (assignedBuildings.length > 0) {
          // Use the first building's full name
          label = assignedBuildings[0].name;
          tooltip = `${assignedBuildings[0].name}: ${contractedStartIndex >= 0 ? contractedStartHour : shiftStartHour}:00 - ${contractedEndIndex >= 0 ? contractedEndHour : shiftEndHour}:00`;
        }
        
        blocks.push({
          id: `${porterId}-available-all`,
          type: 'available',
          leftPercent: leftPercent,
          widthPercent: widthPercent,
          label: label,
          tooltip: tooltip
        });
      }
    }
  }
  
  // 4. Add off-duty block after contracted hours (if any)
  if (contractedEndIndex >= 0 && contractedEndIndex < totalHours - 1) {
    const leftPercent = (contractedEndIndex / totalHours) * 100;
    const widthPercent = (((totalHours - 1) - contractedEndIndex) / totalHours) * 100;
    
    if (widthPercent > 0) {
      blocks.push({
        id: `${porterId}-off-duty-after`,
        type: 'off-duty',
        leftPercent: leftPercent,
        widthPercent: widthPercent,
        label: 'Off Duty',
        tooltip: `Off Duty: ${contractedEndHour}:00 - ${shiftEndHour}:00`
      });
    }
  }
  
  return blocks;
};

// Format minutes to time string
const formatMinutesToTime = (minutes) => {
  // Handle overnight times (minutes > 24 * 60)
  let adjustedMinutes = minutes;
  if (adjustedMinutes >= 24 * 60) {
    adjustedMinutes = adjustedMinutes - (24 * 60);
  }
  
  const hours = Math.floor(adjustedMinutes / 60);
  const mins = adjustedMinutes % 60;
  return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
};

// Format shift duration
const formatShiftDuration = () => {
  if (!props.shift) return '';
  
  const start = new Date(props.shift.start_time);
  const end = new Date(props.shift.end_time);
  const durationMs = end.getTime() - start.getTime();
  const durationHours = Math.round(durationMs / (1000 * 60 * 60));
  
  return `${durationHours} hours`;
};

// Format porter contracted hours
const formatPorterHours = (porterId) => {
  const porter = staffStore.porters.find(p => p.id === porterId);
  if (!porter || !porter.contracted_hours_start || !porter.contracted_hours_end) {
    return 'No hours set';
  }
  
  const start = porter.contracted_hours_start.substring(0, 5); // Remove seconds
  const end = porter.contracted_hours_end.substring(0, 5);
  
  return `${start} - ${end}`;
};

// Load required data on mount
onMounted(async () => {
  console.log('SitRep modal mounting - loading data...');
  
  // Load settings first to ensure shift defaults are available
  await settingsStore.loadSettings();
  
  // CRITICAL: Load porters FIRST before anything else that depends on porter data
  if (!staffStore.porters.length) {
    console.log('Loading porters...');
    await staffStore.fetchPorters();
    console.log(`Loaded ${staffStore.porters.length} porters`);
  }
  
  if (!shiftsStore.shiftPorterPool.length) {
    console.log('Loading shift porter pool...');
    await shiftsStore.fetchShiftPorterPool(props.shift.id);
    console.log(`Loaded ${shiftsStore.shiftPorterPool.length} porters in pool`);
  }
  
  if (!shiftsStore.shiftAreaCoverAssignments.length) {
    console.log('Loading area cover assignments...');
    await shiftsStore.fetchShiftAreaCover(props.shift.id);
    console.log(`Loaded ${shiftsStore.shiftAreaCoverAssignments.length} area cover assignments`);
  }
  
  if (!shiftsStore.shiftSupportServiceAssignments.length) {
    console.log('Loading support service assignments...');
    await shiftsStore.fetchShiftSupportServices(props.shift.id);
    console.log(`Loaded ${shiftsStore.shiftSupportServiceAssignments.length} support service assignments`);
  }
  
  // Fetch historical absences specifically for SitRep
  console.log('Loading historical absences...');
  await fetchHistoricalAbsences();
  
  // Load porter-building assignments for this shift
  console.log('Loading porter-building assignments...');
  await shiftsStore.fetchShiftPorterBuildingAssignments(props.shift.id);
  console.log(`Loaded porter-building assignments for shift ${props.shift.id}`);
  
  // Set CSS custom property for hour width based on timeline length
  updateHourWidth();
  
  console.log('SitRep modal data loading complete');
});

// Update CSS custom property for hour width
const updateHourWidth = () => {
  if (timelineHours.value.length > 0) {
    const hourWidthPercent = (100 / timelineHours.value.length);
    document.documentElement.style.setProperty('--hour-width', `${hourWidthPercent}%`);
  }
};

// Watch for timeline changes and update hour width
import { watch } from 'vue';
watch(timelineHours, () => {
  updateHourWidth();
}, { immediate: true });
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
  border-radius: 6px;
  width: 95%;
  max-width: 1400px;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid #e0e0e0;
    
    h2 {
      margin: 0;
      font-size: 1.25rem;
    }
    
    .modal-actions {
      display: flex;
      gap: 0.5rem;
    }
    
    .close-button {
      background: none;
      border: none;
      font-size: 1.5rem;
      cursor: pointer;
      padding: 0;
      line-height: 1;
    }
  }
  
  .modal-body {
    padding: 1rem;
  }
}

.sitrep-sheet {
  .sheet-header {
    margin-bottom: 1rem;
    
    h2 {
      margin-top: 0;
      margin-bottom: 0.5rem;
    }
    
    .sheet-info {
      font-weight: bold;
      margin: 0;
    }
  }
  
  .shift-summary {
    margin-bottom: 1.5rem;
    padding: 1rem;
    background-color: #f8f9fa;
    border-radius: 6px;
    border: 1px solid #dee2e6;
    
    .summary-stats {
      display: flex;
      gap: 2rem;
      flex-wrap: wrap;
      
      .stat-item {
        display: flex;
        flex-direction: column;
        gap: 0.25rem;
        
        .stat-label {
          font-size: 0.9rem;
          color: #6c757d;
          font-weight: 500;
        }
        
        .stat-value {
          font-size: 1.1rem;
          font-weight: 600;
          color: #495057;
        }
      }
    }
  }
  
    // Time ruler styles
    .time-ruler-container {
      display: grid;
      grid-template-columns: 200px 1fr;
      margin-bottom: 0.5rem;
      border-bottom: 1px solid #dee2e6;
      
      .porter-name-spacer {
        background-color: #f8f9fa;
        border-right: 1px solid #dee2e6;
      }
      
      .time-ruler {
        position: relative;
        height: 40px;
        background-color: #f8f9fa;
        
        .time-marker {
          position: absolute;
          top: 50%;
          transform: translate(-50%, -50%);
          font-size: 0.75rem;
          font-weight: 600;
          color: #495057;
          background-color: rgba(248, 249, 250, 0.9);
          padding: 0.25rem 0.5rem;
          white-space: nowrap;
          border-radius: 3px;
          
          // Style main hour markers differently
          &.main-hour {
            font-weight: 700;
            background-color: rgba(66, 133, 244, 0.1);
            color: #1565c0;
          }
        }
      }
    }
    
    // Grid layout styles
    .sitrep-grid {
      display: grid;
      grid-template-columns: 200px 1fr;
      gap: 0;
      background-color: #dee2e6;
      border: 1px solid #dee2e6;
      overflow: hidden;
      min-width: 800px;
      
      .porter-row {
        display: contents;
      }
      
      .porter-name {
        padding: 1rem;
        background-color: #f8f9fa;
        border-right: 1px solid #dee2e6;
        border-bottom: 1px solid #dee2e6;
        font-weight: 600;
        font-size: 0.9rem;
        color: #495057;
        display: flex;
        flex-direction: column;
        justify-content: center;
        min-height: 70px;
        
        .porter-name-text {
          font-weight: 600;
          margin-bottom: 0.25rem;
        }
        
        .porter-hours {
          font-size: 0.8rem;
          font-weight: 500;
          color: #6c757d;
        }
      }
      
      .porter-timeline {
        position: relative;
        background-color: white;
        border-bottom: 1px solid #dee2e6;
        min-height: 70px;
        
        // Add vertical hour lines to timeline - will be set dynamically via CSS custom property
        background-image: repeating-linear-gradient(
          to right,
          transparent 0%,
          transparent calc(var(--hour-width) - 0.5px),
          #f1f3f4 calc(var(--hour-width) - 0.5px),
          #f1f3f4 calc(var(--hour-width) + 0.5px)
        );
        
        .timeline-block {
          position: absolute;
          top: 8px;
          bottom: 8px;
          display: flex;
          flex-direction: column;
          align-items: flex-start;
          justify-content: center;
          font-size: 0.8rem;
          font-weight: 500;
          overflow: hidden;
          min-width: 20px;
          padding-left: 0.5rem;
          
          &.block-available {
            background-color: #f8f9fa; /* Very light grey */
            color: #6c757d;
            border: 1px solid #dee2e6;
            font-weight: 500;
          }
          
          &.block-allocated {
            background-color: #6c757d; /* Medium grey */
            color: white;
            border: 1px solid #495057;
            font-weight: 600;
          }
          
          &.block-off-duty {
            background-color: #6c757d; /* Same styling as allocated */
            color: white;
            border: 1px solid #495057;
            font-weight: 600;
          }
          
          .block-label {
            font-weight: 600;
            text-align: left;
            line-height: 1.2;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            max-width: 100%;
            padding: 0;
          }
          
          .block-time {
            font-size: 0.7rem;
            font-weight: 500;
            margin-top: 0.25rem;
            opacity: 0.8;
            text-align: left;
            line-height: 1;
            padding: 0;
          }
          
          // Hide time range for very small blocks
          &[style*="width: 0."] .block-time,
          &[style*="width: 1."] .block-time,
          &[style*="width: 2."] .block-time,
          &[style*="width: 3."] .block-time,
          &[style*="width: 4."] .block-time {
            display: none;
          }
          
          // Truncate labels for small blocks
          &[style*="width: 0."] .block-label,
          &[style*="width: 1."] .block-label,
          &[style*="width: 2."] .block-label,
          &[style*="width: 3."] .block-label,
          &[style*="width: 4."] .block-label,
          &[style*="width: 5."] .block-label {
            font-size: 0.7rem;
            max-width: 40px;
          }
        }
      }
    }
    
    .legend {
      display: flex;
      gap: 1.5rem;
      justify-content: center;
      margin-top: 1.5rem;
      padding: 1rem;
      background-color: #f8f9fa;
      border-radius: 6px;
      border: 1px solid #dee2e6;
      
      .legend-item {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        font-size: 0.9rem;
        font-weight: 500;
        color: #495057;
        
        .legend-box {
          width: 18px;
          height: 18px;
          border: 1px solid #dee2e6;
          border-radius: 3px;
          
          &.available {
            background-color: #f8f9fa;
            border-color: #dee2e6;
          }
          
          &.allocated {
            background-color: #6c757d;
            border-color: #495057;
          }
          
          &.off-duty {
            background-color: #6c757d; /* Same styling as allocated */
            border-color: #495057;
          }
          
          &.absent {
            background: linear-gradient(135deg, #ffebee 0%, #ffcdd2 100%);
            border-color: #ef9a9a;
          }
        }
      }
    }
  }

.btn {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s, background-color 0.2s;
  
  &-primary {
    background-color: #4285F4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#4285F4, 10%);
    }
  }
}

/* Print styles - Optimized for A4 Portrait */
@media print {
  /* Hide everything except the SitRep modal */
  body * {
    visibility: hidden;
  }
  
  .modal-overlay,
  .modal-overlay * {
    visibility: visible;
  }
  
  /* Page setup for A4 Portrait */
  @page {
    size: A4 portrait;
    margin: 0.5in;
  }
  
  /* Modal overlay and container */
  .modal-overlay {
    background-color: transparent !important;
    position: static !important;
    width: 100% !important;
    height: auto !important;
    display: block !important;
    align-items: unset !important;
    justify-content: unset !important;
    z-index: auto !important;
  }
  
  .sitrep-modal {
    width: 100% !important;
    max-width: none !important;
    max-height: none !important;
    box-shadow: none !important;
    border-radius: 0 !important;
    background-color: white !important;
    overflow: visible !important;
  }
  
  /* Hide modal header (Print button, close button, etc.) */
  .modal-header {
    display: none !important;
  }
  
  /* Modal body adjustments */
  .modal-body {
    padding: 0 !important;
  }
  
  /* Sheet header styling */
  .sheet-header {
    margin-bottom: 1rem !important;
    
    h2 {
      font-size: 16pt !important;
      margin-top: 0 !important;
      margin-bottom: 0.5rem !important;
      text-align: left !important;
    }
    
    .sheet-info {
      font-size: 12pt !important;
      font-weight: bold !important;
      margin: 0 !important;
      text-align: left !important;
    }
  }
  
  /* Shift summary adjustments */
  .shift-summary {
    margin-bottom: 1rem !important;
    padding: 0.75rem !important;
    background-color: #f8f9fa !important;
    border: 1px solid #dee2e6 !important;
    border-radius: 4px !important;
    
    .summary-stats {
      display: flex !important;
      gap: 1.5rem !important;
      flex-wrap: wrap !important;
      
      .stat-item {
        .stat-label {
          font-size: 9pt !important;
        }
        
        .stat-value {
          font-size: 11pt !important;
        }
      }
    }
  }
  
  /* Time ruler adjustments for portrait */
  .time-ruler-container {
    display: grid !important;
    grid-template-columns: 150px 1fr !important;
    margin-bottom: 0.5rem !important;
    border-bottom: 1px solid #dee2e6 !important;
    
    .porter-name-spacer {
      background-color: #f8f9fa !important;
      border-right: 1px solid #dee2e6 !important;
    }
    
    .time-ruler {
      height: 30px !important;
      background-color: #f8f9fa !important;
      
      .time-marker {
        font-size: 8pt !important;
        font-weight: 600 !important;
        padding: 0.2rem 0.3rem !important;
      }
    }
  }
  
  /* Grid layout adjustments for portrait */
  .sitrep-grid {
    display: grid !important;
    grid-template-columns: 150px 1fr !important;
    gap: 0 !important;
    background-color: #dee2e6 !important;
    border: 1px solid #dee2e6 !important;
    overflow: visible !important;
    min-width: auto !important;
    
    .porter-row {
      display: contents !important;
      page-break-inside: avoid !important;
    }
    
    .porter-name {
      padding: 0.5rem !important;
      background-color: #f8f9fa !important;
      border-right: 1px solid #dee2e6 !important;
      border-bottom: 1px solid #dee2e6 !important;
      font-weight: 600 !important;
      font-size: 9pt !important;
      color: #495057 !important;
      min-height: 50px !important;
      
      .porter-name-text {
        font-weight: 600 !important;
        margin-bottom: 0.2rem !important;
        line-height: 1.2 !important;
      }
      
      .porter-hours {
        font-size: 8pt !important;
        font-weight: 500 !important;
        color: #6c757d !important;
      }
    }
    
    .porter-timeline {
      background-color: white !important;
      border-bottom: 1px solid #dee2e6 !important;
      min-height: 50px !important;
      
      .timeline-block {
        top: 6px !important;
        bottom: 6px !important;
        font-size: 7pt !important;
        font-weight: 500 !important;
        padding-left: 0.3rem !important;
        
        .block-label {
          font-weight: 600 !important;
          line-height: 1.1 !important;
        }
        
        // Adjust label sizes for smaller print format
        &[style*="width: 0."] .block-label,
        &[style*="width: 1."] .block-label,
        &[style*="width: 2."] .block-label,
        &[style*="width: 3."] .block-label,
        &[style*="width: 4."] .block-label,
        &[style*="width: 5."] .block-label,
        &[style*="width: 6."] .block-label,
        &[style*="width: 7."] .block-label {
          font-size: 6pt !important;
          max-width: 30px !important;
        }
      }
    }
  }
  
  /* Legend adjustments */
  .legend {
    display: flex !important;
    gap: 1rem !important;
    justify-content: center !important;
    margin-top: 1rem !important;
    padding: 0.75rem !important;
    background-color: #f8f9fa !important;
    border: 1px solid #dee2e6 !important;
    border-radius: 4px !important;
    page-break-inside: avoid !important;
    
    .legend-item {
      display: flex !important;
      align-items: center !important;
      gap: 0.4rem !important;
      font-size: 9pt !important;
      font-weight: 500 !important;
      color: #495057 !important;
      
      .legend-box {
        width: 12px !important;
        height: 12px !important;
        border: 1px solid #dee2e6 !important;
        border-radius: 2px !important;
      }
    }
  }
  
  /* Ensure proper page breaks */
  .sitrep-sheet {
    page-break-inside: avoid;
  }
  
  .sheet-content {
    page-break-inside: auto;
  }
  
  /* Force black and white printing for better contrast */
  .timeline-block {
    &.block-available {
      background-color: #f8f9fa !important;
      color: #495057 !important;
      border: 1px solid #dee2e6 !important;
    }
    
    &.block-allocated {
      background-color: #495057 !important;
      color: white !important;
      border: 1px solid #343a40 !important;
    }
    
    &.block-off-duty {
      background-color: #6c757d !important;
      color: white !important;
      border: 1px solid #495057 !important;
    }
  }
  
  .legend-box {
    &.available {
      background-color: #f8f9fa !important;
      border-color: #dee2e6 !important;
    }
    
    &.allocated {
      background-color: #495057 !important;
      border-color: #343a40 !important;
    }
    
    &.off-duty {
      background-color: #6c757d !important;
      border-color: #495057 !important;
    }
  }
}
</style>
