<template>
  <div class="view">
    <div class="view__content">
      <!-- Active Shifts Section -->
      <div class="card mb-4">
        <div class="card__header">
          <h2 class="card__title">Active Shifts</h2>
          <button 
            @click="exportSelectedShifts" 
            class="btn btn-export"
            :disabled="selectedShifts.length === 0"
          >
            Export Selected Shifts
          </button>
        </div>
        
        <div v-if="loading" class="loading-indicator">
          <p>Loading shifts...</p>
        </div>
        
        <div v-else-if="activeShifts.length === 0" class="empty-state">
          <p>No active shifts. Create a new shift to get started.</p>
        </div>
        
        <div v-else>
          <div class="selection-controls" v-if="activeShifts.length > 0">
            <label class="select-all-container">
              <input 
                type="checkbox" 
                :checked="isAllSelected" 
                @change="toggleSelectAll" 
              />
              Select All
            </label>
          </div>
          
          <div class="shifts-grid">
          <!-- Day Shifts -->
          <div v-if="dayShifts.length > 0" class="shift-group">
            <h3>Day Shifts</h3>
            <div class="shift-cards">
              <div 
                v-for="shift in dayShifts" 
                :key="shift.id" 
                class="shift-card"
                :style="{ borderColor: getShiftColor(shift.shift_type) }"
                @click="viewShift(shift.id)"
              >
                <div class="shift-card__header">
                  <div class="shift-card__selection">
                    <input 
                      type="checkbox" 
                      :checked="isShiftSelected(shift)"
                      @change="toggleShiftSelection(shift, $event)" 
                      @click.stop
                    />
                    <span class="shift-type">Day Shift</span>
                  </div>
                  <span class="shift-date">{{ formatDate(shift.start_time) }}</span>
                </div>
                <div class="shift-card__body">
                  <p class="supervisor">
                    <strong>Supervisor:</strong> 
                    {{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}
                  </p>
                  <p class="time">
                    <strong>Started:</strong> {{ formatTime(shift.start_time) }}
                  </p>
                  <p class="duration">
                    <strong>Duration:</strong> {{ calculateDuration(shift.start_time) }}
                  </p>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Night Shifts -->
          <div v-if="nightShifts.length > 0" class="shift-group">
            <h3>Night Shifts</h3>
            <div class="shift-cards">
              <div 
                v-for="shift in nightShifts" 
                :key="shift.id" 
                class="shift-card"
                :style="{ borderColor: getShiftColor(shift.shift_type) }"
                @click="viewShift(shift.id)"
              >
                <div class="shift-card__header">
                  <div class="shift-card__selection">
                    <input 
                      type="checkbox" 
                      :checked="isShiftSelected(shift)"
                      @change="toggleShiftSelection(shift, $event)" 
                      @click.stop
                    />
                    <span class="shift-type">Night Shift</span>
                  </div>
                  <span class="shift-date">{{ formatDate(shift.start_time) }}</span>
                </div>
                <div class="shift-card__body">
                  <p class="supervisor">
                    <strong>Supervisor:</strong> 
                    {{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}
                  </p>
                  <p class="time">
                    <strong>Started:</strong> {{ formatTime(shift.start_time) }}
                  </p>
                  <p class="duration">
                    <strong>Duration:</strong> {{ calculateDuration(shift.start_time) }}
                  </p>
                </div>
              </div>
            </div>
          </div>
          </div>
        </div>
      </div>
      
      <!-- Create New Shift Section -->
      <div class="card">
        <h2 class="card__title">Create New Shift</h2>
        
        <div class="create-shift-form">
          <!-- Create New Shift (Single Step) -->
          <div class="shift-type-selection">
            <div class="form-group date-picker-container">
              <label for="shiftDate">Shift Date</label>
              <input 
                type="date" 
                id="shiftDate" 
                v-model="selectedDate" 
                class="form-control"
                :disabled="creating"
                :min="today"
              >
            </div>
            
            <div class="form-group supervisor-picker-container">
              <label for="supervisor">Supervisor</label>
              <select 
                id="supervisor" 
                v-model="selectedSupervisor" 
                class="form-control"
                :disabled="creating"
              >
                <option value="">Select a supervisor</option>
                <option 
                  v-for="supervisor in supervisors" 
                  :key="supervisor.id" 
                  :value="supervisor.id"
                >
                  {{ supervisor.first_name }} {{ supervisor.last_name }}
                </option>
              </select>
            </div>
            
            <div class="shift-type-buttons">
              <button 
                @click="createDayShift()" 
                class="btn btn-shift-type"
                :disabled="creating || !selectedDate || !selectedSupervisor"
                :style="{ backgroundColor: getShiftColor(isDayShiftWeekend ? 'weekend_day' : 'week_day') }"
              >
                <span v-if="!creating">Create {{ isDayShiftWeekend ? 'Weekend' : 'Weekday' }} Day Shift</span>
                <span v-else class="loading-indicator">
                  <span class="loading-spinner"></span>
                  Creating...
                </span>
              </button>
              
              <button 
                @click="createNightShift()" 
                class="btn btn-shift-type"
                :disabled="creating || !selectedDate || !selectedSupervisor"
                :style="{ backgroundColor: getShiftColor(isDayShiftWeekend ? 'weekend_night' : 'week_night') }"
              >
                <span v-if="!creating">Create {{ isDayShiftWeekend ? 'Weekend' : 'Weekday' }} Night Shift</span>
                <span v-else class="loading-indicator">
                  <span class="loading-spinner"></span>
                  Creating...
                </span>
              </button>
            </div>
          </div>
          
          <!-- Removed the second step since we now have a single-step approach -->
          
          <div v-if="error" class="error-message">
            {{ error }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useSettingsStore } from '../stores/settingsStore';
import * as XLSX from 'xlsx';

const router = useRouter();
const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const settingsStore = useSettingsStore();

// Local state
const selectedSupervisor = ref('');
const selectedShiftType = ref(null); // New ref for tracking selected shift type
const selectedDate = ref(new Date().toISOString().split('T')[0]); // Default to today in YYYY-MM-DD format
const selectedShifts = ref([]); // For tracking selected shifts for export
const creating = ref(false);
const error = ref('');
const detectedShiftType = ref('week_day'); // Used for auto-detection, still needed for existing functionality
const updateTimer = ref(null);

// Computed properties
const loading = computed(() => shiftsStore.loading.activeShifts || staffStore.loading.supervisors);
const activeShifts = computed(() => shiftsStore.activeShifts);
const dayShifts = computed(() => shiftsStore.activeDayShifts);
const nightShifts = computed(() => shiftsStore.activeNightShifts);
const supervisors = computed(() => staffStore.sortedSupervisors);
const today = computed(() => new Date().toISOString().split('T')[0]); // Current date in YYYY-MM-DD format for date input min

// Check if the selected date is a weekend
const isDayShiftWeekend = computed(() => {
  if (!selectedDate.value) return false;
  const date = new Date(selectedDate.value);
  return isWeekend(date);
});

// Determine the full shift type based on day/night selection and weekend status
const fullShiftType = computed(() => {
  if (!selectedShiftType.value) return '';
  
  const prefix = isDayShiftWeekend.value ? 'weekend_' : 'week_';
  return prefix + selectedShiftType.value;
});

// Load data and start auto-detection
onMounted(async () => {
  // Initialize settings (to get shift colors)
  await settingsStore.loadSettings();
  
  // Load supervisors and active shifts in parallel
  await Promise.all([
    staffStore.fetchSupervisors(),
    shiftsStore.fetchActiveShifts()
  ]);
  
  // Determine shift type initially
  determineShiftType();
  
  // Set up timer to update the shift type every minute
  updateTimer.value = setInterval(() => {
    determineShiftType();
  }, 60000); // 60 seconds
});

// Clean up timer when component is unmounted
onUnmounted(() => {
  if (updateTimer.value) {
    clearInterval(updateTimer.value);
  }
});

// Determine the current shift type based on time and day
function determineShiftType() {
  const now = new Date();
  const isCurrentDayWeekend = isWeekend(now);
  
  // Parse settings times into minutes for easier comparison
  const dayStartMinutes = parseTimeString(settingsStore.shiftDefaults.week_day.startTime);
  const dayEndMinutes = parseTimeString(settingsStore.shiftDefaults.week_day.endTime);
  const nightStartMinutes = parseTimeString(settingsStore.shiftDefaults.week_night.startTime);
  const nightEndMinutes = parseTimeString(settingsStore.shiftDefaults.week_night.endTime);
  
  // Get current time in minutes
  const currentHours = now.getHours();
  const currentMinutes = now.getMinutes();
  const currentTimeInMinutes = (currentHours * 60) + currentMinutes;
  
  // Check if current time is during day shift
  let isDayShift;
  
  // Handle overnight night shifts (e.g., 20:00 to 08:00)
  if (nightEndMinutes < nightStartMinutes) {
    // Night shift spans midnight
    isDayShift = currentTimeInMinutes < nightEndMinutes || currentTimeInMinutes >= dayStartMinutes;
  } else {
    // Normal day/night split
    isDayShift = currentTimeInMinutes >= dayStartMinutes && currentTimeInMinutes < nightStartMinutes;
  }
  
  // Set shift type based on time and day
  if (isCurrentDayWeekend) {
    detectedShiftType.value = isDayShift ? 'weekend_day' : 'weekend_night';
  } else {
    detectedShiftType.value = isDayShift ? 'week_day' : 'week_night';
  }
}

// Parse time string (HH:MM) to minutes
function parseTimeString(timeString) {
  const [hours, minutes] = timeString.split(':').map(Number);
  return (hours * 60) + minutes;
}

// Format the shift type name for display
function formatShiftTypeName(shiftType) {
  switch (shiftType) {
    case 'week_day':
      return 'Weekday Day Shift';
    case 'week_night':
      return 'Weekday Night Shift';
    case 'weekend_day':
      return 'Weekend Day Shift';
    case 'weekend_night':
      return 'Weekend Night Shift';
    default:
      return 'Unknown Shift Type';
  }
}

// Format current date and time for display
function formatCurrentDateTime() {
  const now = new Date();
  const formattedDate = now.toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  });
  const formattedTime = now.toLocaleTimeString('en-US', { 
    hour: 'numeric', 
    minute: '2-digit', 
    hour12: true 
  });
  return `${formattedDate} at ${formattedTime}`;
}

