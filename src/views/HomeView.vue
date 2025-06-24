<template>
  <div class="view">
    <div class="view__content">
      <!-- Main Tabbed Interface -->
      <div class="card">
        <AnimatedTabs
          v-model="activeTabId"
          :tabs="tabDefinitions"
          @tab-change="handleTabChange"
          class="home-tabs"
        >
          <!-- Active Shifts Tab -->
          <template #active-shifts>
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
              <div class="empty-state__icon">
                <svg width="64" height="64" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M12 8V12L15 15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                  <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/>
                </svg>
              </div>
              <p>No active shifts. Create a new shift to get started.</p>
              <button @click="activeTabId = 'create-shift'" class="btn btn-primary empty-state__action">
                Create Shift
              </button>
            </div>
            
            <div v-else>
              <div class="selection-controls" v-if="activeShifts.length > 0">
                <label class="select-all-container">
                  <span class="checkbox-wrapper">
                    <input 
                      type="checkbox" 
                      :checked="isAllSelected" 
                      @change="toggleSelectAll" 
                    />
                    <span class="custom-checkbox"></span>
                  </span>
                  <span>Select All</span>
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
                      <div class="shift-card__color-bar" :style="{ backgroundColor: getShiftColor(shift.shift_type) }"></div>
                      <div class="shift-card__header">
                        <div class="shift-card__selection">
                          <span class="checkbox-wrapper">
                            <input 
                              type="checkbox" 
                              :checked="isShiftSelected(shift)"
                              @change="toggleShiftSelection(shift, $event)" 
                              @click.stop
                            />
                            <span class="custom-checkbox"></span>
                          </span>
                          <span class="shift-type">
                            <DayShiftIcon v-if="shift.shift_type.includes('day')" size="18" class="shift-icon" />
                            <NightShiftIcon v-else size="18" class="shift-icon" />
                            Day Shift
                          </span>
                        </div>
                        <span class="shift-date">{{ formatDate(shift.start_time) }}</span>
                      </div>
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
                        <div class="detail-row">
                          <ClockIcon size="16" class="detail-icon" />
                          <p class="time">
                            <span class="detail-label">Started:</span> 
                            <span class="detail-value">{{ formatTime(shift.start_time) }}</span>
                          </p>
                        </div>
                        <div class="detail-row">
                          <svg class="detail-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M12 8V12L15 15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                            <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/>
                          </svg>
                          <p class="duration">
                            <span class="detail-label">Duration:</span> 
                            <span class="detail-value">{{ calculateDuration(shift.start_time) }}</span>
                          </p>
                        </div>
                        <div class="shift-card__footer">
                          <button class="btn-view-shift">View Details</button>
                        </div>
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
                      <div class="shift-card__color-bar" :style="{ backgroundColor: getShiftColor(shift.shift_type) }"></div>
                      <div class="shift-card__header">
                        <div class="shift-card__selection">
                          <span class="checkbox-wrapper">
                            <input 
                              type="checkbox" 
                              :checked="isShiftSelected(shift)"
                              @change="toggleShiftSelection(shift, $event)" 
                              @click.stop
                            />
                            <span class="custom-checkbox"></span>
                          </span>
                          <span class="shift-type">
                            <DayShiftIcon v-if="shift.shift_type.includes('day')" size="18" class="shift-icon" />
                            <NightShiftIcon v-else size="18" class="shift-icon" />
                            Night Shift
                          </span>
                        </div>
                        <span class="shift-date">{{ formatDate(shift.start_time) }}</span>
                      </div>
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
                        <div class="detail-row">
                          <ClockIcon size="16" class="detail-icon" />
                          <p class="time">
                            <span class="detail-label">Started:</span> 
                            <span class="detail-value">{{ formatTime(shift.start_time) }}</span>
                          </p>
                        </div>
                        <div class="detail-row">
                          <svg class="detail-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M12 8V12L15 15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                            <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/>
                          </svg>
                          <p class="duration">
                            <span class="detail-label">Duration:</span> 
                            <span class="detail-value">{{ calculateDuration(shift.start_time) }}</span>
                          </p>
                        </div>
                        <div class="shift-card__footer">
                          <button class="btn-view-shift">View Details</button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </template>
          
          <!-- Create New Shift Tab -->
          <template #create-shift>
            <h2 class="card__title">Create New Shift</h2>
            
            <div class="create-shift-form">
              <!-- Progress steps indicator -->
              <div class="progress-steps">
                <div class="step" :class="{ 'active': formStep === 1, 'completed': formStep > 1 }">
                  <div class="step-number">1</div>
                  <div class="step-label">Select Date</div>
                </div>
                <div class="step-connector"></div>
                <div class="step" :class="{ 'active': formStep === 2, 'completed': formStep > 2 }">
                  <div class="step-number">2</div>
                  <div class="step-label">Choose Supervisor</div>
                </div>
                <div class="step-connector"></div>
                <div class="step" :class="{ 'active': formStep === 3, 'completed': formStep > 3 }">
                  <div class="step-number">3</div>
                  <div class="step-label">Create Shift</div>
                </div>
              </div>
              
              <!-- Form contents with steps -->
              <div class="form-step-container">
                <!-- Step 1: Date Selection -->
                <div v-if="formStep === 1" class="form-step date-step" key="step-1">
                  <div class="step-header">
                    <h3 class="step-title">Select Shift Date</h3>
                    <p class="step-description">Choose the date for the new shift</p>
                  </div>
                  
                  <div class="form-card">
                    <div class="date-selection-area">
                      <div class="calendar-wrapper">
                        <label for="shiftDate" class="form-label">
                          <ClockIcon size="18" class="form-icon" />
                          Shift Date
                        </label>
                        <div class="input-wrapper date-input">
                          <input 
                            type="date" 
                            id="shiftDate" 
                            v-model="selectedDate" 
                            class="form-control"
                            :min="today"
                            @change="checkDateSelection"
                          >
                        </div>
                      </div>
                      
                      <div v-if="selectedDate" class="date-preview">
                        <div class="date-preview-header">
                          <span class="date-weekday">{{ getWeekdayName(selectedDate) }}</span>
                          <span class="date-weekend-badge" v-if="isDayShiftWeekend">Weekend</span>
                        </div>
                        <div class="date-preview-calendar">
                          <div class="calendar-month">{{ formatMonth(selectedDate) }}</div>
                          <div class="calendar-day">{{ formatDayNumber(selectedDate) }}</div>
                          <div class="calendar-year">{{ formatYear(selectedDate) }}</div>
                        </div>
                        <div class="shift-hours">
                          <div class="shift-time-block">
                            <div class="shift-label">Day Shift</div>
                            <div class="shift-time">{{ settingsStore.shiftDefaults.week_day.startTime }} - {{ settingsStore.shiftDefaults.week_day.endTime }}</div>
                          </div>
                          <div class="shift-time-block">
                            <div class="shift-label">Night Shift</div>
                            <div class="shift-time">{{ settingsStore.shiftDefaults.week_night.startTime }} - {{ settingsStore.shiftDefaults.week_night.endTime }}</div>
                          </div>
                        </div>
                      </div>
                    </div>
                    
                    <div class="form-actions">
                      <button 
                        @click="formStep = 2" 
                        class="btn btn-next"
                        :disabled="!selectedDate"
                      >
                        Next: Choose Supervisor
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M9 18L15 12L9 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>
                
                <!-- Step 2: Supervisor Selection -->
                <div v-if="formStep === 2" class="form-step supervisor-step" key="step-2">
                  <div class="step-header">
                    <h3 class="step-title">Choose Supervisor</h3>
                    <p class="step-description">Select who will supervise this shift</p>
                  </div>
                  
                  <div class="form-card">
                    <div class="supervisor-selection-area">
                      <label for="supervisor" class="form-label">
                        <svg class="form-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M20 21V19C20 17.9391 19.5786 16.9217 18.8284 16.1716C18.0783 15.4214 17.0609 15 16 15H8C6.93913 15 5.92172 15.4214 5.17157 16.1716C4.42143 16.9217 4 17.9391 4 19V21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                          <path d="M12 11C14.2091 11 16 9.20914 16 7C16 4.79086 14.2091 3 12 3C9.79086 3 8 4.79086 8 7C8 9.20914 9.79086 11 12 11Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        Supervisor
                      </label>
                      
                      <div class="select-wrapper">
                        <input 
                          type="text" 
                          class="form-control supervisor-filter" 
                          placeholder="Type to filter supervisors..."
                          v-model="supervisorFilter"
                        >
                        <div class="supervisor-list">
                          <div 
                            v-for="supervisor in filteredSupervisors" 
                            :key="supervisor.id"
                            class="supervisor-item"
                            :class="{ 'selected': selectedSupervisor === supervisor.id }"
                            @click="selectSupervisor(supervisor.id)"
                          >
                            <div class="supervisor-avatar">
                              {{ getInitials(supervisor.first_name, supervisor.last_name) }}
                            </div>
                            <div class="supervisor-info">
                              <div class="supervisor-name">{{ supervisor.first_name }} {{ supervisor.last_name }}</div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                    
                    <div v-if="selectedSupervisor" class="selected-supervisor-preview">
                      <div class="preview-label">Selected Supervisor:</div>
                      <div class="selected-supervisor-card">
                        <div class="supervisor-avatar large">
                          {{ getSelectedSupervisorInitials() }}
                        </div>
                        <div class="supervisor-details">
                          <div class="supervisor-name">{{ getSelectedSupervisorName() }}</div>
                        </div>
                      </div>
                    </div>
                    
                    <div class="form-actions">
                      <button @click="formStep = 1" class="btn btn-back">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M15 18L9 12L15 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        Back
                      </button>
                      <button 
                        @click="formStep = 3" 
                        class="btn btn-next"
                        :disabled="!selectedSupervisor"
                      >
                        Next: Create Shift
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M9 18L15 12L9 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>
                
                <!-- Step 3: Shift Type Selection -->
                <div v-if="formStep === 3" class="form-step shift-type-step" key="step-3">
                  <div class="step-header">
                    <h3 class="step-title">Create Shift</h3>
                    <p class="step-description">Select the type of shift you want to create</p>
                  </div>
                  
                  <div class="form-card">
                    <div class="form-summary">
                      <div class="summary-title">Shift Summary</div>
                      <div class="summary-details">
                        <div class="summary-row">
                          <div class="summary-label">Date:</div>
                          <div class="summary-value">
                            {{ formatFullDate(selectedDate) }} 
                            <span class="badge" v-if="isDayShiftWeekend">Weekend</span>
                          </div>
                        </div>
                        <div class="summary-row">
                          <div class="summary-label">Supervisor:</div>
                          <div class="summary-value">{{ getSelectedSupervisorName() }}</div>
                        </div>
                      </div>
                    </div>
                    
                    <div class="shift-types">
                      <div class="shift-type-container">
                        <div class="shift-timeline">
                          <div class="timeline-hours">
                            <div v-for="hour in 24" :key="hour" class="timeline-hour">
                              {{ (hour - 1) % 12 + 1 }}{{ hour <= 12 ? 'am' : 'pm' }}
                            </div>
                          </div>
                          <div class="timeline-periods">
                            <div class="timeline-day" 
                                :style="{ left: getTimePosition(settingsStore.shiftDefaults.week_day.startTime) + '%', 
                                         width: getTimeWidth(settingsStore.shiftDefaults.week_day.startTime, settingsStore.shiftDefaults.week_day.endTime) + '%' }">
                              Day Shift
                            </div>
                            <div class="timeline-night"
                                :style="{ left: getTimePosition(settingsStore.shiftDefaults.week_night.startTime) + '%', 
                                         width: getTimeWidth(settingsStore.shiftDefaults.week_night.startTime, settingsStore.shiftDefaults.week_night.endTime) + '%' }">
                              Night Shift
                            </div>
                          </div>
                        </div>
                      </div>
                      
                      <div class="shift-type-buttons">
                        <button 
                          @click="createDayShift()" 
                          class="btn btn-shift-type day-shift"
                          :disabled="creating"
                          :style="{ backgroundColor: getShiftColor(isDayShiftWeekend ? 'weekend_day' : 'week_day') }"
                        >
                          <DayShiftIcon size="48" class="shift-type-icon" />
                          <div class="btn-content">
                            <span v-if="!creating" class="btn-label">
                              Create {{ isDayShiftWeekend ? 'Weekend' : 'Weekday' }} Day Shift
                            </span>
                            <span v-else class="loading-indicator">
                              <span class="loading-spinner"></span>
                              Creating...
                            </span>
                            <span class="shift-hours">{{ settingsStore.shiftDefaults.week_day.startTime }} - {{ settingsStore.shiftDefaults.week_day.endTime }}</span>
                          </div>
                        </button>
                        
                        <button 
                          @click="createNightShift()" 
                          class="btn btn-shift-type night-shift"
                          :disabled="creating"
                          :style="{ backgroundColor: getShiftColor(isDayShiftWeekend ? 'weekend_night' : 'week_night') }"
                        >
                          <NightShiftIcon size="48" class="shift-type-icon" />
                          <div class="btn-content">
                            <span v-if="!creating" class="btn-label">
                              Create {{ isDayShiftWeekend ? 'Weekend' : 'Weekday' }} Night Shift
                            </span>
                            <span v-else class="loading-indicator">
                              <span class="loading-spinner"></span>
                              Creating...
                            </span>
                            <span class="shift-hours">{{ settingsStore.shiftDefaults.week_night.startTime }} - {{ settingsStore.shiftDefaults.week_night.endTime }}</span>
                          </div>
                        </button>
                      </div>
                    </div>
                    
                    <div class="form-actions">
                      <button @click="formStep = 2" class="btn btn-back">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M15 18L9 12L15 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                        Back
                      </button>
                    </div>
                  </div>
                </div>
              </div>
              
              <div v-if="error" class="error-message">
                {{ error }}
              </div>
            </div>
          </template>
        </AnimatedTabs>
      </div>
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
    
    console.log(`Exported ${selectedShifts.value.length} shifts to ${filename}`);
  } catch (error) {
    console.error('Error exporting shifts:', error);
    alert('Failed to export shifts. See console for details.');
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

<style lang="scss" scoped>
.mb-4 {
  margin-bottom: 1rem;
}

.card__header {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-bottom: 1rem;
  
  @media screen and (min-width: 576px) {
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
  }
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
  grid-template-columns: 1fr;
  gap: 1rem;
  
  @media screen and (min-width: 576px) {
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  }
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
    display: flex;
    flex-direction: column; // Stack buttons by default on mobile
    gap: 1rem;
    max-width: 600px;
    margin: 0 auto;
    
    @media screen and (min-width: 700px) {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    }
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

/* Empty State Styling */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem 1rem;
  text-align: center;
  color: #666;
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: 8px;
  
  &__icon {
    color: #9e9e9e;
    margin-bottom: 1rem;
  }
  
  p {
    margin-bottom: 1.5rem;
    font-size: 1.1rem;
  }
  
  &__action {
    padding: 0.75rem 1.5rem;
    background-color: #4285F4;
    color: white;
    border: none;
    border-radius: 6px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    
    &:hover {
      background-color: darken(#4285F4, 10%);
      transform: translateY(-2px);
      box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
    }
  }
}

/* Custom Checkbox Styling */
.checkbox-wrapper {
  position: relative;
  display: inline-block;
  width: 20px;
  height: 20px;
  margin-right: 10px;
  
  input[type="checkbox"] {
    position: absolute;
    opacity: 0;
    cursor: pointer;
    height: 0;
    width: 0;
    
    &:checked ~ .custom-checkbox {
      background-color: #4285F4;
      border-color: #4285F4;
      
      &:after {
        display: block;
      }
    }
  }
  
  .custom-checkbox {
    position: absolute;
    top: 0;
    left: 0;
    height: 20px;
    width: 20px;
    background-color: white;
    border: 2px solid #ccc;
    border-radius: 4px;
    transition: all 0.2s;
    
    &:after {
      content: "";
      position: absolute;
      display: none;
      left: 6px;
      top: 2px;
      width: 5px;
      height: 10px;
      border: solid white;
      border-width: 0 2px 2px 0;
      transform: rotate(45deg);
    }
  }
}

.select-all-container {
  display: flex;
  align-items: center;
  background-color: rgba(0, 0, 0, 0.03);
  padding: 8px 12px;
  border-radius: 6px;
  cursor: pointer;
  user-select: none;
  max-width: fit-content;
  
  &:hover .custom-checkbox {
    border-color: #4285F4;
  }
}

/* Enhanced Shift Card Styling */
.shift-card {
  position: relative;
  border: 1px solid #e0e0e0;
  border-radius: 12px;
  background-color: white;
  overflow: hidden;
  transition: all 0.3s ease;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  
  &__color-bar {
    position: absolute;
    top: 0;
    left: 0;
    width: 6px;
    height: 100%;
    background-color: currentColor;
  }
  
  &__header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1rem 0.5rem 1.5rem;
    border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  }
  
  &__selection {
    display: flex;
    align-items: center;
    
    .shift-type {
      display: flex;
      align-items: center;
      font-weight: 600;
      font-size: 0.95rem;
      
      .shift-icon {
        margin-right: 6px;
        color: #4285F4;
      }
    }
  }
  
  &__body {
    padding: 1rem 1rem 1rem 1.5rem;
  }
  
  .detail-row {
    display: flex;
    align-items: flex-start;
    margin-bottom: 0.75rem;
    
    .detail-icon {
      flex-shrink: 0;
      margin-right: 0.5rem;
      margin-top: 3px;
      color: #666;
    }
    
    p {
      margin: 0;
      font-size: 0.9rem;
      
      .detail-label {
        font-weight: 600;
        color: #333;
      }
      
      .detail-value {
        color: #666;
      }
    }
  }
  
  &__footer {
    margin-top: 1rem;
    padding-top: 0.75rem;
    border-top: 1px solid rgba(0, 0, 0, 0.06);
    text-align: right;
    
    .btn-view-shift {
      background-color: rgba(66, 133, 244, 0.1);
      color: #4285F4;
      border: none;
      padding: 6px 12px;
      border-radius: 4px;
      font-size: 0.85rem;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s;
      
      &:hover {
        background-color: rgba(66, 133, 244, 0.2);
      }
    }
  }
  
  .shift-date {
    font-size: 0.85rem;
    color: #666;
    font-weight: 500;
  }
  
  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.1);
  }
}

