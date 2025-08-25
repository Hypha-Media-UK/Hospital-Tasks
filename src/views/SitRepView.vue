<template>
  <div class="sitrep-view">
    <div class="sitrep-header">
      <div class="header-actions">
        <button @click="goBack" class="btn btn-secondary">
          ← Back to Shift Management
        </button>
        <button @click="printSheet" class="btn btn-primary">
          Print SitRep
        </button>
      </div>
    </div>
    
    <div class="sitrep-content">
      <div class="sitrep-sheet">
        <div class="sheet-header">
          <h1>Situation Report</h1>
          <p class="sheet-info">
            {{ getShiftTypeDisplayName() }} | {{ formatShortDate(shift?.start_time) }}
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
                <span class="stat-label">Supervisor:</span>
                <span class="stat-value">{{ shift?.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}</span>
              </div>
            </div>
          </div>
          
          <!-- Low Porter Availability Alert -->
          <div v-if="showLowPorterAlert" class="porter-alert">
            <div class="alert-content">
              <span class="alert-icon">⚠️</span>
              <span class="alert-text">
                <strong>Low Porter Availability:</strong> Only {{ availablePortersCount }} porter{{ availablePortersCount === 1 ? '' : 's' }} currently available
              </span>
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
              <div class="legend-box absent"></div>
              <span>Absent</span>
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
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useSettingsStore } from '../stores/settingsStore';
import { useLocationsStore } from '../stores/locationsStore';
import { absencesApi } from '../services/api';

const route = useRoute();
const router = useRouter();

const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const settingsStore = useSettingsStore();
const locationsStore = useLocationsStore();

// Get shift ID from route params
const shiftId = computed(() => route.params.shiftId);

// Current shift data
const shift = ref(null);

// Generate Gantt chart timeline - only shift hours with simple hour format
const timelineHours = computed(() => {
  if (!shift.value) return [];
  
  const hours = [];
  
  // Get shift defaults from settings to determine proper shift duration
  const shiftDefaults = settingsStore.shiftDefaults[shift.value.shift_type];
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
    
    // Move to next hour
    currentHour = (currentHour + 1) % 24;
    hourCount++;
    
    // Check if we've reached the end AFTER adding the current hour
    // This ensures we include the end hour in the timeline
    if (currentHour === endHour || (currentHour === (endHour + 1) % 24)) {
      // For assignments that end at a specific hour, we need to include that hour
      // Add the end hour if it's not already added
      if (hours[hours.length - 1].hour !== endHour) {
        hours.push({
          hour: endHour,
          label: endHour.toString(),
          isShiftTime: true
        });
      }
      break;
    }
    
    // For overnight shifts, handle the wrap-around
    if (isOvernightShift && hourCount > 1 && currentHour === endHour) {
      // Add the end hour for overnight shifts
      hours.push({
        hour: endHour,
        label: endHour.toString(),
        isShiftTime: true
      });
      break;
    }
  }
  
  return hours;
});

// Get porter pool data
const porterPool = computed(() => {
  return shiftsStore.shiftPorterPool || [];
});