// Select a shift type
function selectShiftType(shiftType) {
  selectedShiftType.value = shiftType;
  // Reset supervisor selection when changing shift type
  selectedSupervisor.value = '';
}

// Reset the shift type selection to go back to step 1
function resetSelection() {
  selectedShiftType.value = null;
  selectedSupervisor.value = '';
}

// Create a new shift
async function createShift(baseShiftType) {
  if (!selectedSupervisor.value) {
    error.value = 'Please select a supervisor';
    return;
  }
  
  if (!selectedDate.value) {
    error.value = 'Please select a date';
    return;
  }
  
  creating.value = true;
  error.value = '';
  
  try {
    // Get the full shift type (week_day, weekend_night, etc.)
    const completeShiftType = fullShiftType.value;
    
    console.log(`Creating new shift: type=${completeShiftType}, date=${selectedDate.value}`);
    
    // Create a date object for the selected date with current time
    const selectedDateObj = new Date(selectedDate.value);
    const now = new Date();
    
    // Set the time part of the selected date to the current time
    selectedDateObj.setHours(now.getHours(), now.getMinutes(), now.getSeconds());
    
    // Convert to ISO string
    const startTime = selectedDateObj.toISOString();
    
    // Use the complete shift type with custom start time
    const newShift = await shiftsStore.createShift(
      selectedSupervisor.value, 
      completeShiftType,
      startTime
    );
    if (newShift) {
      // The setupShiftAreaCoverFromDefaults function takes care of initializing default assignments
      // No need for additional initialization as it's handled in createShift
      
      // Navigate to the shift management view for the new shift
      router.push(`/shift/${newShift.id}`);
    } else {
      error.value = 'Failed to create shift';
    }
  } catch (err) {
    console.error('Error creating shift:', err);
    error.value = 'An unexpected error occurred';
  } finally {
    creating.value = false;
  }
}