/* Enhanced Create Shift Form Styling */
.create-shift-form {
  max-width: 900px;
  margin: 0 auto;
}

/* Progress Steps Styling */
.progress-steps {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  padding: 0 2rem;
  position: relative;
  
  &::after {
    content: '';
    position: absolute;
    top: 18px;
    left: 10%;
    right: 10%;
    height: 2px;
    background-color: #e0e0e0;
    z-index: 1;
  }
  
  .step {
    display: flex;
    flex-direction: column;
    align-items: center;
    position: relative;
    z-index: 2;
    
    .step-number {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background-color: #f5f5f5;
      border: 2px solid #e0e0e0;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #666;
      font-weight: 600;
      margin-bottom: 8px;
      transition: all 0.3s ease;
    }
    
    .step-label {
      font-size: 0.85rem;
      color: #666;
      font-weight: 500;
      text-align: center;
    }
    
    &.active {
      .step-number {
        background-color: #4285F4;
        border-color: #4285F4;
        color: white;
        box-shadow: 0 0 0 4px rgba(66, 133, 244, 0.2);
      }
      
      .step-label {
        color: #4285F4;
        font-weight: 600;
      }
    }
    
    &.completed {
      .step-number {
        background-color: #34A853;
        border-color: #34A853;
        color: white;
      }
      
      .step-label {
        color: #34A853;
      }
    }
  }
  
  .step-connector {
    flex: 1;
    height: 2px;
    z-index: 0;
  }
}

