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
            <div class="timeline-container">
              <table class="sitrep-table">
                <thead>
                  <tr>
                    <th class="porter-column">Porter</th>
                    <th v-for="hour in timelineHours" :key="hour.label" class="hour-column">
                      {{ hour.label }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="porter in sortedPorters" :key="porter.id">
                    <td class="porter-name">{{ porter.porter.first_name }} {{ porter.porter.last_name }}</td>
                    <template v-for="(hour, hourIndex) in timelineHours" :key="`${porter.id}-${hourIndex}`">
                      <td v-if="shouldRenderCell(porter.porter_id, hourIndex)" 
                          :class="getCellClass(porter.porter_id, hour)"
                          :colspan="getCellSpan(porter.porter_id, hourIndex)"
                          class="timeline-cell">
                        {{ getCellContent(porter.porter_id, hour) }}
                        <span v-if="getCellSpan(porter.porter_id, hourIndex) > 1" class="time-range">
                          {{ getSpanTimeRange(porter.porter_id, hourIndex) }}
                        </span>
                      </td>
                    </template>
                  </tr>
                </tbody>
              </table>
            </div>
            
            <div class="legend">
              <div class="legend-item">
                <div class="legend-box available"></div>
                <span>Available</span>
              </div>
              <div class="legend-item">
                <div class="legend-box allocated"></div>
                <span>Allocated</span>
              </div>
              <div class="legend-item">
                <div class="legend-box off-duty"></div>
                <span>Off Duty</span>
              </div>
              <div class="legend-item">
                <div class="legend-box absent"></div>
                <span>Absent</span>
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

// Generate timeline hours based on standard shift times from settings
const timelineHours = computed(() => {
  if (!props.shift || !props.shift.start_time) return [];
  
  const hours = [];
  const shiftType = props.shift.shift_type;
  
  // Get standard shift times from settings
  const shiftDefaults = settingsStore.shiftDefaults[shiftType];
  if (!shiftDefaults || !shiftDefaults.startTime || !shiftDefaults.endTime) {
    console.warn(`No shift defaults found for shift type: ${shiftType}`);
    return [];
  }
  
  // Get the shift date (not time) from the shift record
  const shiftDate = new Date(props.shift.start_time);
  const year = shiftDate.getFullYear();
  const month = shiftDate.getMonth();
  const day = shiftDate.getDate();
  
  // Parse standard start and end times
  const [startHours, startMinutes] = shiftDefaults.startTime.split(':').map(Number);
  const [endHours, endMinutes] = shiftDefaults.endTime.split(':').map(Number);
  
  // Create standard shift start time using the shift date but standard time
  const standardShiftStart = new Date(year, month, day, startHours, startMinutes, 0);
  
  // Calculate shift duration in hours
  let shiftDurationHours;
  if (endHours < startHours) {
    // Overnight shift (e.g., 20:00 to 08:00)
    shiftDurationHours = (24 - startHours) + endHours;
  } else {
    // Same day shift (e.g., 08:00 to 20:00)
    shiftDurationHours = endHours - startHours;
  }
  
  // Generate hourly segments based on standard times
  for (let i = 0; i < shiftDurationHours; i++) {
    const hourStart = new Date(standardShiftStart);
    hourStart.setHours(standardShiftStart.getHours() + i);
    
    const hourEnd = new Date(hourStart);
    hourEnd.setHours(hourStart.getHours() + 1);
    
    hours.push({
      label: formatHour(hourStart),
      startTime: formatTimeForComparison(hourStart),
      endTime: formatTimeForComparison(hourEnd),
      startMinutes: hourStart.getHours() * 60 + hourStart.getMinutes(),
      endMinutes: hourEnd.getHours() * 60 + hourEnd.getMinutes()
    });
  }
  
  return hours;
});

// Get porter pool data
const porterPool = computed(() => {
  return shiftsStore.shiftPorterPool || [];
});

// Sort porters by availability (available first, then cascading by unavailability)
const sortedPorters = computed(() => {
  if (!porterPool.value.length) return [];
  
  const porters = [...porterPool.value];
  
  return porters.sort((a, b) => {
    const aAvailability = calculatePorterAvailability(a.porter_id);
    const bAvailability = calculatePorterAvailability(b.porter_id);
    
    // Sort by availability percentage (descending), then by name
    if (aAvailability !== bAvailability) {
      return bAvailability - aAvailability;
    }
    
    // If same availability, sort alphabetically
    const aName = `${a.porter.first_name} ${a.porter.last_name}`;
    const bName = `${b.porter.first_name} ${b.porter.last_name}`;
    return aName.localeCompare(bName);
  });
});

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
  
  // Check for scheduled absences and return the reason
  const absences = shiftsStore.shiftPorterAbsences.filter(a => a.porter_id === porterId);
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
  
  // Check if hour overlaps with contracted hours
  return isTimeRangeOverlapping(hour.startMinutes, hour.endMinutes, startMinutes, endMinutes);
};

// Check if porter is absent during a specific hour
const isPorterAbsentDuringHour = (porterId, hour) => {
  const absences = shiftsStore.shiftPorterAbsences.filter(a => a.porter_id === porterId);
  
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
  return (hours * 60) + minutes;
};

