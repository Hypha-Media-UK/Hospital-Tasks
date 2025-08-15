<template>
  <div class="quick-shift-creator">
    <!-- Header -->
    <div class="creator-header">
      <h2 class="creator-title">Create New Shift</h2>
      <p class="creator-subtitle">Quick setup for {{ formatDate(selectedDate) }}</p>
    </div>

    <!-- Main Content -->
    <div class="creator-content">
      <!-- Shift Type Selection (Primary) -->
      <div class="shift-type-section">
        <h3 class="section-title">Select Shift Type</h3>
        <div class="shift-type-grid">
          <button 
            @click="createShift('day')"
            class="shift-type-card day-shift"
            :class="{ 'creating': creating && selectedShiftType === 'day' }"
            :disabled="creating"
            :style="{ 
              backgroundColor: getShiftColor('day'),
              borderColor: getShiftColor('day')
            }"
          >
            <div class="shift-icon">
              <DayShiftIcon size="32" />
            </div>
            <div class="shift-info">
              <div class="shift-name">{{ isDayWeekend ? 'Weekend' : 'Weekday' }} Day Shift</div>
              <div class="shift-time">{{ dayShiftTime }}</div>
              <div class="shift-supervisor" v-if="selectedSupervisor">
                {{ getSupervisorName(selectedSupervisor) }}
              </div>
            </div>
            <div v-if="creating && selectedShiftType === 'day'" class="creating-indicator">
              <div class="spinner"></div>
              <span>Creating...</span>
            </div>
          </button>

          <button 
            @click="createShift('night')"
            class="shift-type-card night-shift"
            :class="{ 'creating': creating && selectedShiftType === 'night' }"
            :disabled="creating"
            :style="{ 
              backgroundColor: getShiftColor('night'),
              borderColor: getShiftColor('night')
            }"
          >
            <div class="shift-icon">
              <NightShiftIcon size="32" />
            </div>
            <div class="shift-info">
              <div class="shift-name">{{ isDayWeekend ? 'Weekend' : 'Weekday' }} Night Shift</div>
              <div class="shift-time">{{ nightShiftTime }}</div>
              <div class="shift-supervisor" v-if="selectedSupervisor">
                {{ getSupervisorName(selectedSupervisor) }}
              </div>
            </div>
            <div v-if="creating && selectedShiftType === 'night'" class="creating-indicator">
              <div class="spinner"></div>
              <span>Creating...</span>
            </div>
          </button>
        </div>
      </div>

      <!-- Quick Options -->
      <div class="quick-options">
        <div class="option-group">
          <label class="option-label">
            <ClockIcon size="16" />
            Date
          </label>
          <div class="date-selector">
            <button 
              @click="setDate('today')"
              class="date-option"
              :class="{ 'active': isToday }"
            >
              Today
            </button>
            <button 
              @click="setDate('tomorrow')"
              class="date-option"
              :class="{ 'active': isTomorrow }"
            >
              Tomorrow
            </button>
            <input 
              type="date" 
              v-model="selectedDate"
              class="date-input"
              :min="today"
            />
          </div>
        </div>

        <div class="option-group">
          <label class="option-label">
            <UserIcon size="16" />
            Supervisor
          </label>
          <div class="supervisor-selector">
            <select v-model="selectedSupervisor" class="supervisor-select">
              <option value="">Auto-assign</option>
              <option 
                v-for="supervisor in supervisors" 
                :key="supervisor.id" 
                :value="supervisor.id"
              >
                {{ supervisor.first_name }} {{ supervisor.last_name }}
              </option>
            </select>
          </div>
        </div>
      </div>

      <!-- Advanced Options (Collapsible) -->
      <div class="advanced-options">
        <button 
          @click="showAdvanced = !showAdvanced"
          class="advanced-toggle"
        >
          <ChevronIcon 
            size="16" 
            :class="{ 'rotated': showAdvanced }"
          />
          Advanced Options
        </button>
        
        <Transition name="slide-down">
          <div v-if="showAdvanced" class="advanced-content">
            <div class="advanced-grid">
              <div class="advanced-option">
                <label>Custom Start Time</label>
                <input 
                  type="time" 
                  v-model="customStartTime"
                  class="time-input"
                />
              </div>
              <div class="advanced-option">
                <label>Copy from Previous Shift</label>
                <select v-model="templateShiftId" class="template-select">
                  <option value="">None</option>
                  <option 
                    v-for="shift in recentShifts" 
                    :key="shift.id" 
                    :value="shift.id"
                  >
                    {{ formatShiftTemplate(shift) }}
                  </option>
                </select>
              </div>
            </div>
          </div>
        </Transition>
      </div>

      <!-- Conflict Warning -->
      <div v-if="conflictWarning" class="conflict-warning">
        <ExclamationIcon size="20" />
        <div class="warning-content">
          <div class="warning-title">Scheduling Conflict</div>
          <div class="warning-message">{{ conflictWarning }}</div>
        </div>
      </div>

      <!-- Error Message -->
      <div v-if="error" class="error-message">
        <ExclamationIcon size="20" />
        {{ error }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useSettingsStore } from '../stores/settingsStore';
