<template>
  <div class="view">
    <div class="view__content">
      <div class="card">
        <h2 class="card__title">Archived Shifts</h2>
        
        <div v-if="loading" class="loading-indicator">
          <p>Loading archived shifts...</p>
        </div>
        
        <div v-else-if="archivedShifts.length === 0" class="empty-state">
          <p>No archived shifts found.</p>
        </div>
        
        <div v-else>
          <!-- Filter Controls -->
          <div class="filter-controls">
            <div class="search-box">
              <input 
                type="text" 
                v-model="searchQuery" 
                placeholder="Search by supervisor name..." 
                class="search-input"
              />
            </div>
            
            <div class="filter-group">
              <label>
                <input 
                  type="radio" 
                  v-model="typeFilter" 
                  value="all" 
                  name="type-filter"
                /> All
              </label>
              <label>
                <input 
                  type="radio" 
                  v-model="typeFilter" 
                  value="weekday" 
                  name="type-filter"
                /> Weekday Shifts
              </label>
              <label>
                <input 
                  type="radio" 
                  v-model="typeFilter" 
                  value="weekend" 
                  name="type-filter"
                /> Weekend Shifts
              </label>
              <label>
                <input 
                  type="radio" 
                  v-model="typeFilter" 
                  value="day" 
                  name="type-filter"
                /> Day Shifts
              </label>
              <label>
                <input 
                  type="radio" 
                  v-model="typeFilter" 
                  value="night" 
                  name="type-filter"
                /> Night Shifts
              </label>
            </div>
          </div>
          
          <!-- Shifts Table -->
          <div class="shifts-table-container">
            <table class="shifts-table">
              <thead>
                <tr>
                  <th @click="changeSortField('start_time')">
                    Date
                    <span v-if="sortField === 'start_time'" class="sort-indicator">
                      {{ sortDirection === 'asc' ? '▲' : '▼' }}
                    </span>
                  </th>
                  <th @click="changeSortField('supervisor')">
                    Supervisor
                    <span v-if="sortField === 'supervisor'" class="sort-indicator">
                      {{ sortDirection === 'asc' ? '▲' : '▼' }}
                    </span>
                  </th>
                  <th @click="changeSortField('task_count')">
                    Total Tasks
                    <span v-if="sortField === 'task_count'" class="sort-indicator">
                      {{ sortDirection === 'asc' ? '▲' : '▼' }}
                    </span>
                  </th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr 
                  v-for="shift in filteredAndSortedShifts" 
                  :key="shift.id"
                  :class="{ 
                    'day-shift': shift.shift_type.includes('day'), 
                    'night-shift': shift.shift_type.includes('night') 
                  }"
                >
                  <td>{{ formatDate(shift.start_time) }}</td>
                  <td>
                    {{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}
                  </td>
                  <td>{{ getTaskCount(shift.id) }}</td>
                  <td>
                    <div class="action-buttons">
                      <button @click="viewShift(shift.id)" class="btn btn-primary btn-small">
                        View
                      </button>
                      
                      <button 
                        v-if="!confirmingDelete[shift.id]" 
                        @click="confirmDelete(shift.id)" 
                        class="btn btn-danger btn-small"
                        :disabled="isDeleting[shift.id]"
                      >
                        Delete
                      </button>
                      
                      <button 
                        v-else
                        @click="deleteShift(shift.id)" 
                        class="btn btn-danger btn-small confirm-delete"
                        :disabled="isDeleting[shift.id]"
                      >
                        {{ isDeleting[shift.id] ? 'Deleting...' : 'Sure?' }}
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useSettingsStore } from '../stores/settingsStore';

const router = useRouter();
const shiftsStore = useShiftsStore();
const settingsStore = useSettingsStore();

// Local state
const loading = ref(true);
const searchQuery = ref('');
const typeFilter = ref('all');
const sortField = ref('end_time');
const sortDirection = ref('desc');
const confirmingDelete = ref({}); // Object to track shifts in delete confirmation state
const isDeleting = ref({}); // Object to track shifts being deleted

// Computed properties
const archivedShifts = computed(() => shiftsStore.archivedShifts);