// Helper function to determine if a date is on a weekend
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Get the appropriate color for a shift type
function getShiftColor(shiftType) {
  switch (shiftType) {
    case 'week_day':
    case 'weekend_day':
      // Use day shift color for both weekday and weekend day shifts
      return settingsStore.shiftDefaults.week_day.color;
    case 'week_night':
    case 'weekend_night':
      // Use night shift color for both weekday and weekend night shifts
      return settingsStore.shiftDefaults.week_night.color;
    default:
      return '#4285F4'; // Default blue color
  }
}

// View a shift
function viewShift(shiftId) {
  router.push(`/shift/${shiftId}`);
}

// Format date (e.g., "May 23, 2025")
function formatDate(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

// Format date for display with ordinal suffix (e.g., "23rd May 2025")
function formatShortDate(date) {
  if (!date) return '';
  
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
}

// Helper to get the correct ordinal suffix for a day
function getDayOrdinalSuffix(day) {
  if (day > 3 && day < 21) return 'th';
  switch (day % 10) {
    case 1: return 'st';
    case 2: return 'nd';
    case 3: return 'rd';
    default: return 'th';
  }
}

// Shift selection functions
function isShiftSelected(shift) {
  return selectedShifts.value.some(s => s.id === shift.id);
}

const isAllSelected = computed(() => {
  return activeShifts.value.length > 0 && selectedShifts.value.length === activeShifts.value.length;
});

function toggleSelectAll() {
  if (isAllSelected.value) {
    selectedShifts.value = [];
  } else {
    selectedShifts.value = [...activeShifts.value];
  }
}

function toggleShiftSelection(shift, event) {
  // If the click was on the checkbox, don't do anything here
  // as the @change event on the checkbox will handle it
  if (event.target.type === 'checkbox') {
    return;
  }
  
  const index = selectedShifts.value.findIndex(s => s.id === shift.id);
  if (index === -1) {
    selectedShifts.value.push(shift);
  } else {
    selectedShifts.value.splice(index, 1);
  }
}

// Export selected shifts to Excel in a comprehensive roster format
async function exportSelectedShifts() {
  if (selectedShifts.value.length === 0) return;
  
  try {
    // Load all necessary data for the export
    await staffStore.initialize(); // Ensure we have all staff data

    // Create a new workbook
    const workbook = XLSX.utils.book_new();
    
    // Process each selected shift
    for (const shift of selectedShifts.value) {
      // Fetch full shift data
      await Promise.all([
        shiftsStore.fetchShiftById(shift.id),
        shiftsStore.fetchShiftTasks(shift.id),
        shiftsStore.fetchShiftAreaCover(shift.id),
        shiftsStore.fetchShiftSupportServices(shift.id),
        shiftsStore.fetchShiftPorterPool(shift.id)
      ]);
      
      // Get the shift date
      const shiftDate = new Date(shift.start_time);
      
      // Format date for display
      const dateOptions = { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' };
      const formattedDate = shiftDate.toLocaleDateString('en-GB', dateOptions);
      
      // Create an array to hold the roster data
      const rosterData = [];
      
      // Add the header row with the date repeated
      const headerRow = Array(12).fill(formattedDate);
      rosterData.push(headerRow);
      
      // Add section for day supervisors
      rosterData.push(['Supervisor', '0800 - 2000', '11', shift.shift_type.includes('day') ? 
        (shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : '') : '', '', 
        'Relief Porters', 'Relief Porters', 'Relief Porters', 'Relief Porters', 'Covering', '', '']);
      
      // Add regular day porters
      const dayPorters = shiftsStore.shiftPorterPool.filter(p => 
        p.porter && !p.end_time // Assume day shift porters if no end time specified
      );
      
      // Add numbered rows for day porters
      for (let i = 1; i <= 10; i++) {
        const porter = dayPorters[i-1];
        if (porter && porter.porter) {
          rosterData.push([
            i.toString(), 
            '0800 - 2000', 
            '11', 
            `${porter.porter.first_name} ${porter.porter.last_name}`,
            '',
            i <= 7 ? i.toString() : '', // Relief porter number (only show for first 7)
            i <= 7 ? '0800-2000' : '',  // Relief porter time
            i <= 7 ? '11' : '',         // Relief porter hours
            i <= 7 ? '' : '',           // Relief porter name
            '', '', ''
          ]);
        } else {
          // Empty row for missing porter
          rosterData.push([i.toString(), '0800 - 2000', '11', '', '', 
            i <= 7 ? i.toString() : '', 
            i <= 7 ? '0800-2000' : '', 
            i <= 7 ? '11' : '', 
            '', '', '', '']);
        }
      }
      
      // Add a blank row
      rosterData.push(Array(12).fill(''));
      
      // Add section for night supervisors
      rosterData.push(['Supervisor', '2000 - 0800', '11', !shift.shift_type.includes('day') ? 
        (shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : '') : '', '', '', '', '', '', '', '', '']);
      
      // Add night porters
      const nightPorters = shiftsStore.shiftPorterPool.filter(p => 
        p.porter && p.end_time // Assume night shift porters if end time specified
      );
      
      // Add numbered rows for night porters
      for (let i = 1; i <= 7; i++) {
        const porter = nightPorters[i-1];
        if (porter && porter.porter) {
          rosterData.push([
            i.toString(), 
            '2000 - 0800', 
            '11', 
            `${porter.porter.first_name} ${porter.porter.last_name}`,
            i === 6 || i === 7 ? '' : '', // Extra column for some rows
            '', '', '', '', '', '', ''
          ]);
        } else {
          // Empty row for missing porter
          rosterData.push([i.toString(), '2000 - 0800', '11', '', i === 6 || i === 7 ? '' : '', '', '', '', '', '', '', '']);
        }
      }
      
      // Add empty rows
      rosterData.push(Array(12).fill(''));
      rosterData.push(['', 'Accident And Emergency', '', '', '', '', '', '', '', '', '', '']);
      
      // Add A&E staff rows
      const aeStaff = [
        { time: '0600-1400', hours: '7.5', name: 'Stuart Ford' },
        { time: '0900-1700', hours: '7.5', name: 'Lee Stafford' },
        { time: '1300-2300', hours: '9.5', name: 'Nicola Benger' },
        { time: '1400-2200', hours: '7.5', name: 'Jeff Robinson' }
      ];
      
      for (const staff of aeStaff) {
        rosterData.push(['A&E', staff.time, staff.hours, staff.name, '', '', '', '', '', '', '', '']);
      }
      
      rosterData.push(['Amu', '1200-2000', '7.5', '', '', '', '', '', '', '', '', '']);
      
      // Add other sections
      rosterData.push(['', 'Additional Demand', '', '', '', '', '', '', '', '', '', '']);
      rosterData.push(Array(12).fill(''));
      
      // Medical Records section
      rosterData.push(['Medical Records', 'Medical Records', 'Medical Records', 'Medical Records', '', 'Blood Drivers', 'Blood Drivers', 'Blood Drivers', 'Blood Drivers', '', '', '']);
      for (let i = 1; i <= 3; i++) {
        rosterData.push(['Med Recs', '0800 - 1600', '7.5', '', '', `Driver ${i}`, '0900 - 1700', '7.5', '', '', '', '']);
      }
      rosterData.push(['', '', '', '', '', 'Driver 4', '0830 - 1630', '7.5', '', '', '', '']);
      
      // Post section
      rosterData.push(['Post', 'Post', 'Post', 'Post', '', 'Laundry', 'Laundry', 'Laundry', 'Laundry', '', '', '']);
      rosterData.push(['Post', '0800 - 1600', '7.5', '', '', 'Laundry', '0700 - 1500', '7.5', '', '', '', '']);
      rosterData.push(['Post', '0900 - 1700', '7.5', '', '', 'Laundry', '0700 - 1500', '7.5', '', '', '', '']);
      
      // Sharps & Cages section
      rosterData.push(['Sharps', 'Sharps', 'Sharps', 'Sharps', '', 'External Waste', 'External Waste', 'External Waste', 'External Waste', '', '', '']);
      rosterData.push(['Cages', '0700 - 1500', '7.5', '', '', 'Waste', '0700 - 1500', '7.5', '', '', '', '']);
      rosterData.push(['Cages', '0700 - 1500', '7.5', '', '', 'Waste', '0700 - 1500', '7.5', '', '', '', '']);
      rosterData.push(Array(12).fill(''));
      
      // Helpdesk section
      rosterData.push(['Helpdesk', 'Helpdesk', 'Helpdesk', 'Helpdesk', '', '', '', '', '', '', '', '']);
      rosterData.push(['Helpdesk', '09:00-17:00', '7.5', '', '', 'Ad-Hoc', 'Ad-Hoc', 'Ad-Hoc', 'Ad-Hoc', '', '', '']);
      rosterData.push(['Helpdesk', '17:00-20:00', '7.5', '', '', 'Ad-Hoc', '0700 - 1500', '7.5', '', '', '', '']);
      
      // District Driver/Pharmacy section
      rosterData.push(['District Driver/Pharmacy', 'District Driver/Pharmacy', 'District Driver/Pharmacy', 'District Driver/Pharmacy', '', 'Ad-Hoc', '0700 - 1500', '7.5', '', '', '', '']);
      rosterData.push(['District ', '0700 - 1500', '7.5', '', '', '', '', '', '', '', '', '']);
      rosterData.push(['Pharmacy', '0730 - 1530', '7.5', '', '', 'Pharmacy', '15:00-20:00', '7.5', '', '', '', '']);
      
      // Create worksheet and add to workbook
      // Extract the day name for the sheet name
      const dayName = shiftDate.toLocaleDateString('en-GB', { weekday: 'long' });
      const worksheet = XLSX.utils.aoa_to_sheet(rosterData);
      
      // Set column widths
      const colWidths = [10, 15, 8, 20, 20, 15, 15, 8, 20, 15, 8, 8];
      worksheet['!cols'] = colWidths.map(width => ({ width }));
      
      // Add the worksheet to the workbook
      XLSX.utils.book_append_sheet(workbook, worksheet, dayName);
      
      // If multiple shifts are selected and include a full week, add a Relief sheet
      if (selectedShifts.value.length >= 5) {
        // Create Relief sheet
        const reliefData = [
          ['Relief shifts week commencing Monday', '', '', '', '', '', '', '', ''],
          ['NAME', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY', 'COMMENTS'],
        ];
        
        // Add some empty relief rows
        for (let i = 0; i < 10; i++) {
          reliefData.push(['', '', '', '', '', '', '', '', '']);
        }
        
        // Add a note at the bottom
        reliefData.push(['* Please check NHSP for all available shifts', '', '', '', '', '', '', '', '']);
        
        const reliefSheet = XLSX.utils.aoa_to_sheet(reliefData);
        XLSX.utils.book_append_sheet(workbook, reliefSheet, 'Relief');
        
        // Create Overtime sheet
        const overtimeData = [
          ['NHSP Shifts Overtime', '', ''],
          ['Week Commencing ' + formattedDate, '', ''],
          ['The following shifts are on NHSP - All shifts will be available from 12pm every Tuesday', '', ''],
          ['', '', ''],
          ['DAY/DATE', 'SHIFT', 'STAFF MEMBER ASIGNED'],
        ];
        
        // Add overtime shift rows for each day
        const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        for (const day of days) {
          overtimeData.push([day, '2/10.', '']);
          overtimeData.push(['', '8/8 Night', '']);
          if (day !== 'Monday' && day !== 'Sunday') {
            overtimeData.push(['', '1/1 PTS', '']);
          }
        }
        
        const overtimeSheet = XLSX.utils.aoa_to_sheet(overtimeData);
        XLSX.utils.book_append_sheet(workbook, overtimeSheet, 'Overtime');
      }
    }
    
    // Generate filename based on the date range of selected shifts
    let filename;
    if (selectedShifts.value.length === 1) {
      // For a single shift, use the date of that shift
      const shiftDate = new Date(selectedShifts.value[0].start_time);
      const dateOptions = { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' };
      const formattedDate = shiftDate.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });
      filename = `${formattedDate}.xlsx`;
    } else {
      // For multiple shifts, use the date range
      const startDate = new Date(Math.min(...selectedShifts.value.map(s => new Date(s.start_time).getTime())));
      const endDate = new Date(Math.max(...selectedShifts.value.map(s => new Date(s.start_time).getTime())));
      
      const formatDateStr = (date) => {
        return date.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });
      };
      
      filename = `${formatDateStr(startDate)} to ${formatDateStr(endDate)}.xlsx`;
    }
    
    // Export the file
    XLSX.writeFile(workbook, filename);
    
    console.log(`Exported ${selectedShifts.value.length} shifts to ${filename}`);
  } catch (error) {
    console.error('Error exporting shifts:', error);
    alert('Failed to export shifts. See console for details.');
  }
}

