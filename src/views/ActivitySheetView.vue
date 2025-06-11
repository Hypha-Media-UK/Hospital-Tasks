<template>
  <div class="activity-sheet-view">
    <!-- Header with navigation and action buttons -->
    <header class="sheet-header">
      <div class="actions-bar">
        <button @click="goBackToShift" class="btn btn-secondary">
          <span>← Back to Shift</span>
        </button>
        
        <div class="right-actions">
          <button @click="exportToExcel" class="btn btn-success">
            <span>Export to Excel</span>
          </button>
          <button @click="printSheet" class="btn btn-primary">
            <span>Print</span>
          </button>
        </div>
      </div>
      
      <div class="sheet-title">
        <p class="sheet-header">Activity Sheet</p>
        <p class="sheet-info">
          {{ getShiftTypeDisplayName() }} | {{ formatShortDate(shift?.start_time) }} | {{ tasks.length }} Tasks
        </p>
      </div>
    </header>

    <!-- Main content (table) -->
    <main class="sheet-content">
      <div v-if="loading" class="loading-indicator">
        <p>Loading activity sheet data...</p>
      </div>
      
      <div v-else-if="error" class="error-message">
        <p>{{ error }}</p>
        <button @click="goBackToShift" class="btn btn-secondary">Back to Shift</button>
      </div>
      
      <div v-else class="activity-sheet-container">
        <table class="tasks-table">
          <thead>
            <tr>
              <th>Time</th>
              <th>From</th>
              <th>To</th>
              <th>Task</th>
              <th>Task Info</th>
              <th>Allocated</th>
              <th>Porter</th>
              <th>Completed</th>
              <th>Duration</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="task in sortedTasks" :key="task.id">
              <td>{{ formatTime(task.time_received) }}</td>
              <td>{{ task.origin_department?.name || '-' }}</td>
              <td>{{ task.destination_department?.name || '-' }}</td>
              <td>{{ task.task_item.task_type?.name || 'Unknown' }}</td>
              <td>{{ task.task_item.name }}</td>
              <td>{{ formatTime(task.time_allocated) }}</td>
              <td>{{ task.porter ? `${task.porter.first_name} ${task.porter.last_name}` : '-' }}</td>
              <td>{{ task.status === 'completed' ? formatTime(task.time_completed) : '-' }}</td>
              <td>{{ calculateDuration(task) }}</td>
            </tr>
          </tbody>
        </table>
        
        <div class="department-summary">
          <p class="summary-title">Department Task Summary</p>
          <ul class="simple-list">
            <li v-for="(summary, index) in departmentSummaries" :key="index">
              {{ summary.departmentName }}: {{ summary.totalTasks }} {{ summary.totalTasks === 1 ? 'Request' : 'Requests' }}
            </li>
            <li class="total-item">
              <strong>All Departments: {{ tasks.length }} {{ tasks.length === 1 ? 'Request' : 'Requests' }}</strong>
            </li>
          </ul>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useSettingsStore } from '../stores/settingsStore';
import { useTaskTypesStore } from '../stores/taskTypesStore';
import * as XLSX from 'xlsx';

const route = useRoute();
const router = useRouter();
const shiftsStore = useShiftsStore();
const settingsStore = useSettingsStore();
const taskTypesStore = useTaskTypesStore();

// Local state
const loading = ref(true);
const error = ref(null);
const shift = ref(null);
const tasks = ref([]);

// Get shift ID from route
const shiftId = computed(() => route.params.id);

// Load data on component mount
onMounted(async () => {
  loading.value = true;
  error.value = null;
  
  try {
    // Fetch the shift
    const shiftData = await shiftsStore.fetchShiftById(shiftId.value);
    if (!shiftData) {
      error.value = 'Shift not found';
      loading.value = false;
      return;
    }
    
    shift.value = shiftData;
    
    // Fetch tasks for this shift
    const tasksData = await shiftsStore.fetchShiftTasks(shiftId.value);
    tasks.value = tasksData || [];
    
    // Load task types if needed
    if (taskTypesStore.taskTypes.length === 0) {
      await taskTypesStore.fetchTaskTypes();
    }
    
    // Load settings if needed
    if (!settingsStore.appSettings) {
      await settingsStore.loadSettings();
    }
  } catch (err) {
    console.error('Error loading activity sheet data:', err);
    error.value = 'Failed to load activity sheet data. Please try again.';
  } finally {
    loading.value = false;
  }
});