import DayShiftIcon from './icons/DayShiftIcon.vue';
import NightShiftIcon from './icons/NightShiftIcon.vue';
import ClockIcon from './icons/ClockIcon.vue';
import ExclamationIcon from './icons/ExclamationIcon.vue';

// Create UserIcon and ChevronIcon components inline for now
const UserIcon = { 
  props: ['size'], 
  template: `
    <svg :width="size" :height="size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M20 21V19C20 17.9391 19.5786 16.9217 18.8284 16.1716C18.0783 15.4214 17.0609 15 16 15H8C6.93913 15 5.92172 15.4214 5.17157 16.1716C4.42143 16.9217 4 17.9391 4 19V21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M12 11C14.2091 11 16 9.20914 16 7C16 4.79086 14.2091 3 12 3C9.79086 3 8 4.79086 8 7C8 9.20914 9.79086 11 12 11Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
  `
};

const ChevronIcon = { 
  props: ['size'], 
  template: `
    <svg :width="size" :height="size" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M6 9L12 15L18 9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
  `
};

const router = useRouter();
const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const settingsStore = useSettingsStore();

// State
const selectedDate = ref(new Date().toISOString().split('T')[0]);
const selectedSupervisor = ref('');
const selectedShiftType = ref(null);
const creating = ref(false);
const error = ref('');
const showAdvanced = ref(false);
const customStartTime = ref('');
const templateShiftId = ref('');
const conflictWarning = ref('');

// Computed
const today = computed(() => new Date().toISOString().split('T')[0]);

const isToday = computed(() => selectedDate.value === today.value);

const isTomorrow = computed(() => {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  return selectedDate.value === tomorrow.toISOString().split('T')[0];
});

const isDayWeekend = computed(() => {
  if (!selectedDate.value) return false;
  const date = new Date(selectedDate.value);
  return isWeekend(date);
});

const dayShiftTime = computed(() => {
  const shiftType = isDayWeekend.value ? 'weekend_day' : 'week_day';
  const defaults = settingsStore.shiftDefaultsByType[shiftType];
  if (!defaults) return '08:00 - 20:00'; // fallback
  return `${settingsStore.formatTime(defaults.start_time)} - ${settingsStore.formatTime(defaults.end_time)}`;
});

const nightShiftTime = computed(() => {
  const shiftType = isDayWeekend.value ? 'weekend_night' : 'week_night';
  const defaults = settingsStore.shiftDefaultsByType[shiftType];
  if (!defaults) return '20:00 - 08:00'; // fallback
  return `${settingsStore.formatTime(defaults.start_time)} - ${settingsStore.formatTime(defaults.end_time)}`;
});

const supervisors = computed(() => staffStore.sortedSupervisors);

const recentShifts = computed(() => {
  // Get recent shifts for template options
  return shiftsStore.activeShifts.slice(0, 5);
});

// Methods
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6;
}

function setDate(option) {
  const date = new Date();
  if (option === 'tomorrow') {
    date.setDate(date.getDate() + 1);
  }
  selectedDate.value = date.toISOString().split('T')[0];
}

function getShiftColor(shiftType) {
  const fullShiftType = isDayWeekend.value 
    ? `weekend_${shiftType}` 
    : `week_${shiftType}`;
  return settingsStore.shiftDefaultsByType[fullShiftType]?.color || '#4285F4';
}