// Format time (e.g., "9:30 AM")
function formatTime(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
}

// Helper functions for creating day and night shifts
function createDayShift() {
  // Set the shift type to 'day' and create the shift
  selectedShiftType.value = 'day';
  createShift();
}

function createNightShift() {
  // Set the shift type to 'night' and create the shift
  selectedShiftType.value = 'night';
  createShift();
}

// Calculate duration since start time
function calculateDuration(startTimeString) {
  if (!startTimeString) return '';
  
  const startTime = new Date(startTimeString);
  const now = new Date();
  
  const diffMs = now - startTime;
  const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
  const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
  
  if (diffHrs === 0) {
    return `${diffMins}m`;
  } else if (diffMins === 0) {
    return `${diffHrs}h`;
  } else {
    return `${diffHrs}h ${diffMins}m`;
  }
}
</script>

<style lang="scss" scoped>
.mb-4 {
  margin-bottom: 1rem;
}

.card__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.selection-controls {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 1rem;
  
  .select-all-container {
    display: flex;
    align-items: center;
    cursor: pointer;
    
    input {
      margin-right: 0.5rem;
    }
  }
}

.btn-export {
  background-color: #4caf50;
  color: white;
  border: none;
  border-radius: 4px;
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
  cursor: pointer;
  transition: background-color 0.2s;
  
  &:hover:not(:disabled) {
    background-color: #45a049;
  }
  
  &:disabled {
    background-color: #cccccc;
    cursor: not-allowed;
  }
}

