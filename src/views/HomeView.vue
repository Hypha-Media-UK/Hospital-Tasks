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
          <div class="form-group">
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
          
          <div class="form-actions">
            <button 
              @click="createAutoShift()" 
              class="btn btn-auto-shift"
              :disabled="!selectedSupervisor || creating"
              :style="{ backgroundColor: getShiftColor(detectedShiftType) }"
            >
              Start Shift
            </button>
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
const creating = ref(false);
const error = ref('');
const detectedShiftType = ref('week_day'); // Default value, will be updated
const updateTimer = ref(null);

// Computed properties
const loading = computed(() => shiftsStore.loading.activeShifts || staffStore.loading.supervisors);
const activeShifts = computed(() => shiftsStore.activeShifts);
const dayShifts = computed(() => shiftsStore.activeDayShifts);
const nightShifts = computed(() => shiftsStore.activeNightShifts);
const supervisors = computed(() => staffStore.sortedSupervisors);

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

// Create a shift based on the auto-detected type
function createAutoShift() {
  createShift(detectedShiftType.value);
}

// Create a new shift
async function createShift(shiftType) {
  if (!selectedSupervisor.value) {
    error.value = 'Please select a supervisor';
    return;
  }
  
  creating.value = true;
  error.value = '';
  
  try {
    console.log(`Creating new shift: type=${shiftType}`);
    
    // Use specific shift type directly - no conversion needed
    const newShift = await shiftsStore.createShift(
      selectedSupervisor.value, 
      shiftType
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

.btn-auto-shift {
  padding: 16px 24px;
  border: none;
  border-radius: 6px;
  color: white;
  font-weight: 600;
  font-size: 1.2rem;
  cursor: pointer;
  transition: all 0.2s ease;
  width: 100%;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
  margin: 10px 0;
  
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
