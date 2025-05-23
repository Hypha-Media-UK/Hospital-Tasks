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
                  <th @click="changeSortField('shift_type')">
                    Type
                    <span v-if="sortField === 'shift_type'" class="sort-indicator">
                      {{ sortDirection === 'asc' ? '▲' : '▼' }}
                    </span>
                  </th>
                  <th @click="changeSortField('supervisor')">
                    Supervisor
                    <span v-if="sortField === 'supervisor'" class="sort-indicator">
                      {{ sortDirection === 'asc' ? '▲' : '▼' }}
                    </span>
                  </th>
                  <th @click="changeSortField('start_time')">
                    Start Time
                    <span v-if="sortField === 'start_time'" class="sort-indicator">
                      {{ sortDirection === 'asc' ? '▲' : '▼' }}
                    </span>
                  </th>
                  <th @click="changeSortField('end_time')">
                    End Time
                    <span v-if="sortField === 'end_time'" class="sort-indicator">
                      {{ sortDirection === 'asc' ? '▲' : '▼' }}
                    </span>
                  </th>
                  <th>Duration</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr 
                  v-for="shift in filteredAndSortedShifts" 
                  :key="shift.id"
                  :class="{ 'day-shift': shift.shift_type === 'day', 'night-shift': shift.shift_type === 'night' }"
                >
                  <td>{{ shift.shift_type === 'day' ? 'Day' : 'Night' }}</td>
                  <td>
                    {{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}
                  </td>
                  <td>{{ formatDateTime(shift.start_time) }}</td>
                  <td>{{ formatDateTime(shift.end_time) }}</td>
                  <td>{{ calculateDuration(shift.start_time, shift.end_time) }}</td>
                  <td>
                    <button @click="viewShift(shift.id)" class="btn btn-primary btn-small">
                      View
                    </button>
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

const router = useRouter();
const shiftsStore = useShiftsStore();

// Local state
const loading = ref(true);
const searchQuery = ref('');
const typeFilter = ref('all');
const sortField = ref('end_time');
const sortDirection = ref('desc');

// Computed properties
const archivedShifts = computed(() => shiftsStore.archivedShifts);

const filteredAndSortedShifts = computed(() => {
  let shifts = [...archivedShifts.value];
  
  // Apply type filter
  if (typeFilter.value !== 'all') {
    shifts = shifts.filter(shift => shift.shift_type === typeFilter.value);
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

// Load data on component mount
onMounted(async () => {
  loading.value = true;
  await shiftsStore.fetchArchivedShifts();
  loading.value = false;
});

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
      border-left: 3px solid #4285F4;
    }
    
    &.night-shift {
      border-left: 3px solid #673AB7;
    }
    
    &:hover {
      background-color: #f9f9f9;
    }
  }
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
      background-color: darken(#4285F4, 10%);
    }
  }
  
  &-small {
    padding: 0.25rem 0.5rem;
    font-size: 0.9rem;
  }
}
</style>
