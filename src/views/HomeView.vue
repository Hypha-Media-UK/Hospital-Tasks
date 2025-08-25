<template>
  <div class="view">
    <div class="view__content">
      <AnimatedTabs
        v-model="activeTabId"
        :tabs="tabDefinitions"
        @tab-change="handleTabChange"
        class="home-tabs"
      >
          <!-- Active Shifts Tab -->
          <template #active-shifts>
            <header class="card__header">
              <h2 class="card__title">Active Shifts</h2>
              <button
                @click="exportSelectedShifts"
                class="btn btn-export"
                :disabled="selectedShifts.length === 0"
              >
                Export Selected Shifts
              </button>
            </header>

            <div v-if="loading" class="loading-indicator">
              <p>Loading shifts...</p>
            </div>

            <div v-else-if="activeShifts.length === 0" class="empty-state">
              <svg class="empty-state__icon" width="64" height="64" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 8V12L15 15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/>
              </svg>
              <p>No active shifts. Create a new shift to get started.</p>
              <button @click="activeTabId = 'create-shift'" class="btn btn-primary empty-state__action">
                Create Shift
              </button>
            </div>

            <div v-else>
              <div class="selection-controls" v-if="activeShifts.length > 0">
                <label class="select-all-container">
                  <input
                    type="checkbox"
                    :checked="isAllSelected"
                    @change="toggleSelectAll"
                  />
                  <span class="custom-checkbox"></span>
                  <span>Select All</span>
                </label>
              </div>

              <div class="shifts-grid">
                <!-- Day Shifts -->
                <section v-if="dayShifts.length > 0" class="shift-group">
                  <h3>Day Shifts</h3>
                  <div class="shift-cards">
                    <article
                      v-for="shift in dayShifts"
                      :key="shift.id"
                      class="shift-card"
                      :style="{ borderColor: getShiftColor(shift.shift_type) }"
                      @click="viewShift(shift.id)"
                    >
                      <div class="shift-card__color-bar" :style="{ backgroundColor: getShiftColor(shift.shift_type) }"></div>
                      <header class="shift-card__header">
                        <div class="shift-card__type">
                          <DayShiftIcon v-if="shift.shift_type.includes('day')" size="18" class="shift-icon" />
                          <NightShiftIcon v-else size="18" class="shift-icon" />
                          <span class="shift-type">Day Shift</span>
                        </div>
                        <div class="shift-card__right">
                          <span class="shift-date">{{ formatDate(shift.start_time) }}</span>
                          <label class="checkbox-wrapper">
                            <input
                              type="checkbox"
                              :checked="isShiftSelected(shift)"
                              @change="toggleShiftSelection(shift, $event)"
                              @click.stop
                            />
                            <span class="custom-checkbox"></span>
                          </label>
                        </div>
                      </header>
                      <div class="shift-card__body">
                        <div class="detail-row">
                          <svg class="detail-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M20 21V19C20 17.9391 19.5786 16.9217 18.8284 16.1716C18.0783 15.4214 17.0609 15 16 15H8C6.93913 15 5.92172 15.4214 5.17157 16.1716C4.42143 16.9217 4 17.9391 4 19V21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="M12 11C14.2091 11 16 9.20914 16 7C16 4.79086 14.2091 3 12 3C9.79086 3 8 4.79086 8 7C8 9.20914 9.79086 11 12 11Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                          </svg>
                          <p class="supervisor">
                            <span class="detail-label">Supervisor:</span>
                            <span class="detail-value">{{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}</span>
                          </p>
                        </div>
                        <footer class="shift-card__footer">
                          <button class="btn-view-shift">View Details</button>
                        </footer>
                      </div>
                    </article>
                  </div>
                </section>

                <!-- Night Shifts -->
                <section v-if="nightShifts.length > 0" class="shift-group">
                  <h3>Night Shifts</h3>
                  <div class="shift-cards">
                    <article
                      v-for="shift in nightShifts"
                      :key="shift.id"
                      class="shift-card"
                      :style="{ borderColor: getShiftColor(shift.shift_type) }"
                      @click="viewShift(shift.id)"
                    >
                      <div class="shift-card__color-bar" :style="{ backgroundColor: getShiftColor(shift.shift_type) }"></div>
                      <header class="shift-card__header">
                        <div class="shift-card__type">
                          <DayShiftIcon v-if="shift.shift_type.includes('day')" size="18" class="shift-icon" />
                          <NightShiftIcon v-else size="18" class="shift-icon" />
                          <span class="shift-type">Night Shift</span>
                        </div>
                        <div class="shift-card__right">
                          <span class="shift-date">{{ formatDate(shift.start_time) }}</span>
                          <label class="checkbox-wrapper">
                            <input
                              type="checkbox"
                              :checked="isShiftSelected(shift)"
                              @change="toggleShiftSelection(shift, $event)"
                              @click.stop
                            />
                            <span class="custom-checkbox"></span>
                          </label>
                        </div>
                      </header>
                      <div class="shift-card__body">
                        <div class="detail-row">
                          <svg class="detail-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M20 21V19C20 17.9391 19.5786 16.9217 18.8284 16.1716C18.0783 15.4214 17.0609 15 16 15H8C6.93913 15 5.92172 15.4214 5.17157 16.1716C4.42143 16.9217 4 17.9391 4 19V21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                            <path d="M12 11C14.2091 11 16 9.20914 16 7C16 4.79086 14.2091 3 12 3C9.79086 3 8 4.79086 8 7C8 9.20914 9.79086 11 12 11Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                          </svg>
                          <p class="supervisor">
                            <span class="detail-label">Supervisor:</span>
                            <span class="detail-value">{{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}</span>
                          </p>
                        </div>
                        <footer class="shift-card__footer">
                          <button class="btn-view-shift">View Details</button>
                        </footer>
                      </div>
                    </article>
                  </div>
                </section>
              </div>
            </div>
          </template>
          
          <!-- Create New Shift Tab -->
          <template #create-shift>
            <QuickShiftCreator />
          </template>
      </AnimatedTabs>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useSettingsStore } from '../stores/settingsStore';
import AnimatedTabs from '../components/shared/AnimatedTabs.vue';
import DayShiftIcon from '../components/icons/DayShiftIcon.vue';
import NightShiftIcon from '../components/icons/NightShiftIcon.vue';
import ClockIcon from '../components/icons/ClockIcon.vue';
import QuickShiftCreator from '../components/QuickShiftCreator.vue';
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
const formStep = ref(1); // For multi-step form (1=date, 2=supervisor, 3=shift type)
const supervisorFilter = ref(''); // For filtering supervisors list

// Tab state
const activeTabId = ref('active-shifts');
const tabChangeDirection = ref(0);

// Tab definitions
const tabDefinitions = computed(() => [
  { id: 'active-shifts', label: 'Active Shifts' },
  { id: 'create-shift', label: 'Create New Shift' }
]);

// Handle tab change
function handleTabChange(tabId) {
  // Calculate direction of tab change for animation
  const oldIndex = tabDefinitions.value.findIndex(tab => tab.id === activeTabId.value);
  const newIndex = tabDefinitions.value.findIndex(tab => tab.id === tabId);
  
  if (oldIndex !== -1 && newIndex !== -1) {
    tabChangeDirection.value = newIndex > oldIndex ? 1 : -1;
  } else {
    tabChangeDirection.value = 0;
  }
}

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

// Get weekday name from date
function getWeekdayName(dateString) {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', { weekday: 'long' });
}

// Format month for calendar display
function formatMonth(dateString) {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', { month: 'long' });
}

// Format day number for calendar display
function formatDayNumber(dateString) {
  const date = new Date(dateString);
  return date.getDate();
}

// Format year for calendar display
function formatYear(dateString) {
  const date = new Date(dateString);
  return date.getFullYear();
}

// Format full date with weekday
function formatFullDate(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', { 
    weekday: 'long',
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  });
}

