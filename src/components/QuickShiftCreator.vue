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

<!-- Styles are now handled by the global CSS layers -->