.shifts-grid {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.shift-group {
  h3 {
    margin-bottom: 0.75rem;
    font-size: 1.1rem;
  }
}

.shift-cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 1rem;
}

.shift-card {
  border: 2px solid #ccc;
  border-radius: 6px;
  padding: 1rem;
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
  
  &:hover {
    transform: translateY(-3px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  }
  
  &__header {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0.5rem;
    
    .shift-type {
      font-weight: bold;
    }
    
    .shift-date {
      font-size: 0.9rem;
      color: #666;
    }
  }
  
  &__selection {
    display: flex;
    align-items: center;
    
    input[type="checkbox"] {
      margin-right: 0.5rem;
    }
  }
  
  &__body {
    p {
      margin: 0.5rem 0;
      font-size: 0.95rem;
    }
  }
}

.create-shift-form {
  .form-group {
    margin-bottom: 1rem;
    
    label {
      display: block;
      margin-bottom: 0.5rem;
      font-weight: bold;
    }
    
    .form-control {
      width: 100%;
      padding: 0.5rem;
      border: 1px solid #ccc;
      border-radius: 4px;
      font-size: 1rem;
    }
  }
  
  .form-actions {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-top: 1.5rem;
  }
}

.shift-type-selection {
  .instruction {
    text-align: center;
    margin-bottom: 1.25rem;
    font-weight: 500;
    font-size: 1.1rem;
  }
  
  .date-picker-container {
    max-width: 400px;
    margin: 0 auto 1.5rem auto;
  }
  
  .shift-type-buttons {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 1rem;
    max-width: 600px;
    margin: 0 auto;
  }
  
  .date-info {
    text-align: center;
    margin-top: 1rem;
    padding: 0.5rem;
    background-color: rgba(0, 0, 0, 0.05);
    border-radius: 4px;
    color: #333;
    font-size: 0.95rem;
    
    strong {
      color: #4285F4;
    }
  }
}

.supervisor-selection {
  .selection-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
    padding-bottom: 0.75rem;
    border-bottom: 1px solid #eee;
    
    .selected-type {
      font-size: 1rem;
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 0.5rem;
      
      .shift-date {
        font-size: 0.9rem;
        color: #666;
        font-weight: normal;
        margin-left: 0.5rem;
      }
    }
    
    .btn-reset {
      background: none;
      border: 1px solid #ccc;
      border-radius: 4px;
      padding: 0.3rem 0.6rem;
      font-size: 0.9rem;
      cursor: pointer;
      transition: all 0.2s;
      
      &:hover {
        background-color: #f5f5f5;
      }
    }
  }
}