const filteredAndSortedShifts = computed(() => {
  let shifts = [...archivedShifts.value];
  
  // Apply type filter
  if (typeFilter.value !== 'all') {
    if (typeFilter.value === 'weekday') {
      shifts = shifts.filter(shift => shift.shift_type.includes('week_'));
    } else if (typeFilter.value === 'weekend') {
      shifts = shifts.filter(shift => shift.shift_type.includes('weekend_'));
    } else if (typeFilter.value === 'day') {
      shifts = shifts.filter(shift => shift.shift_type.includes('day'));
    } else if (typeFilter.value === 'night') {
      shifts = shifts.filter(shift => shift.shift_type.includes('night'));
    }
  }
  
  // Apply search filter
  if (searchQuery.value.trim()) {
    const query = searchQuery.value.toLowerCase();
    shifts = shifts.filter(shift => {
      if (!shift.supervisor) return false;
      
      const supervisorName = `${shift.supervisor.first_name} ${shift.supervisor.last_name}`.toLowerCase();
      return supervisorName.includes(query);
    });
  }
  
  // Apply sorting
  shifts.sort((a, b) => {
    let valueA, valueB;
    
    if (sortField.value === 'supervisor') {
      // Handle supervisor sorting
      valueA = a.supervisor ? `${a.supervisor.first_name} ${a.supervisor.last_name}` : '';
      valueB = b.supervisor ? `${b.supervisor.first_name} ${b.supervisor.last_name}` : '';
      return sortDirection.value === 'asc' 
        ? valueA.localeCompare(valueB)
        : valueB.localeCompare(valueA);
    } else if (sortField.value === 'task_count') {
      // Handle task count sorting
      valueA = shiftsStore.archivedShiftTaskCounts[a.id] || 0;
      valueB = shiftsStore.archivedShiftTaskCounts[b.id] || 0;
      
      if (valueA === valueB) return 0;
      
      if (sortDirection.value === 'asc') {
        return valueA < valueB ? -1 : 1;
      } else {
        return valueA > valueB ? -1 : 1;
      }
    } else {
      // Handle date/time and other fields
      valueA = a[sortField.value];
      valueB = b[sortField.value];
      
      if (valueA === valueB) return 0;
      
      if (sortDirection.value === 'asc') {
        return valueA < valueB ? -1 : 1;
      } else {
        return valueA > valueB ? -1 : 1;
      }
    }
  });
  
  return shifts;
});

// Watch for filter changes to refresh results
watch([searchQuery, typeFilter], () => {
  // No need to reload data, just let the computed property handle filtering
});

