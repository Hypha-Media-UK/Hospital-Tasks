<template>
  <div class="modal-overlay" @click.self="closeModal">
    <div class="activity-sheet-modal">
      <div class="modal-header">
        <h2>Activity Sheet</h2>
        <div class="modal-actions">
          <button @click="printSheet" class="btn btn-primary">
            Print
          </button>
          <button @click="closeModal" class="close-button">&times;</button>
        </div>
      </div>
      
      <div class="modal-body">
        <div class="activity-sheet">
          <div class="sheet-header">
            <h2>Activity Sheet</h2>
            <p class="sheet-info">
              {{ getShiftTypeDisplayName() }} | {{ formatShortDate(shift.start_time) }} | {{ tasks.length }} Tasks
            </p>
          </div>
          
          <div class="sheet-content">
            <!-- Pending Tasks Table (only shown if there are pending tasks) -->
            <div v-if="hasPendingTasks" class="pending-tasks-section">
              <h3 class="table-title">Pending Tasks</h3>
              <table class="tasks-table">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>From</th>
                    <th>Task</th>
                    <th>Task Info</th>
                    <th>To</th>
                    <th>Allocated</th>
                    <th>Porter</th>
                    <th>Completed</th>
                    <th>Duration</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="task in pendingTasks" :key="task.id">
                    <td>{{ formatTime(task.time_received) }}</td>
                    <td>{{ task.origin_department?.name || '-' }}</td>
                    <td>{{ task.task_item.task_type?.name || 'Unknown' }}</td>
                    <td>{{ task.task_item.name }}</td>
                    <td>{{ task.destination_department?.name || '-' }}</td>
                    <td>{{ formatTime(task.time_allocated) }}</td>
                    <td>{{ task.porter ? `${task.porter.first_name} ${task.porter.last_name}` : '-' }}</td>
                    <td>{{ task.status === 'completed' ? formatTime(task.time_completed) : '-' }}</td>
                    <td>{{ calculateDuration(task) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            
            <!-- Completed Tasks Table -->
            <div class="completed-tasks-section">
              <h3 class="table-title">Completed Tasks</h3>
              <table class="tasks-table">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>From</th>
                    <th>Task</th>
                    <th>Task Info</th>
                    <th>To</th>
                    <th>Allocated</th>
                    <th>Porter</th>
                    <th>Completed</th>
                    <th>Duration</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="task in completedTasks" :key="task.id">
                    <td>{{ formatTime(task.time_received) }}</td>
                    <td>{{ task.origin_department?.name || '-' }}</td>
                    <td>{{ task.task_item.task_type?.name || 'Unknown' }}</td>
                    <td>{{ task.task_item.name }}</td>
                    <td>{{ task.destination_department?.name || '-' }}</td>
                    <td>{{ formatTime(task.time_allocated) }}</td>
                    <td>{{ task.porter ? `${task.porter.first_name} ${task.porter.last_name}` : '-' }}</td>
                    <td>{{ task.status === 'completed' ? formatTime(task.time_completed) : '-' }}</td>
                    <td>{{ calculateDuration(task) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            
            <div class="department-summary">
              <h3>Department Task Summary</h3>
              <ul class="department-list">
                <li v-for="(summary, index) in departmentSummaries" :key="index">
                  <strong>{{ summary.departmentName }}:</strong>
                  <span v-for="(count, type, typeIndex) in summary.taskTypes" :key="type">
                    {{ count }} {{ type }}{{ typeIndex < Object.keys(summary.taskTypes).length - 1 ? ' | ' : '' }}
                  </span>
                  ({{ summary.totalTasks }} {{ summary.totalTasks === 1 ? 'Task' : 'Tasks' }})
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useSettingsStore } from '../stores/settingsStore';
import { useTaskTypesStore } from '../stores/taskTypesStore';

const props = defineProps({
  shift: {
    type: Object,
    required: true
  },
  tasks: {
    type: Array,
    required: true
  }
});

const emit = defineEmits(['close']);

const settingsStore = useSettingsStore();
const taskTypesStore = useTaskTypesStore();

// Sort tasks by time received
const sortedTasks = computed(() => {
  return [...props.tasks].sort((a, b) => {
    // First convert time strings to Date objects for comparison
    const timeA = a.time_received ? new Date(`2025-01-01T${a.time_received}`) : new Date(0);
    const timeB = b.time_received ? new Date(`2025-01-01T${b.time_received}`) : new Date(0);
    return timeA - timeB;
  });
});

// Filter for pending tasks only
const pendingTasks = computed(() => {
  return sortedTasks.value.filter(task => task.status === 'pending');
});

// Filter for completed tasks only
const completedTasks = computed(() => {
  return sortedTasks.value.filter(task => task.status === 'completed');
});

// Check if there are any pending tasks
const hasPendingTasks = computed(() => {
  return pendingTasks.value.length > 0;
});

// Generate department summaries
const departmentSummaries = computed(() => {
  const summaries = [];
  const departmentMap = new Map();
  
  // First, let's get all origin departments with their tasks
  props.tasks.forEach(task => {
    if (!task.origin_department) return;
    
    const deptId = task.origin_department.id;
    const deptName = task.origin_department.name;
    
    if (!departmentMap.has(deptId)) {
      departmentMap.set(deptId, {
        departmentName: deptName,
        taskTypes: {},
        totalTasks: 0
      });
    }
    
    const summary = departmentMap.get(deptId);
    const taskTypeName = task.task_item.task_type?.name || 'Unknown';
    
    // Increment count for this task type
    summary.taskTypes[taskTypeName] = (summary.taskTypes[taskTypeName] || 0) + 1;
    summary.totalTasks++;
  });
  
  // Convert map to array
  departmentMap.forEach(summary => {
    summaries.push(summary);
  });
  
  // Sort by department name
  return summaries.sort((a, b) => a.departmentName.localeCompare(b.departmentName));
});

// Load task types if needed
onMounted(async () => {
  if (taskTypesStore.taskTypes.length === 0) {
    await taskTypesStore.fetchTaskTypes();
  }
});

// Close the modal
function closeModal() {
  emit('close');
}

// Print the sheet
function printSheet() {
  window.print();
}

// Format time using centralized timezone helper
function formatTime(timeString) {
  if (!timeString) return '-';
  
  // Use browser's built-in formatting for 24-hour time
  try {
    // Handle both time-only strings (HH:MM:SS) and full datetime strings
    let date;
    if (timeString.includes('T')) {
      // Full datetime string
      date = new Date(timeString);
    } else {
      // Time-only string - create a date with today's date
      date = new Date(`2025-01-01T${timeString}`);
    }
    
    if (isNaN(date.getTime())) {
      return timeString; // Return original if parsing fails
    }
    
    return date.toLocaleTimeString('en-GB', { 
      hour12: false,
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch (error) {
    return timeString; // Return original if error occurs
  }
}

// Calculate duration for a task
function calculateDuration(task) {
  if (task.status !== 'completed' || !task.time_received || !task.time_completed) {
    return '-';
  }
  
  try {
    // Create date objects for start and end times
    const startTime = new Date(`2025-01-01T${task.time_received}`);
    const endTime = new Date(`2025-01-01T${task.time_completed}`);
    
    // Calculate difference in minutes
    let diffMinutes = Math.round((endTime - startTime) / (1000 * 60));
    
    // Handle overnight tasks (if end time is before start time)
    if (diffMinutes < 0) {
      diffMinutes += 24 * 60; // Add 24 hours in minutes
    }
    
    // Format as hours and minutes
    const hours = Math.floor(diffMinutes / 60);
    const minutes = diffMinutes % 60;
    
    if (hours === 0) {
      return `${minutes}m`;
    } else {
      return `${hours}h ${minutes}m`;
    }
  } catch (e) {
    return '-';
  }
}

// Format date as "29th May 2025"
function formatShortDate(dateString) {
  if (!dateString) return '';
  
  const date = new Date(dateString);
  
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

// Get display name for shift type
function getShiftTypeDisplayName() {
  if (!props.shift) return 'Shift';
  
  // Simplify shift type display to just "Day Shift" or "Night Shift"
  if (props.shift.shift_type.includes('day')) {
    return 'Day Shift';
  } else if (props.shift.shift_type.includes('night')) {
    return 'Night Shift';
  } else {
    return 'Shift';
  }
}
</script>

<!-- Styles are now handled by the global CSS layers -->