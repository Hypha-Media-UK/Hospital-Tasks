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
            <div class="shift-buttons">
              <button 
                @click="createShift('week_day')" 
                class="btn btn-primary"
                :disabled="!selectedSupervisor || creating"
                :style="{ backgroundColor: settingsStore.shiftDefaults.week_day.color }"
              >
                Start Week Day Shift
              </button>
              
              <button 
                @click="createShift('week_night')" 
                class="btn btn-secondary"
                :disabled="!selectedSupervisor || creating"
                :style="{ backgroundColor: settingsStore.shiftDefaults.week_night.color }"
              >
                Start Week Night Shift
              </button>
            </div>
            
            <div class="shift-buttons">
              <button 
                @click="createShift('weekend_day')" 
                class="btn btn-primary"
                :disabled="!selectedSupervisor || creating"
                :style="{ backgroundColor: '#34A853' }"
              >
                Start Weekend Day Shift
              </button>
              
              <button 
                @click="createShift('weekend_night')" 
                class="btn btn-secondary"
                :disabled="!selectedSupervisor || creating"
                :style="{ backgroundColor: '#EA4335' }"
              >
                Start Weekend Night Shift
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
import { ref, computed, onMounted } from 'vue';
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

// Computed properties
const loading = computed(() => shiftsStore.loading.activeShifts || staffStore.loading.supervisors);
const activeShifts = computed(() => shiftsStore.activeShifts);
const dayShifts = computed(() => shiftsStore.activeDayShifts);
const nightShifts = computed(() => shiftsStore.activeNightShifts);
const supervisors = computed(() => staffStore.sortedSupervisors);

// Load data
onMounted(async () => {
  // Initialize settings (to get shift colors)
  await settingsStore.loadSettings();
  
  // Load supervisors and active shifts in parallel
  await Promise.all([
    staffStore.fetchSupervisors(),
    shiftsStore.fetchActiveShifts()
  ]);
});

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
      return settingsStore.shiftDefaults.week_day.color;
    case 'week_night':
      return settingsStore.shiftDefaults.week_night.color;
    case 'weekend_day':
      return settingsStore.shiftDefaults.weekend_day.color;
    case 'weekend_night':
      return settingsStore.shiftDefaults.weekend_night.color;
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
    
    .shift-buttons {
      display: flex;
      gap: 1rem;
      flex-wrap: wrap;
    }
    
    button {
      padding: 0.5rem 1rem;
      border: none;
      border-radius: 4px;
      color: white;
      font-weight: bold;
      cursor: pointer;
      transition: opacity 0.2s;
      flex: 1;
      min-width: 150px;
      
      &:disabled {
        opacity: 0.6;
        cursor: not-allowed;
      }
      
      &:not(:disabled):hover {
        opacity: 0.9;
      }
    }
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