// Calculate currently available porters (not allocated, on duty, not absent)
const availablePortersCount = computed(() => {
  if (!porterPool.value.length) return 0;
  
  const now = new Date();
  const currentTimeStr = now.toTimeString().substring(0, 8); // HH:MM:SS format
  const currentHours = now.getHours();
  const currentMinutes = now.getMinutes();
  const currentTimeInMinutes = (currentHours * 60) + currentMinutes;
  
  // Helper function to convert time string (HH:MM:SS) to minutes
  const timeToMinutes = (timeStr) => {
    if (!timeStr) return 0;
    const [hours, minutes] = timeStr.split(':').map(Number);
    return (hours * 60) + minutes;
  };
  
  // Helper function to check if current time is within a time range, handling overnight ranges
  const isTimeInRange = (currentTimeMinutes, startTimeMinutes, endTimeMinutes) => {
    // Handle overnight ranges (where end time is less than start time)
    if (endTimeMinutes < startTimeMinutes) {
      // Current time is either after start time or before end time
      return currentTimeMinutes >= startTimeMinutes || currentTimeInMinutes <= endTimeMinutes;
    } else {
      // Normal case: current time is between start and end times
      return currentTimeInMinutes >= startTimeMinutes && currentTimeInMinutes <= endTimeMinutes;
    }
  };
  
  // Helper function to check if a time period is active now
  const isTimePeriodActive = (startTimeStr, endTimeStr) => {
    if (!startTimeStr || !endTimeStr) return false;
    
    const startTimeMinutes = timeToMinutes(startTimeStr);
    const endTimeMinutes = timeToMinutes(endTimeStr);
    
    return isTimeInRange(currentTimeInMinutes, startTimeMinutes, endTimeMinutes);
  };
  
  // Helper function to check if porter is on duty based on contracted hours
  const isPorterOnDuty = (porterId) => {
    const porter = staffStore.porters.find(p => p.id === porterId);
    if (!porter || !porter.contracted_hours_start || !porter.contracted_hours_end) {
      return true; // Assume on duty if no contracted hours set
    }
    
    const startMinutes = timeToMinutes(porter.contracted_hours_start);
    const endMinutes = timeToMinutes(porter.contracted_hours_end);
    
    // Check if current time is within contracted hours, handling overnight shifts properly
    if (endMinutes < startMinutes) {
      // Overnight shift (e.g., 22:00 to 06:00)
      return currentTimeInMinutes >= startMinutes || currentTimeInMinutes <= endMinutes;
    } else {
      // Normal shift (e.g., 10:00 to 22:00)
      return currentTimeInMinutes >= startMinutes && currentTimeInMinutes <= endMinutes;
    }
  };
  
  // Filter porters to find those currently available
  const availablePorters = porterPool.value.filter(porter => {
    // Exclude supervisors
    if (shift.value?.supervisor_id && porter.porter_id === shift.value.supervisor_id) {
      return false;
    }
    if (porter.is_supervisor) {
      return false;
    }
    
    // Check if porter has a global absence (illness, annual leave)
    const isAbsent = staffStore.isPorterAbsent(porter.porter_id, now);
    if (isAbsent) return false;
    
    // Check if porter is not on duty yet based on contracted hours
    if (!isPorterOnDuty(porter.porter_id)) return false;
    
    // Check if porter has an active scheduled absence in the shift
    const hasActiveAbsence = shiftsStore.shiftPorterAbsences && 
      shiftsStore.shiftPorterAbsences.some(absence => {
        if (absence.porter_id !== porter.porter_id) return false;
        
        // Check if current time is within absence period
        return isTimePeriodActive(absence.start_time, absence.end_time);
      });
    if (hasActiveAbsence) return false;
    
    // Check if porter has active area cover assignments
    const hasActiveAreaCoverAssignment = shiftsStore.shiftAreaCoverPorterAssignments.some(
      assignment => {
        if (assignment.porter_id !== porter.porter_id) return false;
        
        // Check if current time is within assignment period
        return isTimePeriodActive(assignment.start_time, assignment.end_time);
      }
    );
    if (hasActiveAreaCoverAssignment) return false;
    
    // Check if porter has active service assignments
    const hasActiveServiceAssignment = shiftsStore.shiftSupportServicePorterAssignments.some(
      assignment => {
        if (assignment.porter_id !== porter.porter_id) return false;
        
        // Check if current time is within assignment period
        return isTimePeriodActive(assignment.start_time, assignment.end_time);
      }
    );
    if (hasActiveServiceAssignment) return false;
    
    // If we've reached here, porter is available
    return true;
  });
  
  return availablePorters.length;
});

// Show low porter alert when available count is below threshold
const showLowPorterAlert = computed(() => {
  return availablePortersCount.value < 3;
});