const isTimeRangeOverlapping = (start1, end1, start2, end2) => {
  // Handle overnight ranges
  if (end2 < start2) {
    // Overnight range: check if it overlaps with either part
    return (start1 < end2) || (end1 > start2) || (start1 >= start2);
  }
  
  if (end1 < start1) {
    // First range is overnight
    return (start2 < end1) || (end2 > start1) || (start2 >= start1);
  }
  
  // Normal case: ranges overlap if one starts before the other ends
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

// Load required data on mount
onMounted(async () => {
  // Load settings first to ensure shift defaults are available
  await settingsStore.loadSettings();
  
  if (!shiftsStore.shiftPorterPool.length) {
    await shiftsStore.fetchShiftPorterPool(props.shift.id);
  }
  
  if (!shiftsStore.shiftAreaCoverAssignments.length) {
    await shiftsStore.fetchShiftAreaCover(props.shift.id);
  }
  
  if (!shiftsStore.shiftSupportServiceAssignments.length) {
    await shiftsStore.fetchShiftSupportServices(props.shift.id);
  }
  
  if (!staffStore.porters.length) {
    await staffStore.fetchPorters();
  }
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
  
  .sheet-content {
    .timeline-container {
      overflow-x: auto;
      margin-bottom: 1rem;
    }
    
    .sitrep-table {
      width: 100%;
      border-collapse: collapse;
      min-width: 800px;
      
      th, td {
        border: 1px solid #000;
        padding: 0.5rem;
        text-align: center;
        vertical-align: middle;
      }
      
      th {
        background-color: #f8f9fa;
        font-weight: bold;
        font-size: 0.9rem;
      }
      
      .porter-column {
        width: 150px;
        text-align: left;
        position: sticky;
        left: 0;
        background-color: #f8f9fa;
        z-index: 1;
      }
      
      .hour-column {
        width: 80px;
        min-width: 80px;
      }
      
      .porter-name {
        font-weight: 500;
        text-align: left;
        position: sticky;
        left: 0;
        background-color: white;
        z-index: 1;
      }
      
      .timeline-cell {
        font-size: 0.8rem;
        font-weight: 500;
        position: relative;
        
        &.cell-available {
          background-color: white;
        }
        
        &.cell-allocated {
          background-color: #e0e0e0;
          
          // Enhanced styling for merged cells
          &[colspan] {
            background: linear-gradient(135deg, #e0e0e0 0%, #d0d0d0 100%);
            border-left: 3px solid #4285F4;
            border-right: 3px solid #4285F4;
          }
        }
        
        &.cell-off-duty {
          background-color: #9e9e9e;
          
          // Enhanced styling for merged off-duty cells
          &[colspan] {
            background: linear-gradient(135deg, #9e9e9e 0%, #8e8e8e 100%);
            border-left: 3px solid #ff9800;
            border-right: 3px solid #ff9800;
          }
        }
        
        &.cell-absent {
          background-color: #9e9e9e;
          
          // Enhanced styling for merged absence cells
          &[colspan] {
            background: linear-gradient(135deg, #9e9e9e 0%, #8e8e8e 100%);
            border-left: 3px solid #f44336;
            border-right: 3px solid #f44336;
          }
        }
        
        &.cell-unavailable {
          background-color: #9e9e9e;
        }
        
        .time-range {
          display: block;
          font-size: 0.7rem;
          color: #666;
          margin-top: 0.25rem;
          font-style: italic;
        }
      }
    }
    
    .legend {
      display: flex;
      gap: 1rem;
      justify-content: center;
      margin-top: 1rem;
      
      .legend-item {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        
        .legend-box {
          width: 20px;
          height: 20px;
          border: 1px solid #000;
          
          &.available {
            background-color: white;
          }
          
          &.allocated {
            background-color: #e0e0e0;
          }
          
          &.off-duty {
            background-color: #9e9e9e;
          }
          
          &.absent {
            background-color: #9e9e9e;
          }
          
          &.unavailable {
            background-color: #9e9e9e;
          }
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

/* Print styles */
@media print {
  .modal-overlay {
    background-color: transparent;
    position: absolute;
  }
  
  .sitrep-modal {
    width: 100%;
    max-width: none;
    max-height: none;
    box-shadow: none;
    border-radius: 0;
  }
  
  .modal-header {
    display: none !important;
  }
  
  .modal-body {
    padding: 0 !important;
  }
  
  .sheet-header h2 {
    text-align: left;
    font-size: 14pt;
  }
  
  .sheet-info {
    text-align: left;
    font-size: 12pt;
  }
  
  .sitrep-table {
    font-size: 9pt;
    
    th, td {
      padding: 0.25rem !important;
    }
    
    .porter-column {
      width: 120px;
    }
    
    .hour-column {
      width: 60px;
      min-width: 60px;
    }
  }
  
  .legend {
    font-size: 10pt;
    
    .legend-box {
      width: 15px;
      height: 15px;
    }
  }
  
  /* Ensure page breaks don't happen inside table rows */
  tr {
    page-break-inside: avoid;
  }
  
  /* Force landscape orientation */
  @page {
    size: A4 landscape;
    margin: 0.5in;
  }
}
</style>