// Get initials from name
function getInitials(firstName, lastName) {
  return (firstName ? firstName.charAt(0) : '') + (lastName ? lastName.charAt(0) : '');
}

// Get the selected supervisor's initials
function getSelectedSupervisorInitials() {
  const supervisor = supervisors.value.find(s => s.id === selectedSupervisor.value);
  if (!supervisor) return '';
  return getInitials(supervisor.first_name, supervisor.last_name);
}

// Get the selected supervisor's full name
function getSelectedSupervisorName() {
  const supervisor = supervisors.value.find(s => s.id === selectedSupervisor.value);
  if (!supervisor) return 'Not selected';
  return `${supervisor.first_name} ${supervisor.last_name}`;
}

// Select a supervisor
function selectSupervisor(supervisorId) {
  selectedSupervisor.value = supervisorId;
}

// Check if date is selected and valid
function checkDateSelection() {
  if (!selectedDate.value) {
    error.value = 'Please select a valid date';
    return false;
  }
  error.value = '';
  return true;
}

// Filtered supervisors based on search input
const filteredSupervisors = computed(() => {
  if (!supervisorFilter.value) return supervisors.value;
  
  const filter = supervisorFilter.value.toLowerCase();
  return supervisors.value.filter(supervisor => {
    const fullName = `${supervisor.first_name} ${supervisor.last_name}`.toLowerCase();
    return fullName.includes(filter);
  });
});

