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
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useSettingsStore } from '../stores/settingsStore';
import { useLocationsStore } from '../stores/locationsStore';

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

// Generate accurate Gantt chart blocks for a porter including off-duty periods
const getPorterGanttBlocks = (porterId) => {
  const blocks = [];
  const porter = staffStore.porters.find(p => p.id === porterId);
  
  if (!porter || !timelineHours.value.length) {
    return blocks;
  }
  
  // DEBUG: Log porter assignment processing
  console.log(`=== Processing Gantt blocks for porter ${porterId} (${porter.first_name} ${porter.last_name}) ===`);
  
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
  
  // DEBUG: Log assignment data
  console.log(`Found ${departmentAssignments.length} department assignments for porter ${porterId}:`, departmentAssignments);
  console.log(`Found ${serviceAssignments.length} service assignments for porter ${porterId}:`, serviceAssignments);
  console.log('Available area cover assignments:', shiftsStore.shiftAreaCoverAssignments);
  console.log('Available service assignments:', shiftsStore.shiftSupportServiceAssignments);
  
  // Combine all assignments with detailed info
  const allAssignments = [];
  
  // Add department assignments
  departmentAssignments.forEach((assignment, index) => {
    console.log(`Processing department assignment ${index}:`, assignment);
    const areaCover = shiftsStore.shiftAreaCoverAssignments?.find(a => a.id === assignment.shift_area_cover_assignment_id);
    console.log(`Found matching area cover:`, areaCover);
    
    if (areaCover) {
      const assignmentData = {
        id: `dept-${index}`,
        startMinutes: timeToMinutes(assignment.start_time),
        endMinutes: timeToMinutes(assignment.end_time),
        startTime: assignment.start_time,
        endTime: assignment.end_time,
        label: areaCover.department?.name || 'Department',
        type: 'allocated',
        color: areaCover.color || '#999'
      };
      console.log(`Adding department assignment to allAssignments:`, assignmentData);
      allAssignments.push(assignmentData);
    } else {
      console.warn(`No matching area cover found for assignment ID ${assignment.shift_area_cover_assignment_id}`);
    }
  });
  
  // Add service assignments
  serviceAssignments.forEach((assignment, index) => {
    console.log(`Processing service assignment ${index}:`, assignment);
    const service = shiftsStore.shiftSupportServiceAssignments?.find(a => a.id === assignment.shift_support_service_assignment_id);
    console.log(`Found matching service:`, service);
    
    if (service) {
      const assignmentData = {
        id: `service-${index}`,
        startMinutes: timeToMinutes(assignment.start_time),
        endMinutes: timeToMinutes(assignment.end_time),
        startTime: assignment.start_time,
        endTime: assignment.end_time,
        label: service.service?.name || 'Service',
        type: 'allocated',
        color: service.color || '#999'
      };
      console.log(`Adding service assignment to allAssignments:`, assignmentData);
      allAssignments.push(assignmentData);
    } else {
      console.warn(`No matching service found for assignment ID ${assignment.shift_support_service_assignment_id}`);
    }
  });
  
  console.log(`Total assignments for porter ${porterId}:`, allAssignments);
  
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
    
    console.log(`Processing assignment for porter ${porterId}:`, {
      assignment,
      startHour,
      endHour,
      startIndex,
      endIndex,
      totalHours
    });
    
    if (startIndex >= 0 && endIndex >= 0) {
      const leftPercent = (startIndex / totalHours) * 100;
      const widthPercent = ((endIndex - startIndex) / totalHours) * 100;
      
      console.log(`Assignment positioning:`, {
        leftPercent,
        widthPercent,
        label: assignment.label
      });
      
      if (widthPercent > 0) {
        const block = {
          id: `${porterId}-assignment-${assignment.id}`,
          type: 'allocated',
          leftPercent: leftPercent,
          widthPercent: widthPercent,
          label: assignment.label,
          tooltip: `${assignment.label}: ${assignment.startTime.substring(0, 5)} - ${assignment.endTime.substring(0, 5)}`,
          color: assignment.color
        };
        console.log(`Adding assignment block:`, block);
        blocks.push(block);
      } else {
        console.warn(`Assignment has zero width - not adding block:`, assignment);
      }
    } else {
      console.warn(`Invalid hour indices for assignment:`, {
        startHour,
        endHour,
        startIndex,
        endIndex,
        timelineHours: timelineHours.value.map(h => h.hour),
        assignmentTimes: `${assignment.startTime} - ${assignment.endTime}`,
        assignmentLabel: assignment.label
      });
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
    const { supabase } = await import('../services/supabase');
    
    const { data, error } = await supabase
      .from('shift_porter_absences')
      .select(`
        *,
        porter:porter_id(id, first_name, last_name)
      `)
      .eq('shift_id', shiftId.value);
    
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

// Load shift data
const loadShiftData = async () => {
  try {
    const { supabase } = await import('../services/supabase');
    
    const { data, error } = await supabase
      .from('shifts')
      .select(`
        *,
        supervisor:supervisor_id(id, first_name, last_name)
      `)
      .eq('id', shiftId.value)
      .single();
    
    if (error) {
      console.error('Error fetching shift:', error);
      return;
    }
    
    shift.value = data;
    console.log('Loaded shift data:', data);
  } catch (error) {
    console.error('Error in loadShiftData:', error);
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
  console.log('SitRep view mounting - loading data...');
  
  // Load shift data first
  await loadShiftData();
  
  // Load settings first to ensure shift defaults are available
  await settingsStore.loadSettings();
  
  // CRITICAL: Load porters FIRST before anything else that depends on porter data
  if (!staffStore.porters.length) {
    console.log('Loading porters...');
    await staffStore.fetchPorters();
    console.log(`Loaded ${staffStore.porters.length} porters`);
  }
  
  // Load locations for building assignments
  if (!locationsStore.buildings.length) {
    console.log('Loading locations...');
    await locationsStore.fetchBuildings();
    console.log(`Loaded ${locationsStore.buildings.length} buildings`);
  }
  
  if (!shiftsStore.shiftPorterPool.length) {
    console.log('Loading shift porter pool...');
    await shiftsStore.fetchShiftPorterPool(shiftId.value);
    console.log(`Loaded ${shiftsStore.shiftPorterPool.length} porters in pool`);
  }
  
  if (!shiftsStore.shiftAreaCoverAssignments.length) {
    console.log('Loading area cover assignments...');
    await shiftsStore.fetchShiftAreaCover(shiftId.value);
    console.log(`Loaded ${shiftsStore.shiftAreaCoverAssignments.length} area cover assignments`);
    
    // DEBUG: Log the area cover assignments data
    console.log('Area cover assignments:', shiftsStore.shiftAreaCoverAssignments);
    console.log('Area cover porter assignments:', shiftsStore.shiftAreaCoverPorterAssignments);
  }
  
  if (!shiftsStore.shiftSupportServiceAssignments.length) {
    console.log('Loading support service assignments...');
    await shiftsStore.fetchShiftSupportServices(shiftId.value);
    console.log(`Loaded ${shiftsStore.shiftSupportServiceAssignments.length} support service assignments`);
    
    // DEBUG: Log the support service assignments data
    console.log('Support service assignments:', shiftsStore.shiftSupportServiceAssignments);
    console.log('Support service porter assignments:', shiftsStore.shiftSupportServicePorterAssignments);
  }
  
  // Fetch historical absences specifically for SitRep
  console.log('Loading historical absences...');
  await fetchHistoricalAbsences();
  
  // Load porter-building assignments for this shift
  console.log('Loading porter-building assignments...');
  await shiftsStore.fetchShiftPorterBuildingAssignments(shiftId.value);
  console.log(`Loaded porter-building assignments for shift ${shiftId.value}`);
  
  // Set CSS custom property for hour width based on timeline length
  updateHourWidth();
  
  console.log('SitRep view data loading complete');
  
  // DEBUG: Final data state check
  console.log('=== FINAL DATA STATE ===');
  console.log('Shift porter pool:', shiftsStore.shiftPorterPool);
  console.log('Area cover assignments:', shiftsStore.shiftAreaCoverAssignments);
  console.log('Area cover porter assignments:', shiftsStore.shiftAreaCoverPorterAssignments);
  console.log('Support service assignments:', shiftsStore.shiftSupportServiceAssignments);
  console.log('Support service porter assignments:', shiftsStore.shiftSupportServicePorterAssignments);
});

// Watch for timeline changes and update hour width
import { watch } from 'vue';
watch(timelineHours, () => {
  updateHourWidth();
}, { immediate: true });
</script>

<style lang="scss" scoped>
.sitrep-view {
  min-height: 100vh;
  background-color: #f8f9fa;
  
  .sitrep-header {
    background-color: white;
    border-bottom: 1px solid #dee2e6;
    padding: 1rem 2rem;
    position: sticky;
    top: 0;
    z-index: 100;
    
    .header-actions {
      display: flex;
      justify-content: space-between;
      align-items: center;
      max-width: 1400px;
      margin: 0 auto;
    }
  }
  
  .sitrep-content {
    padding: 2rem;
    max-width: 1400px;
    margin: 0 auto;
  }
}

.sitrep-sheet {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  padding: 2rem;
  
  .sheet-header {
    margin-bottom: 2rem;
    text-align: center;
    
    h1 {
      margin-top: 0;
      margin-bottom: 0.5rem;
      font-size: 2rem;
      color: #495057;
    }
    
    .sheet-info {
      font-weight: bold;
      font-size: 1.1rem;
      color: #6c757d;
      margin: 0;
    }
  }
  
  .shift-summary {
    margin-bottom: 2rem;
    padding: 1.5rem;
    background-color: #f8f9fa;
    border-radius: 8px;
    border: 1px solid #dee2e6;
    
    .summary-stats {
      display: flex;
      gap: 3rem;
      justify-content: center;
      flex-wrap: wrap;
      
      .stat-item {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
        text-align: center;
        
        .stat-label {
          font-size: 0.9rem;
          color: #6c757d;
          font-weight: 500;
        }
        
        .stat-value {
          font-size: 1.5rem;
          font-weight: 700;
          color: #495057;
        }
      }
    }
  }
  
  .porter-alert {
    margin-bottom: 2rem;
    padding: 1rem 1.5rem;
    background-color: #fff3cd;
    border: 1px solid #ffeaa7;
    border-radius: 8px;
    border-left: 4px solid #f39c12;
    
    .alert-content {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      
      .alert-icon {
        font-size: 1.25rem;
        flex-shrink: 0;
      }
      
      .alert-text {
        font-size: 1rem;
        color: #856404;
        line-height: 1.4;
        
        strong {
          font-weight: 700;
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
      height: 50px;
      background-color: #f8f9fa;
      
      .time-marker {
        position: absolute;
        top: 50%;
        transform: translate(-50%, -50%);
        font-size: 0.85rem;
        font-weight: 600;
        color: #495057;
        background-color: rgba(248, 249, 250, 0.9);
        padding: 0.25rem 0.5rem;
        white-space: nowrap;
        border-radius: 4px;
        
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
    border-radius: 6px;
    
    .porter-row {
      display: contents;
    }
    
    .porter-name {
      padding: 1.25rem;
      background-color: #f8f9fa;
      border-right: 1px solid #dee2e6;
      border-bottom: 1px solid #dee2e6;
      font-weight: 600;
      font-size: 0.95rem;
      color: #495057;
      display: flex;
      flex-direction: column;
      justify-content: center;
      min-height: 80px;
      
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
      min-height: 80px;
      
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
        top: 10px;
        bottom: 10px;
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        justify-content: center;
        font-size: 0.85rem;
        font-weight: 500;
        overflow: hidden;
        min-width: 20px;
        padding-left: 0.5rem;
        border-radius: 3px;
        
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
        
        // Hide labels for very small blocks
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
    gap: 2rem;
    justify-content: center;
    margin-top: 2rem;
    padding: 1.5rem;
    background-color: #f8f9fa;
    border-radius: 8px;
    border: 1px solid #dee2e6;
    
    .legend-item {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      font-size: 1rem;
      font-weight: 500;
      color: #495057;
      
      .legend-box {
        width: 20px;
        height: 20px;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        
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
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  font-size: 0.9rem;
  
  &-primary {
    background-color: #4285F4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: #3367d6;
      transform: translateY(-1px);
    }
  }
  
  &-secondary {
    background-color: #6c757d;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: #5a6268;
      transform: translateY(-1px);
    }
  }
}

/* Print styles - Clean A4 Portrait */
@media print {
  /* Page setup for A4 Portrait */
  @page {
    size: A4 portrait;
    margin: 0.5in;
  }
  
  /* Hide screen-only elements */
  .sitrep-header {
    display: none !important;
  }
  
  .sitrep-view {
    background-color: white !important;
    min-height: auto !important;
  }
  
  .sitrep-content {
    padding: 0 !important;
    max-width: none !important;
    margin: 0 !important;
  }
  
  .sitrep-sheet {
    box-shadow: none !important;
    border-radius: 0 !important;
    padding: 0 !important;
    
    .sheet-header {
      margin-bottom: 1rem !important;
      
      h1 {
        font-size: 18pt !important;
        margin-bottom: 0.5rem !important;
      }
      
      .sheet-info {
        font-size: 14pt !important;
      }
    }
    
    .shift-summary {
      margin-bottom: 1rem !important;
      padding: 0.75rem !important;
      border-radius: 4px !important;
      
      .summary-stats {
        gap: 2rem !important;
        
        .stat-item {
          .stat-label {
            font-size: 10pt !important;
          }
          
          .stat-value {
            font-size: 12pt !important;
          }
        }
      }
    }
    
    .porter-alert {
      margin-bottom: 1rem !important;
      padding: 0.75rem 1rem !important;
      background-color: #fff3cd !important;
      border: 1px solid #ffeaa7 !important;
      border-radius: 4px !important;
      border-left: 3px solid #f39c12 !important;
      
      .alert-content {
        display: flex !important;
        align-items: center !important;
        gap: 0.5rem !important;
        
        .alert-icon {
          font-size: 11pt !important;
          flex-shrink: 0 !important;
        }
        
        .alert-text {
          font-size: 10pt !important;
          color: #856404 !important;
          line-height: 1.3 !important;
          
          strong {
            font-weight: 700 !important;
          }
        }
      }
    }
    
    .time-ruler-container {
      grid-template-columns: 150px 1fr !important;
      margin-bottom: 0.5rem !important;
      
      .time-ruler {
        height: 30px !important;
        
        .time-marker {
          font-size: 9pt !important;
          padding: 0.2rem 0.3rem !important;
        }
      }
    }
    
    .sitrep-grid {
      grid-template-columns: 150px 1fr !important;
      min-width: auto !important;
      border-radius: 0 !important;
      
      .porter-name {
        padding: 0.5rem !important;
        font-size: 10pt !important;
        min-height: 50px !important;
        
        .porter-name-text {
          margin-bottom: 0.2rem !important;
          line-height: 1.2 !important;
        }
        
        .porter-hours {
          font-size: 9pt !important;
        }
      }
      
      .porter-timeline {
        min-height: 50px !important;
        
        .timeline-block {
          top: 6px !important;
          bottom: 6px !important;
          font-size: 8pt !important;
          padding-left: 0.3rem !important;
          border-radius: 2px !important;
          
          .block-label {
            line-height: 1.1 !important;
          }
          
          &[style*="width: 0."] .block-label,
          &[style*="width: 1."] .block-label,
          &[style*="width: 2."] .block-label,
          &[style*="width: 3."] .block-label,
          &[style*="width: 4."] .block-label,
          &[style*="width: 5."] .block-label,
          &[style*="width: 6."] .block-label,
          &[style*="width: 7."] .block-label {
            font-size: 7pt !important;
            max-width: 30px !important;
          }
        }
      }
    }
    
    .legend {
      margin-top: 1rem !important;
      padding: 0.75rem !important;
      gap: 1.5rem !important;
      border-radius: 4px !important;
      
      .legend-item {
        gap: 0.5rem !important;
        font-size: 10pt !important;
        
        .legend-box {
          width: 14px !important;
          height: 14px !important;
          border-radius: 2px !important;
        }
      }
    }
  }
  
  /* Ensure proper page breaks */
  .porter-row {
    page-break-inside: avoid !important;
  }
  
  /* Force black and white printing for better contrast */
  .timeline-block {
    &.block-available {
      background-color: #f8f9fa !important;
      color: #495057 !important;
      border: 1px solid #dee2e6 !important;
    }
    
    &.block-allocated {
      background-color: #808080 !important;
      color: white !important;
      border: 1px solid #666666 !important;
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
      background-color: #808080 !important;
      border-color: #666666 !important;
    }
    
    &.off-duty {
      background-color: #6c757d !important;
      border-color: #495057 !important;
    }
  }
}
</style>