function getSupervisorName(supervisorId) {
  const supervisor = supervisors.value.find(s => s.id === supervisorId);
  return supervisor ? `${supervisor.first_name} ${supervisor.last_name}` : '';
}

function formatDate(dateString) {
  const date = new Date(dateString);
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  if (dateString === today.toISOString().split('T')[0]) {
    return 'Today';
  } else if (dateString === tomorrow.toISOString().split('T')[0]) {
    return 'Tomorrow';
  } else {
    return date.toLocaleDateString('en-US', { 
      weekday: 'long', 
      month: 'short', 
      day: 'numeric' 
    });
  }
}

function formatShiftTemplate(shift) {
  const date = new Date(shift.start_time);
  const shiftTypeName = shift.shift_type.includes('day') ? 'Day' : 'Night';
  return `${shiftTypeName} - ${date.toLocaleDateString()}`;
}

async function createShift(shiftType) {
  if (creating.value) return;
  
  selectedShiftType.value = shiftType;
  creating.value = true;
  error.value = '';
  conflictWarning.value = '';
  
  try {
    // Check for conflicts
    await checkForConflicts(shiftType);
    
    // Determine supervisor
    let supervisorId = selectedSupervisor.value;
    if (!supervisorId && supervisors.value.length > 0) {
      // Auto-assign first available supervisor
      supervisorId = supervisors.value[0].id;
    }
    
    if (!supervisorId) {
      throw new Error('No supervisor available');
    }
    
    // Determine full shift type
    const fullShiftType = isDayWeekend.value 
      ? `weekend_${shiftType}` 
      : `week_${shiftType}`;
    
    // Create shift date
    const shiftDate = new Date(selectedDate.value);
    
    // Create the shift
    const newShift = await shiftsStore.createShift(
      supervisorId,
      fullShiftType,
      shiftDate.toISOString()
    );
    
    if (newShift) {
      // If template shift selected, duplicate its setup
      if (templateShiftId.value) {
        await shiftsStore.duplicateShift(templateShiftId.value, selectedDate.value);
      }
      
      // Navigate to the new shift
      router.push(`/shift/${newShift.id}`);
    } else {
      throw new Error('Failed to create shift');
    }
  } catch (err) {
    error.value = err.message || 'Failed to create shift';
  } finally {
    creating.value = false;
    selectedShiftType.value = null;
  }
}

async function checkForConflicts(shiftType) {
  // Check if there's already a shift of this type on this date
  const existingShift = shiftsStore.activeShifts.find(shift => {
    const shiftDate = new Date(shift.start_time).toISOString().split('T')[0];
    const shiftTypeMatch = shift.shift_type.includes(shiftType);
    return shiftDate === selectedDate.value && shiftTypeMatch;
  });
  
  if (existingShift) {
    conflictWarning.value = `A ${shiftType} shift already exists for this date`;
  }
}

// Watch for date changes to check conflicts
watch([selectedDate, selectedSupervisor], () => {
  conflictWarning.value = '';
});

// Initialize
onMounted(async () => {
  await Promise.all([
    staffStore.fetchSupervisors(),
    shiftsStore.fetchActiveShifts(),
    settingsStore.loadSettings()
  ]);
  
  // Auto-select most recently used supervisor
  if (supervisors.value.length > 0 && !selectedSupervisor.value) {
    selectedSupervisor.value = supervisors.value[0].id;
  }
});
</script>

<style lang="scss" scoped>
.quick-shift-creator {
  max-width: 600px;
  margin: 0 auto;
  padding: 1.5rem;
}

.creator-header {
  text-align: center;
  margin-bottom: 2rem;
  
  .creator-title {
    font-size: 1.5rem;
    font-weight: 600;
    color: #333;
    margin-bottom: 0.5rem;
  }
  
  .creator-subtitle {
    color: #666;
    font-size: 0.95rem;
  }
}

.creator-content {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.shift-type-section {
  .section-title {
    font-size: 1.1rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: #333;
  }
}

.shift-type-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
  
  @media (min-width: 640px) {
    grid-template-columns: 1fr 1fr;
  }
}