// Sort porters by building allocation, then by availability
// Exclude the shift supervisor from the porter list
const sortedPorters = computed(() => {
  if (!porterPool.value.length) return [];
  
  // Filter out the shift supervisor - they shouldn't appear in the porter timeline
  const porters = [...porterPool.value].filter(porter => {
    // Exclude if this porter is the shift supervisor
    if (shift.value?.supervisor_id && porter.porter_id === shift.value.supervisor_id) {
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

// Helper functions
const timeToMinutes = (timeStr) => {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  let totalMinutes = (hours * 60) + minutes;
  
  // For night shifts, adjust times after midnight to ensure consistent calculation
  // This ensures that times like 02:00 (2 AM) are treated as being after 20:00 (8 PM) from the previous day
  if (shift.value && shift.value.shift_type.includes('night') && hours < 12) {
    totalMinutes += 24 * 60; // Add 24 hours worth of minutes
  }
  
  return totalMinutes;
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
  if (!shift.value) return 'Shift';
  
  // Simplify shift type display to just "Day Shift" or "Night Shift"
  if (shift.value.shift_type.includes('day')) {
    return 'Day Shift';
  } else if (shift.value.shift_type.includes('night')) {
    return 'Night Shift';
  } else {
    return 'Shift';
  }
};

// Go back to shift management
const goBack = () => {
  router.push('/shift-management');
};

// Print the sheet
const printSheet = () => {
  window.print();
};

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

// Generate accurate Gantt chart blocks for a porter using chronological timeline approach
const getPorterGanttBlocks = (porterId) => {
  const blocks = [];
  const porter = staffStore.porters.find(p => p.id === porterId);
  
  if (!porter || !timelineHours.value.length) {
    return blocks;
  }

  const totalHours = timelineHours.value.length;
  const shiftStartHour = timelineHours.value[0].hour;
  const shiftEndHour = timelineHours.value[timelineHours.value.length - 1].hour;
  
  // Get porter's contracted hours
  const contractedStartHour = porter.contracted_hours_start ? 
    parseInt(porter.contracted_hours_start.split(':')[0]) : shiftStartHour;
  const contractedEndHour = porter.contracted_hours_end ? 
    parseInt(porter.contracted_hours_end.split(':')[0]) : shiftEndHour;
  
  // Helper function to convert time string to minutes for precise calculations
  const timeStringToMinutes = (timeStr) => {
    const [hours, minutes] = timeStr.split(':').map(Number);
    return hours * 60 + minutes;
  };
  
  // Helper function to find hour index in timeline
  const findHourIndex = (hour) => {
    return timelineHours.value.findIndex(h => h.hour === hour);
  };
  
  // Create a timeline array representing each hour slot and what should be displayed
  const timelineSlots = [];
  for (let i = 0; i < totalHours; i++) {
    const hour = timelineHours.value[i].hour;
    timelineSlots.push({
      hour: hour,
      index: i,
      status: 'available', // default status
      label: 'Available',
      tooltip: '',
      priority: 10 // higher number = lower priority (available is lowest priority)
    });
  }
  
  // 1. First, mark off-duty periods (lower priority than assignments but higher than available)
  timelineSlots.forEach(slot => {
    if (slot.hour < contractedStartHour || slot.hour >= contractedEndHour) {
      slot.status = 'off-duty';
      slot.label = 'Off Duty';
      slot.tooltip = `Off Duty: ${slot.hour}:00`;
      slot.priority = 8;
    }
  });
  
  // 2. Get and process all assignments
  const departmentAssignments = shiftsStore.shiftAreaCoverPorterAssignments?.filter(a => a.porter_id === porterId) || [];
  const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments?.filter(a => a.porter_id === porterId) || [];
  
  
  // Process department assignments
  departmentAssignments.forEach((assignment, index) => {
    const areaCover = shiftsStore.shiftAreaCoverAssignments?.find(a => a.id === assignment.shift_area_cover_assignment_id);
    if (areaCover) {
      const startHour = parseInt(assignment.start_time.split(':')[0]);
      const endHour = parseInt(assignment.end_time.split(':')[0]);
      
      
      // Mark all hours in this assignment range
      timelineSlots.forEach(slot => {
        if (slot.hour >= startHour && slot.hour < endHour && slot.priority > 5) {
          slot.status = 'allocated';
          slot.label = areaCover.department?.name || 'Department';
          slot.tooltip = `${slot.label}: ${assignment.start_time.substring(0, 5)} - ${assignment.end_time.substring(0, 5)}`;
          slot.priority = 5;
          slot.assignmentType = 'department';
        }
      });
    } else {
    }
  });
  
  // Process service assignments
  serviceAssignments.forEach((assignment, index) => {
    const service = shiftsStore.shiftSupportServiceAssignments?.find(a => a.id === assignment.shift_support_service_assignment_id);
    if (service) {
      const startHour = parseInt(assignment.start_time.split(':')[0]);
      const endHour = parseInt(assignment.end_time.split(':')[0]);
      
      
      // Mark all hours in this assignment range
      timelineSlots.forEach(slot => {
        if (slot.hour >= startHour && slot.hour < endHour && slot.priority > 5) {
          slot.status = 'allocated';
          slot.label = service.service?.name || 'Service';
          slot.tooltip = `${slot.label}: ${assignment.start_time.substring(0, 5)} - ${assignment.end_time.substring(0, 5)}`;
          slot.priority = 5;
          slot.assignmentType = 'service';
        }
      });
    } else {
    }
  });
  
  // 3. Process absences (highest priority - they override everything)
  const porterAbsences = [
    ...(shiftsStore.shiftPorterAbsences?.filter(a => a.porter_id === porterId) || []),
    ...(historicalAbsences.value?.filter(a => a.porter_id === porterId) || [])
  ];
  
  
  porterAbsences.forEach((absence, index) => {
    const startHour = parseInt(absence.start_time.split(':')[0]);
    const endHour = parseInt(absence.end_time.split(':')[0]);
    
    
    // Mark all hours in this absence range (highest priority)
    timelineSlots.forEach(slot => {
      if (slot.hour >= startHour && slot.hour < endHour) {
        slot.status = 'absent';
        slot.label = 'Absent';
        slot.tooltip = `Absent: ${absence.start_time.substring(0, 5)} - ${absence.end_time.substring(0, 5)}${absence.absence_reason ? ` (${absence.absence_reason})` : ''}`;
        slot.priority = 1; // Highest priority
      }
    });
  });
  
  // 4. Set building assignments for available slots
  const buildingAssignments = shiftsStore.getPorterBuildingAssignments(porterId);
  const assignedBuildings = buildingAssignments.map(buildingId => 
    locationsStore.buildings.find(b => b.id === buildingId)
  ).filter(Boolean);
  
  if (assignedBuildings.length > 0) {
    timelineSlots.forEach(slot => {
      if (slot.status === 'available') {
        slot.label = assignedBuildings[0].name;
        slot.tooltip = `${assignedBuildings[0].name}: ${slot.hour}:00`;
      }
    });
  }
  
  // 5. Convert timeline slots to blocks
  let currentBlock = null;
  
  timelineSlots.forEach((slot, index) => {
    if (!currentBlock || currentBlock.status !== slot.status || currentBlock.label !== slot.label) {
      // Start a new block
      if (currentBlock) {
        // Finish the previous block
        const leftPercent = (currentBlock.startIndex / totalHours) * 100;
        const widthPercent = ((currentBlock.endIndex - currentBlock.startIndex + 1) / totalHours) * 100;
        
        if (widthPercent > 0) {
          blocks.push({
            id: `${porterId}-${currentBlock.status}-${currentBlock.startIndex}`,
            type: currentBlock.status,
            leftPercent: leftPercent,
            widthPercent: widthPercent,
            label: currentBlock.label,
            tooltip: currentBlock.tooltip
          });
        }
      }
      
      // Start new block
      currentBlock = {
        status: slot.status,
        label: slot.label,
        tooltip: slot.tooltip,
        startIndex: index,
        endIndex: index
      };
    } else {
      // Continue current block
      currentBlock.endIndex = index;
    }
  });
  
  // Don't forget the last block
  if (currentBlock) {
    const leftPercent = (currentBlock.startIndex / totalHours) * 100;
    const widthPercent = ((currentBlock.endIndex - currentBlock.startIndex + 1) / totalHours) * 100;
    
    if (widthPercent > 0) {
      blocks.push({
        id: `${porterId}-${currentBlock.status}-${currentBlock.startIndex}`,
        type: currentBlock.status,
        leftPercent: leftPercent,
        widthPercent: widthPercent,
        label: currentBlock.label,
        tooltip: currentBlock.tooltip
      });
    }
  }
  
  
  return blocks;
};

// Format shift duration
const formatShiftDuration = () => {
  if (!shift.value) return '';
  
  const start = new Date(shift.value.start_time);
  const end = new Date(shift.value.end_time);
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

// Historical absence data for SitRep (not cleaned up)
const historicalAbsences = ref([]);

// Fetch all historical absences for this shift (including expired ones)
const fetchHistoricalAbsences = async () => {
  try {
    if (!shift.value) return;
    
    // Get the shift date to filter absences
    const shiftDate = new Date(shift.value.start_time);
    const startDate = shiftDate.toISOString().split('T')[0]; // YYYY-MM-DD format
    const endDate = startDate; // Same day
    
    const response = await absencesApi.getAll({
      start_date: startDate,
      end_date: endDate
    });
    
    historicalAbsences.value = response.data || response || [];
  } catch (error) {
    console.error('Error fetching historical absences:', error);
    historicalAbsences.value = [];
  }
};

// Load shift data
const loadShiftData = async () => {
  try {
    // Use the shifts store to fetch shift data
    const shiftData = await shiftsStore.fetchShiftById(shiftId.value);
    if (shiftData) {
      shift.value = shiftData;
    }
  } catch (error) {
  }
};

// Update CSS custom property for hour width
const updateHourWidth = () => {
  if (timelineHours.value.length > 0) {
    const hourWidthPercent = (100 / timelineHours.value.length);
    document.documentElement.style.setProperty('--hour-width', `${hourWidthPercent}%`);
  }
};

// Load required data on mount
onMounted(async () => {
  
  // Load shift data first
  await loadShiftData();
  
  // Load settings first to ensure shift defaults are available
  await settingsStore.loadSettings();
  
  // CRITICAL: Load porters FIRST before anything else that depends on porter data
  if (!staffStore.porters.length) {
    await staffStore.fetchPorters();
  }
  
  // Load locations for building assignments
  if (!locationsStore.buildings.length) {
    await locationsStore.fetchBuildings();
  }
  
  if (!shiftsStore.shiftPorterPool.length) {
    await shiftsStore.fetchShiftPorterPool(shiftId.value);
  }
  
  if (!shiftsStore.shiftAreaCoverAssignments.length) {
    await shiftsStore.fetchShiftAreaCover(shiftId.value);
  }

  if (!shiftsStore.shiftSupportServiceAssignments.length) {
    await shiftsStore.fetchShiftSupportServices(shiftId.value);
  }
  
  // Fetch historical absences specifically for SitRep
  await fetchHistoricalAbsences();
  
  // Load porter-building assignments for this shift
  await shiftsStore.fetchShiftPorterBuildingAssignments(shiftId.value);
  
  // Set CSS custom property for hour width based on timeline length
  updateHourWidth();
});

// Watch for timeline changes and update hour width
import { watch } from 'vue';
watch(timelineHours, () => {
  updateHourWidth();
}, { immediate: true });
</script>

<!-- Styles are now handled by the global CSS layers -->