// Helper function to convert hex to rgba
function hexToRgba(hex, alpha = 1) {
  if (!hex) return 'rgba(66, 133, 244, 0.15)'; // Default light blue if no color
  
  // Remove # if present
  hex = hex.replace('#', '');
  
  // Parse r, g, b values
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

// Get tinted versions of the user-defined shift colors
const dayShiftBgColor = computed(() => {
  // Use week_day color or fallback to a default if not available
  const hexColor = settingsStore.shiftDefaults?.week_day?.color || '#4285F4';
  return hexToRgba(hexColor, 0.15);
});

const nightShiftBgColor = computed(() => {
  // Use week_night color or fallback to a default if not available
  const hexColor = settingsStore.shiftDefaults?.week_night?.color || '#673AB7';
  return hexToRgba(hexColor, 0.15);
});

// Load data on component mount
onMounted(async () => {
  loading.value = true;
  try {
    console.log('Loading archived shifts...');
    await Promise.all([
      shiftsStore.fetchArchivedShifts(),
      settingsStore.loadSettings()
    ]);
    console.log(`Loaded ${shiftsStore.archivedShifts.length} archived shifts`);
    
    // Fetch task counts for all archived shifts
    await shiftsStore.fetchArchivedShiftTaskCounts();
  } catch (error) {
    console.error('Error loading archived shifts:', error);
  } finally {
    loading.value = false;
  }
});

// Get task count for a specific shift
function getTaskCount(shiftId) {
  return shiftsStore.archivedShiftTaskCounts[shiftId] || 0;
}

// Format date only (e.g., "May 23, 2025")
function formatDate(dateString) {
  if (!dateString) return 'N/A';
  const date = new Date(dateString);
  return date.toLocaleString('en-US', { 
    month: 'short', 
    day: 'numeric', 
    year: 'numeric'
  });
}

// Methods
function changeSortField(field) {
  if (sortField.value === field) {
    // Toggle direction if clicking on the same field
    sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc';
  } else {
    // Set new field and default to descending for dates
    sortField.value = field;
    sortDirection.value = (field === 'start_time' || field === 'end_time') ? 'desc' : 'asc';
  }
}

function viewShift(shiftId) {
  router.push(`/shift/${shiftId}`);
}

function confirmDelete(shiftId) {
  // Set this shift to confirmation state
  confirmingDelete.value = {
    ...confirmingDelete.value,
    [shiftId]: true
  };
  
  // Auto-reset confirmation after a timeout (3 seconds)
  setTimeout(() => {
    if (confirmingDelete.value[shiftId]) {
      confirmingDelete.value = {
        ...confirmingDelete.value,
        [shiftId]: false
      };
    }
  }, 3000);
}

async function deleteShift(shiftId) {
  if (isDeleting.value[shiftId]) return;
  
  isDeleting.value = {
    ...isDeleting.value,
    [shiftId]: true
  };
  
  try {
    const success = await shiftsStore.deleteShift(shiftId);
    if (!success) {
      // Reset confirmation state for this shift
      confirmingDelete.value = {
        ...confirmingDelete.value,
        [shiftId]: false
      };
    }
  } finally {
    // Reset deleting state for this shift
    isDeleting.value = {
      ...isDeleting.value,
      [shiftId]: false
    };
  }
}

// Format date and time (e.g., "May 23, 2025, 9:30 AM")
function formatDateTime(dateString) {
  if (!dateString) return 'N/A';
  const date = new Date(dateString);
  return date.toLocaleString('en-US', { 
    month: 'short', 
    day: 'numeric', 
    year: 'numeric',
    hour: 'numeric', 
    minute: '2-digit', 
    hour12: true 
  });
}

// Format shift type for display
function formatShiftType(shiftType) {
  switch (shiftType) {
    case 'week_day':
      return 'Weekday (Day)';
    case 'week_night':
      return 'Weekday (Night)';
    case 'weekend_day':
      return 'Weekend (Day)';
    case 'weekend_night':
      return 'Weekend (Night)';
    default:
      return shiftType;
  }
}

// Calculate duration between two timestamps
function calculateDuration(startTime, endTime) {
  if (!startTime || !endTime) return 'N/A';
  
  const start = new Date(startTime);
  const end = new Date(endTime);
  
  const diffMs = end - start;
  const diffHrs = Math.floor(diffMs / (1000 * 60 * 60));
  const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
  
  return `${diffHrs}h ${diffMins}m`;
}
</script>

<style lang="scss" scoped>
@use "sass:color";
.loading-indicator, .empty-state {
  text-align: center;
  padding: 2rem;
  color: #666;
}

.filter-controls {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  gap: 1rem;
  
  .search-box {
    flex: 1;
    min-width: 200px;
    
    .search-input {
      width: 100%;
      padding: 0.5rem;
      border: 1px solid #ccc;
      border-radius: 4px;
      font-size: 1rem;
    }
  }
  
  .filter-group {
    display: flex;
    gap: 1rem;
    
    label {
      display: flex;
      align-items: center;
      gap: 0.25rem;
      cursor: pointer;
    }
  }
}

.shifts-table-container {
  overflow-x: auto;
}

.shifts-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.95rem;
  
  th, td {
    padding: 0.75rem;
    text-align: left;
    border-bottom: 1px solid #e0e0e0;
  }
  
  th {
    background-color: #f5f5f5;
    font-weight: 600;
    cursor: pointer;
    user-select: none;
    
    &:hover {
      background-color: #e8e8e8;
    }
    
    .sort-indicator {
      margin-left: 0.25rem;
      display: inline-block;
    }
  }
  
  tr {
    &.day-shift {
      border-left: 3px solid v-bind('settingsStore.shiftDefaults?.week_day?.color || "#4285F4"');
      background-color: v-bind('dayShiftBgColor');
    }
    
    &.night-shift {
      border-left: 3px solid v-bind('settingsStore.shiftDefaults?.week_night?.color || "#673AB7"');
      background-color: v-bind('nightShiftBgColor');
    }
    
    &:hover {
      background-color: #f9f9f9;
    }
  }
}

.action-buttons {
  display: flex;
  gap: 0.5rem;
}

.btn {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s, background-color 0.2s;
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
  
  &-primary {
    background-color: #4285F4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#4285F4, $lightness: -10%);
    }
  }
  
  &-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#dc3545, $lightness: -10%);
    }
    
    &.confirm-delete {
      animation: pulse 1.5s infinite;
    }
  }
  
  &-small {
    padding: 0.25rem 0.5rem;
    font-size: 0.9rem;
  }
}

@keyframes pulse {
  0% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.9;
    transform: scale(1.05);
  }
  100% {
    opacity: 1;
    transform: scale(1);
  }
}
</style>