.btn-shift-type, 
.btn-create-shift {
  padding: 16px 24px;
  border: none;
  border-radius: 6px;
  color: white;
  font-weight: 600;
  font-size: 1.1rem;
  cursor: pointer;
  transition: all 0.2s ease;
  width: 100%;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
  margin: 10px 0;
  text-align: center;
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
  
  &:not(:disabled):hover {
    opacity: 0.9;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
  }
  
  &:not(:disabled):active {
    transform: translateY(1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }
}

.btn-shift-type {
  // Specific styles for the shift type buttons
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  height: 80px;
}

.btn-create-shift {
  // Specific styles for the create shift button
  font-size: 1.2rem;
  margin-top: 2rem;
}

.error-message {
  margin-top: 1rem;
  padding: 0.5rem;
  background-color: rgba(220, 53, 69, 0.1);
  border: 1px solid rgba(220, 53, 69, 0.3);
  border-radius: 4px;
  color: #dc3545;
}

.loading-indicator, .empty-state {
  padding: 2rem 0;
  text-align: center;
  color: #666;
}

// Loading spinner in buttons
.loading-spinner {
  display: inline-block;
  width: 20px;
  height: 20px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  border-top-color: #fff;
  animation: spin 1s ease-in-out infinite;
  margin-right: 8px;
  vertical-align: middle;
}

.loading-indicator {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.supervisor-picker-container {
  max-width: 400px;
  margin: 0 auto 1.5rem auto;
}
</style>