// Convert time to position percentage for timeline
function getTimePosition(timeString) {
  if (!timeString) return 0;
  const [hours, minutes] = timeString.split(':').map(Number);
  return ((hours * 60 + minutes) / (24 * 60)) * 100;
}

// Calculate width percentage between start and end times
function getTimeWidth(startTime, endTime) {
  if (!startTime || !endTime) return 0;
  
  const [startHours, startMinutes] = startTime.split(':').map(Number);
  const [endHours, endMinutes] = endTime.split(':').map(Number);
  
  let startMinutesTotal = startHours * 60 + startMinutes;
  let endMinutesTotal = endHours * 60 + endMinutes;
  
  // Handle overnight shifts
  if (endMinutesTotal < startMinutesTotal) {
    endMinutesTotal += 24 * 60; // Add 24 hours
  }
  
  return ((endMinutesTotal - startMinutesTotal) / (24 * 60)) * 100;
}

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
  const shiftDefaults = settingsStore.shiftDefaultsByType;
  
  // Check if shift defaults are loaded
  if (!shiftDefaults.week_day || !shiftDefaults.week_night) {
    return; // Exit early if shift defaults aren't loaded yet
  }
  
  // Parse settings times into minutes for easier comparison
  const dayStartMinutes = parseTimeString(settingsStore.formatTime(shiftDefaults.week_day.start_time));
  const dayEndMinutes = parseTimeString(settingsStore.formatTime(shiftDefaults.week_day.end_time));
  const nightStartMinutes = parseTimeString(settingsStore.formatTime(shiftDefaults.week_night.start_time));
  const nightEndMinutes = parseTimeString(settingsStore.formatTime(shiftDefaults.week_night.end_time));
  
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
  const shiftDefaults = settingsStore.shiftDefaultsByType;
  
  switch (shiftType) {
    case 'week_day':
    case 'weekend_day':
      // Use day shift color for both weekday and weekend day shifts
      return shiftDefaults.week_day?.color || '#4285F4';
    case 'week_night':
    case 'weekend_night':
      // Use night shift color for both weekday and weekend night shifts
      return shiftDefaults.week_night?.color || '#673AB7';
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

// Format time (e.g., "9:30 AM")
function formatTime(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
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
    
  } catch (error) {
    alert('Failed to export shifts. Please try again.');
  }
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

<!-- Styles are now handled by the global CSS layers -->