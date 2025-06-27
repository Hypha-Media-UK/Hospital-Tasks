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
                <span>Available (Pale Grey)</span>
              </div>
              <div class="legend-item">
                <div class="legend-box allocated"></div>
                <span>Allocated to Department/Service (Darker Grey)</span>
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

// Generate Gantt chart timeline - only shift hours with simple hour format
const timelineHours = computed(() => {
  if (!props.shift) return [];
  
  const hours = [];
  
  // Get actual shift start and end times
  const shiftStart = new Date(props.shift.start_time);
  const shiftEnd = new Date(props.shift.end_time);
  
  // Generate only the shift hours (no buffer)
  let currentTime = new Date(shiftStart);
  currentTime.setMinutes(0, 0, 0); // Round down to hour
  
  while (currentTime < shiftEnd) {
    const hour = currentTime.getHours();
    
    // Format label as simple hour number
    const label = hour.toString();
    
    hours.push({
      hour: hour,
      label: label,
      time: currentTime.toISOString()
    });
    
    // Move to next hour
    currentTime.setHours(currentTime.getHours() + 1);
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

// Get hour position as percentage for time ruler - simplified for Gantt chart
const getHourPosition = (hour) => {
  if (!timelineHours.value.length) return 0;
  
  const hourIndex = timelineHours.value.findIndex(h => h.hour === hour.hour);
  if (hourIndex >= 0) {
    // Position at the start of each hour column
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

// Generate Gantt chart blocks for a porter - simplified logic
const getPorterGanttBlocks = (porterId) => {
  const blocks = [];
  const porter = staffStore.porters.find(p => p.id === porterId);
  
  if (!porter || !timelineHours.value.length) {
    return blocks;
  }
  
  // Get shift start and end hours
  const shiftStartHour = timelineHours.value[0].hour;
  const shiftEndHour = timelineHours.value[timelineHours.value.length - 1].hour;
  const totalHours = timelineHours.value.length;
  
  // Get porter's contracted hours (default to full shift if not set)
  const contractedStartHour = porter.contracted_hours_start ? 
    parseInt(porter.contracted_hours_start.split(':')[0]) : shiftStartHour;
  const contractedEndHour = porter.contracted_hours_end ? 
    parseInt(porter.contracted_hours_end.split(':')[0]) : shiftEndHour;
  
  // Get all assignments for this porter
  const departmentAssignments = shiftsStore.shiftAreaCoverPorterAssignments?.filter(a => a.porter_id === porterId) || [];
  const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments?.filter(a => a.porter_id === porterId) || [];
  
  // Combine all assignments
  const allAssignments = [];
  
  // Add department assignments
  departmentAssignments.forEach(assignment => {
    const areaCover = shiftsStore.shiftAreaCoverAssignments?.find(a => a.id === assignment.shift_area_cover_assignment_id);
    if (areaCover) {
      allAssignments.push({
        startHour: parseInt(assignment.start_time.split(':')[0]),
        endHour: parseInt(assignment.end_time.split(':')[0]),
        label: areaCover.department?.name || 'Department',
        type: 'allocated'
      });
    }
  });
  
  // Add service assignments
  serviceAssignments.forEach(assignment => {
    const service = shiftsStore.shiftSupportServiceAssignments?.find(a => a.id === assignment.shift_support_service_assignment_id);
    if (service) {
      allAssignments.push({
        startHour: parseInt(assignment.start_time.split(':')[0]),
        endHour: parseInt(assignment.end_time.split(':')[0]),
        label: service.service?.name || 'Service',
        type: 'allocated'
      });
    }
  });
  
  // Sort assignments by start time
  allAssignments.sort((a, b) => a.startHour - b.startHour);
  
  // Create blocks for the porter's working hours
  let currentHour = contractedStartHour;
  
  allAssignments.forEach((assignment, index) => {
    // Add availability block before assignment if needed
    if (currentHour < assignment.startHour) {
      const startIndex = timelineHours.value.findIndex(h => h.hour === currentHour);
      const endIndex = timelineHours.value.findIndex(h => h.hour === assignment.startHour);
      
      if (startIndex >= 0 && endIndex >= 0) {
        const leftPercent = (startIndex / totalHours) * 100;
        const widthPercent = ((endIndex - startIndex) / totalHours) * 100;
        
        blocks.push({
          id: `${porterId}-available-${index}`,
          type: 'available',
          leftPercent: leftPercent,
          widthPercent: widthPercent,
          label: 'Available',
          tooltip: `Available: ${currentHour}:00 - ${assignment.startHour}:00`
        });
      }
    }
    
    // Add assignment block
    const startIndex = timelineHours.value.findIndex(h => h.hour === assignment.startHour);
    const endIndex = timelineHours.value.findIndex(h => h.hour === assignment.endHour);
    
    if (startIndex >= 0 && endIndex >= 0) {
      const leftPercent = (startIndex / totalHours) * 100;
      const widthPercent = ((endIndex - startIndex) / totalHours) * 100;
      
      blocks.push({
        id: `${porterId}-assignment-${index}`,
        type: 'allocated',
        leftPercent: leftPercent,
        widthPercent: widthPercent,
        label: assignment.label,
        tooltip: `${assignment.label}: ${assignment.startHour}:00 - ${assignment.endHour}:00`
      });
    }
    
    currentHour = assignment.endHour;
  });
  
  // Add final availability block if needed
  if (currentHour < contractedEndHour) {
    const startIndex = timelineHours.value.findIndex(h => h.hour === currentHour);
    const endIndex = timelineHours.value.findIndex(h => h.hour === contractedEndHour);
    
    if (startIndex >= 0 && endIndex >= 0) {
      const leftPercent = (startIndex / totalHours) * 100;
      const widthPercent = ((endIndex - startIndex) / totalHours) * 100;
      
      blocks.push({
        id: `${porterId}-available-final`,
        type: 'available',
        leftPercent: leftPercent,
        widthPercent: widthPercent,
        label: 'Available',
        tooltip: `Available: ${currentHour}:00 - ${contractedEndHour}:00`
      });
    }
  }
  
  // If no assignments, create one big availability block
  if (allAssignments.length === 0) {
    const startIndex = timelineHours.value.findIndex(h => h.hour === contractedStartHour);
    const endIndex = timelineHours.value.findIndex(h => h.hour === contractedEndHour);
    
    if (startIndex >= 0 && endIndex >= 0) {
      const leftPercent = (startIndex / totalHours) * 100;
      const widthPercent = ((endIndex - startIndex) / totalHours) * 100;
      
      blocks.push({
        id: `${porterId}-available-all`,
        type: 'available',
        leftPercent: leftPercent,
        widthPercent: widthPercent,
        label: 'Available',
        tooltip: `Available: ${contractedStartHour}:00 - ${contractedEndHour}:00`
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
  
  console.log('SitRep modal data loading complete');
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
        
        // Add vertical hour lines to timeline
        background-image: repeating-linear-gradient(
          to right,
          transparent 0%,
          transparent calc(8.33% - 0.5px),
          #f1f3f4 calc(8.33% - 0.5px),
          #f1f3f4 calc(8.33% + 0.5px)
        );
        
        .timeline-block {
          position: absolute;
          top: 8px;
          bottom: 8px;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          font-size: 0.8rem;
          font-weight: 500;
          overflow: hidden;
          min-width: 20px;
          
          &.block-available {
            background-color: #f5f5f5; /* Pale grey */
            color: #666;
            border: 1px solid #ddd;
          }
          
          &.block-allocated {
            background-color: #999; /* Darker grey */
            color: white;
            border: 1px solid #777;
          }
          
          .block-label {
            font-weight: 600;
            text-align: center;
            line-height: 1.2;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            max-width: 100%;
            padding: 0 0.25rem;
          }
          
          .block-time {
            font-size: 0.7rem;
            font-weight: 500;
            margin-top: 0.25rem;
            opacity: 0.8;
            text-align: center;
            line-height: 1;
            padding: 0 0.25rem;
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
          
          &.available {
            background-color: white;
          }
          
          &.allocated {
            background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%);
            border-color: #90caf9;
          }
          
          &.off-duty {
            background: linear-gradient(135deg, #f3e5f5 0%, #e1bee7 100%);
            border-color: #ce93d8;
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
