<template>
  <div class="view">
    <div class="view__content">
      <!-- Active Shifts Section -->
      <div class="card mb-4">
        <h2 class="card__title">Active Shifts</h2>
        
        <div v-if="loading" class="loading-indicator">
          <p>Loading shifts...</p>
        </div>
        
        <div v-else-if="activeShifts.length === 0" class="empty-state">
          <p>No active shifts. Create a new shift to get started.</p>
        </div>
        
        <div v-else class="shifts-grid">
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
                  <span class="shift-type">Day Shift</span>
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
                  <span class="shift-type">Night Shift</span>
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
      
      <!-- Create New Shift Section -->
      <div class="card">
        <h2 class="card__title">Create New Shift</h2>
        
        <div class="create-shift-form">
          <!-- Step 1: Select Date and Shift Type -->
          <div v-if="!selectedShiftType" class="shift-type-selection">
            <p class="instruction">Select a date and shift type to start:</p>
            
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
            
            <div class="shift-type-buttons">
              <button 
                @click="selectShiftType('day')" 
                class="btn btn-shift-type"
                :disabled="creating || !selectedDate"
                :style="{ backgroundColor: getShiftColor(isDayShiftWeekend ? 'weekend_day' : 'week_day') }"
              >
                Create Day Shift
              </button>
              
              <button 
                @click="selectShiftType('night')" 
                class="btn btn-shift-type"
                :disabled="creating || !selectedDate"
                :style="{ backgroundColor: getShiftColor(isDayShiftWeekend ? 'weekend_night' : 'week_night') }"
              >
                Create Night Shift
              </button>
            </div>
            
            <p v-if="selectedDate" class="date-info">
              Selected date is a <strong>{{ isDayShiftWeekend ? 'weekend' : 'weekday' }}</strong> shift
            </p>
          </div>
          
          <!-- Step 2: Select Supervisor (shown after shift type is selected) -->
          <div v-else class="supervisor-selection">
            <div class="selection-header">
              <div class="selected-type">
                <span>Selected: </span>
                <strong :style="{ color: getShiftColor(fullShiftType) }">
                  {{ isDayShiftWeekend ? 'Weekend' : 'Weekday' }} {{ selectedShiftType === 'day' ? 'Day' : 'Night' }} Shift
                </strong>
                <span class="shift-date">{{ formatShortDate(new Date(selectedDate)) }}</span>
              </div>
              <button @click="resetSelection" class="btn-reset">Change</button>
            </div>

            <div class="form-group">
              <label for="supervisor">Select Supervisor</label>
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
            
            <div class="form-actions">
              <button 
                @click="createShift(selectedShiftType)" 
                class="btn btn-create-shift"
                :disabled="!selectedSupervisor || !selectedDate || creating"
                :style="{ backgroundColor: getShiftColor(fullShiftType) }"
              >
                Start {{ isDayShiftWeekend ? 'Weekend' : 'Weekday' }} {{ selectedShiftType === 'day' ? 'Day' : 'Night' }} Shift
              </button>
            </div>
          </div>
          
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

const router = useRouter();
const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const settingsStore = useSettingsStore();

// Local state
const selectedSupervisor = ref('');
const selectedShiftType = ref(null); // New ref for tracking selected shift type
const selectedDate = ref(new Date().toISOString().split('T')[0]); // Default to today in YYYY-MM-DD format
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

// Format time (e.g., "9:30 AM")
function formatTime(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
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
</style>