.shift-type-card {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1.5rem;
  border: 2px solid;
  border-radius: 12px;
  background: white;
  color: white;
  cursor: pointer;
  transition: all 0.3s ease;
  min-height: 140px;
  
  &:hover:not(:disabled) {
    transform: translateY(-4px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
  }
  
  &:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }
  
  &.creating {
    .shift-icon,
    .shift-info {
      opacity: 0.3;
    }
  }
  
  .shift-icon {
    margin-bottom: 0.75rem;
    opacity: 0.9;
  }
  
  .shift-info {
    text-align: center;
    
    .shift-name {
      font-weight: 600;
      font-size: 1rem;
      margin-bottom: 0.25rem;
    }
    
    .shift-time {
      font-size: 0.85rem;
      opacity: 0.9;
      margin-bottom: 0.25rem;
    }
    
    .shift-supervisor {
      font-size: 0.8rem;
      opacity: 0.8;
    }
  }
  
  .creating-indicator {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    color: white;
    
    .spinner {
      width: 24px;
      height: 24px;
      border: 2px solid rgba(255, 255, 255, 0.3);
      border-top: 2px solid white;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    
    span {
      font-size: 0.9rem;
      font-weight: 500;
    }
  }
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.quick-options {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
  
  @media (min-width: 640px) {
    grid-template-columns: 1fr 1fr;
  }
}

.option-group {
  .option-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 500;
    color: #333;
    margin-bottom: 0.75rem;
    font-size: 0.9rem;
  }
}

.date-selector {
  display: flex;
  gap: 0.5rem;
  
  .date-option {
    padding: 0.5rem 1rem;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    background: white;
    color: #666;
    cursor: pointer;
    transition: all 0.2s;
    font-size: 0.9rem;
    
    &:hover {
      border-color: #4285F4;
      color: #4285F4;
    }
    
    &.active {
      background: #4285F4;
      border-color: #4285F4;
      color: white;
    }
  }
  
  .date-input {
    flex: 1;
    padding: 0.5rem;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    font-size: 0.9rem;
    
    &:focus {
      outline: none;
      border-color: #4285F4;
      box-shadow: 0 0 0 3px rgba(66, 133, 244, 0.1);
    }
  }
}

.supervisor-selector {
  .supervisor-select {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    background: white;
    font-size: 0.9rem;
    
    &:focus {
      outline: none;
      border-color: #4285F4;
      box-shadow: 0 0 0 3px rgba(66, 133, 244, 0.1);
    }
  }
}

.advanced-options {
  .advanced-toggle {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background: none;
    border: none;
    color: #666;
    cursor: pointer;
    font-size: 0.9rem;
    padding: 0.5rem 0;
    transition: color 0.2s;
    
    &:hover {
      color: #4285F4;
    }
    
    svg {
      transition: transform 0.2s;
      
      &.rotated {
        transform: rotate(180deg);
      }
    }
  }
}

.slide-down-enter-active,
.slide-down-leave-active {
  transition: all 0.3s ease;
}

.slide-down-enter-from,
.slide-down-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}

.advanced-content {
  margin-top: 1rem;
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 8px;
}

.advanced-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
  
  @media (min-width: 640px) {
    grid-template-columns: 1fr 1fr;
  }
}

.advanced-option {
  label {
    display: block;
    font-size: 0.85rem;
    font-weight: 500;
    color: #333;
    margin-bottom: 0.5rem;
  }
  
  .time-input,
  .template-select {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    font-size: 0.9rem;
    
    &:focus {
      outline: none;
      border-color: #4285F4;
      box-shadow: 0 0 0 3px rgba(66, 133, 244, 0.1);
    }
  }
}

.conflict-warning,
.error-message {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  padding: 1rem;
  border-radius: 8px;
  font-size: 0.9rem;
}

.conflict-warning {
  background: rgba(255, 193, 7, 0.1);
  border: 1px solid rgba(255, 193, 7, 0.3);
  color: #856404;
  
  .warning-content {
    .warning-title {
      font-weight: 600;
      margin-bottom: 0.25rem;
    }
    
    .warning-message {
      font-size: 0.85rem;
    }
  }
}

.error-message {
  background: rgba(220, 53, 69, 0.1);
  border: 1px solid rgba(220, 53, 69, 0.3);
  color: #721c24;
}
</style>