/* Form Step Container */
.form-step-container {
  position: relative;
  min-height: 400px;
}

.form-step {
  animation: fadeIn 0.3s ease-in-out;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.step-header {
  text-align: center;
  margin-bottom: 1.5rem;
  
  .step-title {
    font-size: 1.4rem;
    color: #333;
    margin-bottom: 0.5rem;
  }
  
  .step-description {
    color: #666;
    font-size: 1rem;
  }
}

/* Form Card Styling */
.form-card {
  background-color: white;
  border-radius: 12px;
  padding: 1.5rem;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
  margin-bottom: 2rem;
}

/* Date Selection Step */
.date-selection-area {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  
  @media (min-width: 768px) {
    flex-direction: row;
  }
  
  .calendar-wrapper {
    flex: 1;
  }
  
  .date-preview {
    flex: 1;
    background-color: #f9f9f9;
    border-radius: 12px;
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    
    &-header {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 1rem;
      
      .date-weekday {
        font-size: 1.2rem;
        font-weight: 600;
        color: #4285F4;
      }
      
      .date-weekend-badge {
        background-color: #FFC107;
        color: rgba(0, 0, 0, 0.7);
        font-size: 0.75rem;
        font-weight: 700;
        padding: 2px 8px;
        border-radius: 12px;
      }
    }
    
    &-calendar {
      display: flex;
      flex-direction: column;
      align-items: center;
      margin-bottom: 1.5rem;
      
      .calendar-month {
        font-size: 1.1rem;
        color: #666;
        margin-bottom: 0.5rem;
      }
      
      .calendar-day {
        font-size: 3.5rem;
        font-weight: 700;
        color: #333;
        line-height: 1;
      }
      
      .calendar-year {
        font-size: 1.1rem;
        color: #666;
        margin-top: 0.5rem;
      }
    }
  }
}

.shift-hours {
  width: 100%;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  padding-top: 1rem;
  
  .shift-time-block {
    margin-bottom: 1rem;
    
    .shift-label {
      font-weight: 600;
      font-size: 0.9rem;
      margin-bottom: 0.25rem;
      color: #333;
    }
    
    .shift-time {
      font-size: 0.95rem;
      color: #666;
    }
  }
}

/* Form Actions */
.form-actions {
  display: flex;
  justify-content: space-between;
  margin-top: 2rem;
  
  .btn {
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    gap: 8px;
    border: none;
    
    &-back {
      background-color: #f5f5f5;
      color: #666;
      
      &:hover {
        background-color: #e0e0e0;
      }
    }
    
    &-next {
      background-color: #4285F4;
      color: white;
      
      &:hover:not(:disabled) {
        background-color: darken(#4285F4, 5%);
        transform: translateY(-2px);
        box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
      }
      
      &:disabled {
        opacity: 0.6;
        cursor: not-allowed;
      }
    }
  }
}

/* Supervisor Selection Step */
.supervisor-selection-area {
  margin-bottom: 2rem;
  
  .form-label {
    display: flex;
    align-items: center;
    font-weight: 600;
    margin-bottom: 0.75rem;
    color: #333;
    
    .form-icon {
      margin-right: 0.5rem;
      color: #4285F4;
    }
  }
}

.supervisor-filter {
  padding: 0.75rem 1rem;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  font-size: 1rem;
  margin-bottom: 1rem;
  width: 100%;
  
  &:focus {
    outline: none;
    border-color: #4285F4;
    box-shadow: 0 0 0 3px rgba(66, 133, 244, 0.2);
  }
}

.supervisor-list {
  max-height: 300px;
  overflow-y: auto;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
}

.supervisor-item {
  display: flex;
  align-items: center;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;
  transition: background-color 0.2s;
  
  &:last-child {
    border-bottom: none;
  }
  
  &:hover {
    background-color: #f9f9f9;
  }
  
  &.selected {
    background-color: rgba(66, 133, 244, 0.1);
  }
  
  .supervisor-avatar {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background-color: #4285F4;
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    margin-right: 1rem;
    font-size: 0.9rem;
    
    &.large {
      width: 48px;
      height: 48px;
      font-size: 1.1rem;
    }
  }
  
  .supervisor-info {
    flex: 1;
  }
  
  .supervisor-name {
    font-weight: 500;
    font-size: 0.95rem;
  }
}

.selected-supervisor-preview {
  background-color: #f9f9f9;
  padding: 1rem;
  border-radius: 8px;
  margin-bottom: 1.5rem;
  
  .preview-label {
    color: #666;
    font-size: 0.85rem;
    margin-bottom: 0.5rem;
  }
  
  .selected-supervisor-card {
    display: flex;
    align-items: center;
  }
  
  .supervisor-details {
    margin-left: 1rem;
    
    .supervisor-name {
      font-weight: 600;
      font-size: 1.1rem;
      color: #333;
    }
  }
}

/* Shift Type Selection Step */
.form-summary {
  background-color: #f9f9f9;
  padding: 1.25rem;
  border-radius: 8px;
  margin-bottom: 2rem;
  
  .summary-title {
    font-weight: 600;
    font-size: 1.1rem;
    margin-bottom: 1rem;
    color: #333;
  }
  
  .summary-details {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  
  .summary-row {
    display: flex;
    
    .summary-label {
      width: 100px;
      font-weight: 500;
      color: #666;
    }
    
    .summary-value {
      flex: 1;
      color: #333;
      
      .badge {
        display: inline-block;
        background-color: #FFC107;
        color: rgba(0, 0, 0, 0.7);
        font-size: 0.75rem;
        font-weight: 700;
        padding: 2px 8px;
        border-radius: 12px;
        margin-left: 8px;
      }
    }
  }
}

.shift-timeline {
  position: relative;
  height: 100px;
  background-color: #f9f9f9;
  border-radius: 8px;
  padding: 1rem;
  margin-bottom: 2rem;
  overflow: hidden;
  
  .timeline-hours {
    display: flex;
    justify-content: space-between;
    padding: 0 1rem;
    position: relative;
    height: 20px;
    
    .timeline-hour {
      font-size: 0.75rem;
      color: #666;
      position: relative;
    }
  }
  
  .timeline-periods {
    position: relative;
    height: 50px;
    margin-top: 10px;
    
    .timeline-day, .timeline-night {
      position: absolute;
      height: 30px;
      top: 10px;
      border-radius: 6px;
      padding: 5px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 0.85rem;
      font-weight: 500;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    
    .timeline-day {
      background-color: #4285F4;
    }
    
    .timeline-night {
      background-color: #673AB7;
    }
  }
}

.shift-type-buttons {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
  
  @media (min-width: 768px) {
    grid-template-columns: 1fr 1fr;
  }
  
  .btn-shift-type {
    display: flex;
    align-items: center;
    padding: 1.5rem;
    border-radius: 12px;
    color: white;
    border: none;
    cursor: pointer;
    transition: all 0.3s ease;
    
    .shift-type-icon {
      margin-right: 1.5rem;
    }
    
    .btn-content {
      text-align: left;
      
      .btn-label {
        font-size: 1.2rem;
        font-weight: 600;
        margin-bottom: 0.5rem;
        line-height: 1.4;
      }
      
      .shift-hours {
        font-size: 0.9rem;
        opacity: 0.8;
        border-top: none;
        padding-top: 0;
      }
    }
    
    &:hover:not(:disabled) {
      transform: translateY(-4px);
      box-shadow: 0 8px 16px rgba(0, 0, 0, 0.15);
    }
    
    &:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
  }
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
  padding: 2rem 0;
  text-align: center;
  color: #666;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Tabs styling */
.home-tabs {
  margin-bottom: 1.5rem;
  
  :deep(.tabs-header) {
    display: flex;
    border-bottom: 1px solid #e0e0e0;
    margin-bottom: 1.5rem;
  }
  
  :deep(.tab-button) {
    padding: 0.75rem 1.25rem;
    background: none;
    border: none;
    cursor: pointer;
    font-weight: 500;
    color: #666;
    position: relative;
    transition: color 0.2s;
    
    &.active {
      color: #4285F4;
      font-weight: 600;
    }
    
    &:hover:not(.active) {
      background-color: rgba(0, 0, 0, 0.03);
    }
  }
  
  :deep(.active-indicator) {
    position: absolute;
    bottom: -1px;
    height: 2px;
    background-color: #4285F4;
    transition: all 0.3s ease;
  }
}

.btn-primary {
  background-color: #4285F4;
  color: white;
  border: none;
  border-radius: 6px;
  padding: 0.75rem 1.5rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  
  &:hover {
    background-color: darken(#4285F4, 10%);
  }
}
</style>