// Sort tasks by time received
const sortedTasks = computed(() => {
  return [...tasks.value].sort((a, b) => {
    // First convert time strings to Date objects for comparison
    const timeA = a.time_received ? new Date(`2025-01-01T${a.time_received}`) : new Date(0);
    const timeB = b.time_received ? new Date(`2025-01-01T${b.time_received}`) : new Date(0);
    return timeA - timeB;
  });
});

// Generate department summaries
const departmentSummaries = computed(() => {
  const summaries = [];
  const departmentMap = new Map();
  
  // First, let's get all origin departments with their tasks
  tasks.value.forEach(task => {
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

// Get unique task types from all tasks
const uniqueTaskTypes = computed(() => {
  const taskTypes = new Set();
  
  // Collect all task types from tasks
  tasks.value.forEach(task => {
    const typeName = task.task_item.task_type?.name || 'Unknown';
    taskTypes.add(typeName);
  });
  
  // Convert to array and sort alphabetically
  return Array.from(taskTypes).sort();
});

// Get total count for a specific task type across all departments
function getTaskTypeTotal(taskType) {
  return tasks.value.filter(task => 
    (task.task_item.task_type?.name || 'Unknown') === taskType
  ).length;
}

// Navigation
function goBackToShift() {
  router.push(`/shift/${shiftId.value}`);
}

// Print the sheet
function printSheet() {
  window.print();
}

// Export to Excel
function exportToExcel() {
  try {
    // Prepare data for export - flatten the task objects
    const excelData = sortedTasks.value.map(task => ({
      'Time': formatTime(task.time_received),
      'From': task.origin_department?.name || '-',
      'To': task.destination_department?.name || '-',
      'Task': task.task_item.task_type?.name || 'Unknown',
      'Task Info': task.task_item.name,
      'Allocated': formatTime(task.time_allocated),
      'Porter': task.porter ? `${task.porter.first_name} ${task.porter.last_name}` : '-',
      'Completed': task.status === 'completed' ? formatTime(task.time_completed) : '-',
      'Duration': calculateDuration(task)
    }));
    
    // Create worksheet
    const worksheet = XLSX.utils.json_to_sheet(excelData);
    
    // Set column widths for better readability
    const columnWidths = [
      { wch: 10 }, // Time
      { wch: 20 }, // From
      { wch: 20 }, // To
      { wch: 15 }, // Task
      { wch: 25 }, // Task Info
      { wch: 10 }, // Allocated
      { wch: 20 }, // Porter
      { wch: 10 }, // Completed
      { wch: 10 }  // Duration
    ];
    worksheet['!cols'] = columnWidths;
    
    // Create department summary worksheet
    const summaryData = departmentSummaries.value.map(summary => {
      // Create an object with department name and total tasks
      const data = {
        'Department': summary.departmentName,
        'Total Tasks': summary.totalTasks
      };
      
      // Add task type counts
      Object.entries(summary.taskTypes).forEach(([type, count]) => {
        data[type] = count;
      });
      
      return data;
    });
    
    const summaryWorksheet = XLSX.utils.json_to_sheet(summaryData);
    
    // Create workbook and append worksheets
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Tasks');
    XLSX.utils.book_append_sheet(workbook, summaryWorksheet, 'Department Summary');
    
    // Generate filename based on shift info
    const shiftDate = shift.value?.start_time 
      ? formatShortDate(shift.value.start_time).replace(/[^a-zA-Z0-9]/g, '_')
      : 'Unknown_Date';
    const shiftType = getShiftTypeDisplayName().replace(' ', '_');
    const filename = `Activity_Sheet_${shiftType}_${shiftDate}.xlsx`;
    
    // Write to file and trigger download
    XLSX.writeFile(workbook, filename);
  } catch (err) {
    console.error('Error exporting to Excel:', err);
    alert('Failed to export to Excel. Please try again.');
  }
}

// Format time (e.g., "9:30 AM" or "09:30") without the date based on app settings
function formatTime(timeString) {
  if (!timeString) return '-';
  
  // Check if the input is already in HH:MM format
  if (typeof timeString === 'string' && /^\d{1,2}:\d{2}$/.test(timeString)) {
    // Already in the right format, just format according to settings
    const [hours, minutes] = timeString.split(':').map(Number);
    
    // Use 24h or 12h format based on settings
    if (settingsStore.appSettings?.timeFormat === '24h') {
      return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
    } else {
      // Convert to 12h format
      const period = hours >= 12 ? 'PM' : 'AM';
      const hours12 = hours % 12 || 12;
      return `${hours12}:${String(minutes).padStart(2, '0')} ${period}`;
    }
  } else {
    // For backward compatibility - if it's still a date string
    try {
      const date = new Date(timeString);
      
      // Use 24h or 12h format based on settings
      if (settingsStore.appSettings?.timeFormat === '24h') {
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        return `${hours}:${minutes}`;
      } else {
        return date.toLocaleTimeString('en-US', { 
          hour: 'numeric', 
          minute: '2-digit', 
          hour12: true 
        });
      }
    } catch (e) {
      console.error('Error formatting time:', e);
      return timeString || '-';
    }
  }
}

// Helper to validate time format
function isValidTimeFormat(timeStr) {
  return typeof timeStr === 'string' && /^\d{1,2}:\d{2}(:\d{2})?$/.test(timeStr);
}

// Helper to safely create a date object from a time string
function createTimeDate(timeStr) {
  try {
    // Try standard format first (HH:MM or HH:MM:SS)
    if (isValidTimeFormat(timeStr)) {
      const date = new Date(`2025-01-01T${timeStr}`);
      if (!isNaN(date.getTime())) {
        return date;
      }
    }
    
    // If it's a full date string, try to extract time part
    if (typeof timeStr === 'string' && timeStr.includes('T')) {
      const date = new Date(timeStr);
      if (!isNaN(date.getTime())) {
        return date;
      }
    }
    
    return null; // Invalid format
  } catch (e) {
    console.error('Error creating date object:', e);
    return null;
  }
}

// Calculate duration for a task
function calculateDuration(task) {
  if (task.status !== 'completed' || !task.time_received || !task.time_completed) {
    return '-';
  }
  
  try {
    // Create date objects for start and end times with validation
    const startTime = createTimeDate(task.time_received);
    const endTime = createTimeDate(task.time_completed);
    
    // Verify both dates are valid
    if (!startTime || !endTime) {
      console.warn('Invalid time format for task:', task.id);
      return '-';
    }
    
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
    console.error('Error calculating duration:', e, task);
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
  if (!shift.value) return 'Shift';
  
  // Simplify shift type display to just "Day Shift" or "Night Shift"
  if (shift.value.shift_type.includes('day')) {
    return 'Day Shift';
  } else if (shift.value.shift_type.includes('night')) {
    return 'Night Shift';
  } else {
    return 'Shift';
  }
}
</script>

<style lang="scss">
// Global styles (applied to the whole document when printing)
@media print {
  @page {
    size: A4 portrait;
    margin: 0.7cm;
  }
  
  body {
    margin: 0;
    padding: 0;
    background-color: white;
    font-size: 6.5pt;
  }
  
  button, .actions-bar {
    display: none !important;
  }
  
  .sheet-title {
    text-align: center;
    margin-bottom: 10px;
  }
  
  .sheet-header {
    font-size: 16pt !important;
    font-weight: bold;
    margin-bottom: 4pt !important;
  }
  
  .sheet-info {
    font-size: 10pt !important;
    margin: 0 !important;
  }
  
  .tasks-table {
    font-size: 6.5pt !important;
    width: 100%;
    table-layout: fixed;
    border-collapse: collapse;
    letter-spacing: -0.1pt !important;
    
    th, td {
      padding: 1px 2px !important;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      border: 0.25pt solid black !important;
    }
    
    th {
      font-weight: bold !important;
      font-size: 7pt !important;
      background-color: #f2f2f2 !important;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
      padding-top: 2px !important;
      padding-bottom: 2px !important;
    }
    
    /* Set specific column widths */
    th:nth-child(1) { width: 5.5%; }  /* Time */
    th:nth-child(2) { width: 14%; }   /* From */
    th:nth-child(3) { width: 14%; }   /* To */
    th:nth-child(4) { width: 13%; }   /* Task */
    th:nth-child(5) { width: 16%; }   /* Task Info */
    th:nth-child(6) { width: 6.5%; }  /* Allocated */
    th:nth-child(7) { width: 14.5%; } /* Porter */
    th:nth-child(8) { width: 6.5%; }  /* Completed */
    th:nth-child(9) { width: 10%; }   /* Duration */
  }
  
  .department-summary {
    font-size: 8pt;
    break-before: page;
    margin-top: 0 !important;
    padding-top: 0.8cm !important;
    
    .summary-title {
      font-size: 12pt !important;
      font-weight: bold;
      margin-bottom: 8px !important;
    }
  }
  
  .simple-list {
    list-style-type: none !important;
    padding-left: 0 !important;
    margin-left: 0 !important;
    
    li {
      font-size: 8pt !important;
      margin-bottom: 3pt !important;
      line-height: 1.2 !important;
    }
    
    .total-item {
      margin-top: 8pt !important;
      padding-top: 4pt !important;
      border-top: 1px solid #333 !important;
    }
  }
}
</style>

<style lang="scss" scoped>
.activity-sheet-view {
  padding: 20px;
  max-width: 1400px;
  margin: 0 auto;
}

.sheet-header {
  margin-bottom: 30px;
}

.actions-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  
  .right-actions {
    display: flex;
    gap: 10px;
  }
}

.sheet-title {
  .sheet-header {
    font-size: 28px;
    font-weight: bold;
    margin-bottom: 8px;
    margin-top: 0;
  }
  
  .sheet-info {
    font-size: 16px;
    font-weight: bold;
    margin: 0;
  }
}

.loading-indicator, .error-message {
  text-align: center;
  padding: 40px;
  
  p {
    margin-bottom: 20px;
  }
}

.tasks-table {
  width: 100%;
  border-collapse: collapse;
  margin-bottom: 30px;
  font-size: 0.85rem;
  table-layout: fixed;
  
  th, td {
    border: 0.5px solid #ccc;
    padding: 6px 8px;
    text-align: left;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  
  th {
    background-color: #f8f9fa;
    font-weight: bold;
    font-size: 0.9rem;
    position: sticky;
    top: 0;
  }
  
  tr:nth-child(even) {
    background-color: #f8f9fa;
  }
  
  /* Column widths for better display */
  th:nth-child(1) { width: 5.5%; }  /* Time */
  th:nth-child(2) { width: 14%; }   /* From */
  th:nth-child(3) { width: 14%; }   /* To */
  th:nth-child(4) { width: 13%; }   /* Task */
  th:nth-child(5) { width: 16%; }   /* Task Info */
  th:nth-child(6) { width: 6.5%; }  /* Allocated */
  th:nth-child(7) { width: 14.5%; } /* Porter */
  th:nth-child(8) { width: 6.5%; }  /* Completed */
  th:nth-child(9) { width: 10%; }   /* Duration */
}

.department-summary {
  margin-top: 40px;
  
  .summary-title {
    font-size: 22px;
    font-weight: bold;
    margin-bottom: 15px;
    margin-top: 0;
  }
  
  .simple-list {
    list-style-type: none;
    padding-left: 0;
    margin-left: 0;
    
    li {
      font-size: 18px;
      font-weight: 400;
      color: #333;
      margin-bottom: 12px;
      line-height: 1.5;
    }
    
    .total-item {
      margin-top: 20px;
      padding-top: 10px;
      border-top: 1px solid #333;
    }
  }
}

.btn {
  padding: 10px 15px;
  border: none;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  transition: background-color 0.2s;
  
  &-primary {
    background-color: #4285F4;
    color: white;
    
    &:hover {
      background-color: darken(#4285F4, 10%);
    }
  }
  
  &-secondary {
    background-color: #9e9e9e;
    color: white;
    
    &:hover {
      background-color: darken(#9e9e9e, 10%);
    }
  }
  
  &-success {
    background-color: #34A853;
    color: white;
    
    &:hover {
      background-color: darken(#34A853, 10%);
    }
  }
}
</style>
