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
        <!-- Pending Tasks Table (only shown if there are pending tasks) -->
        <div v-if="hasPendingTasks" class="pending-tasks-section">
          <h3 class="table-title">Pending Tasks</h3>
          <table class="tasks-table">
            <thead>
              <tr>
                <th>Time</th>
                <th>From</th>
                <th>To</th>
                <th>Task Info</th>
                <th>Porter</th>
                <th>Duration</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="task in pendingTasks" :key="task.id">
                <td>{{ formatTime(task.time_received) }}</td>
                <td>{{ task.departments_shift_tasks_origin_department_idTodepartments?.name || '-' }}</td>
                <td>{{ task.departments_shift_tasks_destination_department_idTodepartments?.name || '-' }}</td>
                <td>{{ task.task_items?.name || '-' }}</td>
                <td>{{ formatTaskPorters(task) }}</td>
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
                <th>To</th>
                <th>Task Info</th>
                <th>Porter</th>
                <th>Duration</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="task in completedTasks" :key="task.id">
                <td>{{ formatTime(task.time_received) }}</td>
                <td>{{ task.departments_shift_tasks_origin_department_idTodepartments?.name || '-' }}</td>
                <td>{{ task.departments_shift_tasks_destination_department_idTodepartments?.name || '-' }}</td>
                <td>{{ task.task_items?.name || '-' }}</td>
                <td>{{ formatTaskPorters(task) }}</td>
                <td>{{ calculateDuration(task) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        
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
        
        <!-- Porter Activity Summary -->
        <div class="porter-summary">
          <p class="summary-title">Porter Activity</p>
          <ul class="simple-list">
            <!-- Only render this section if we have pool porters -->
            <template v-if="hasPoolPorters">
              <li v-for="porterItem in poolPorters" :key="porterItem.id">
                {{ porterItem.name }}: {{ porterItem.taskCount }} {{ porterItem.taskCount === 1 ? 'Task' : 'Tasks' }}
                <span class="percentage-value">({{ porterItem.percentage.toFixed(1) }}%)</span>
                <span v-if="porterItem.movedTo" class="moved-note">(Moved to {{ porterItem.movedTo }})</span>
              </li>
            </template>
            <li v-else class="empty-state">
              No porters in the pool with assigned tasks
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
    
    // Fetch porter pool for this shift (needed for Porter Activity section)
    await shiftsStore.fetchShiftPorterPool(shiftId.value);
    
    // Fetch area cover assignments to determine porter department assignments
    await shiftsStore.fetchShiftAreaCover(shiftId.value);
    
    // Load task types if needed
    if (taskTypesStore.taskTypes.length === 0) {
      await taskTypesStore.fetchTaskTypes();
    }
    
    // Load settings if needed
    if (!settingsStore.appSettings) {
      await settingsStore.loadSettings();
    }
  } catch (err) {
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
  tasks.value.forEach(task => {
    if (!task.departments_shift_tasks_origin_department_idTodepartments) return;
    
    const deptId = task.departments_shift_tasks_origin_department_idTodepartments.id;
    const deptName = task.departments_shift_tasks_origin_department_idTodepartments.name;
    
    if (!departmentMap.has(deptId)) {
      departmentMap.set(deptId, {
        departmentName: deptName,
        taskTypes: {},
        totalTasks: 0
      });
    }
    
    const summary = departmentMap.get(deptId);
    const taskTypeName = task.task_items?.task_types?.name || 'Unknown';
    
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
    const typeName = task.task_items?.task_types?.name || 'Unknown';
    taskTypes.add(typeName);
  });
  
  // Convert to array and sort alphabetically
  return Array.from(taskTypes).sort();
});

// Debug log to track when porterActivity is recalculated
const debug = (msg, data) => {
  // Debug logging removed for production
};

// Porter activity summary - tracks porters and their task counts
const porterActivity = computed(() => {
  // If required data isn't loaded yet, return empty array
  if (!tasks.value || !shiftsStore.shiftPorterPool) {
    return [];
  }
  
  try {
    
    // Track porter task counts and department assignments
    const porterData = new Map();
    
    // Count tasks assigned to each porter
    tasks.value.forEach(task => {
      // Get all porters assigned to this task (both legacy and new multiple porter assignments)
      const taskPorters = getTaskPorters(task);
      
      taskPorters.forEach(porter => {
        if (porter && porter.id) {
          const porterId = porter.id;
          const porterName = `${porter.first_name} ${porter.last_name}`;
          
          if (!porterData.has(porterId)) {
            porterData.set(porterId, {
              id: porterId,
              name: porterName,
              taskCount: 0,
              inPool: true, // Default assumption
              movedTo: null // Will be set if the porter was moved to a department
            });
          }
          
          // Increment task count
          const data = porterData.get(porterId);
          data.taskCount++;
        }
      });
    });
    
    // Check pool assignments
    const porterPool = shiftsStore.shiftPorterPool || [];
    const poolPorterIds = new Set(porterPool.map(p => p?.porter_id).filter(Boolean));
    
    // Check area cover assignments (department assignments)
    const areaCoverAssignments = shiftsStore.shiftAreaCoverPorterAssignments || [];
    
    // Track department assignments
    const departmentAssignments = new Map();
    
    // Check area cover assignments
    areaCoverAssignments.forEach(assignment => {
      if (!assignment || !assignment.porter_id) return;
      
      const porterId = assignment.porter_id;
      if (!departmentAssignments.has(porterId)) {
        departmentAssignments.set(porterId, []);
      }
      
      // Add department to porter's assignments if it has a department
      if (assignment.shift_area_cover_assignment && 
          assignment.shift_area_cover_assignment.department) {
        departmentAssignments.get(porterId).push(
          assignment.shift_area_cover_assignment.department.name
        );
      }
    });
    
    // Update porter data with pool and department status
    porterData.forEach((data, porterId) => {
      // Check if porter is in the pool
      data.inPool = poolPorterIds.has(porterId);
      
      // Check if porter is assigned to any departments
      if (departmentAssignments.has(porterId)) {
        const depts = departmentAssignments.get(porterId);
        if (depts && depts.length > 0) {
          // If in pool but also has department assignments, they were moved mid-shift
          if (data.inPool) {
            data.movedTo = depts[0]; // Just use the first department
          } else {
            data.inPool = false;
          }
        }
      }
      
      // Calculate percentage of total tasks
      const totalTasks = tasks.value.length;
      if (totalTasks > 0) {
        data.percentage = (data.taskCount / totalTasks) * 100;
      } else {
        data.percentage = 0;
      }
    });
    
    // Convert to array and sort by task count (descending)
    const result = Array.from(porterData.values());
    const sortedResult = result.sort((a, b) => b.taskCount - a.taskCount);
    
    return sortedResult;
  } catch (error) {
    return []; // Return empty array on error
  }
});

// Derived computed property to get only porters in the pool
const poolPorters = computed(() => {
  return porterActivity.value.filter(p => p && p.inPool);
});

// Check if we have any porters in the pool to display
const hasPoolPorters = computed(() => {
  return poolPorters.value.length > 0;
});

// Get total count for a specific task type across all departments
function getTaskTypeTotal(taskType) {
  return tasks.value.filter(task => 
    (task.task_items?.task_types?.name || 'Unknown') === taskType
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
    // Function to create a task data row
    const createTaskRow = (task) => ({
      'Time': formatTime(task.time_received),
      'From': task.departments_shift_tasks_origin_department_idTodepartments?.name || '-',
      'To': task.departments_shift_tasks_destination_department_idTodepartments?.name || '-',
      'Task Info': task.task_items?.name || '-',
      'Porter': formatTaskPorters(task),
      'Duration': calculateDuration(task)
    });
    
    // Prepare column widths for task worksheets
    const columnWidths = [
      { wch: 10 }, // Time
      { wch: 20 }, // From
      { wch: 20 }, // To
      { wch: 25 }, // Task Info
      { wch: 15 }, // Porter
      { wch: 10 }  // Duration
    ];
    
    // Create pending tasks worksheet if there are pending tasks
    let pendingWorksheet = null;
    if (pendingTasks.value.length > 0) {
      const pendingData = pendingTasks.value.map(createTaskRow);
      pendingWorksheet = XLSX.utils.json_to_sheet(pendingData);
      pendingWorksheet['!cols'] = columnWidths;
    }
    
    // Create completed tasks worksheet
    const completedData = completedTasks.value.map(createTaskRow);
    const completedWorksheet = XLSX.utils.json_to_sheet(completedData);
    completedWorksheet['!cols'] = columnWidths;
    
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
    
    // Create porter activity worksheet
    const porterData = poolPorters.value
      .map(porterItem => ({
        'Porter': porterItem.name,
        'Tasks': porterItem.taskCount,
        'Percentage': `${porterItem.percentage.toFixed(1)}%`,
        'Status': porterItem.movedTo ? `Moved to ${porterItem.movedTo}` : 'In Pool'
      }));
    
    const porterWorksheet = XLSX.utils.json_to_sheet(porterData);
    
    // Set column widths for porter worksheet
    const porterColumnWidths = [
      { wch: 25 }, // Porter
      { wch: 10 }, // Tasks
      { wch: 12 }, // Percentage
      { wch: 20 }  // Status
    ];
    porterWorksheet['!cols'] = porterColumnWidths;
    
    // Create workbook and append worksheets
    const workbook = XLSX.utils.book_new();
    
    // Set workbook properties for sans-serif font
    workbook.Styles = {
      "fonts": [
        { "name": "Arial", "family": 2 }  // Sans-serif font
      ],
      "numFmts": [],
      "cellStyles": [
        { "fontId": 0 }
      ]
    };
    
    // Add pending tasks worksheet if it exists
    if (pendingWorksheet) {
      XLSX.utils.book_append_sheet(workbook, pendingWorksheet, 'Pending Tasks');
    }
    
    // Add completed tasks and other worksheets
    XLSX.utils.book_append_sheet(workbook, completedWorksheet, 'Completed Tasks');
    XLSX.utils.book_append_sheet(workbook, summaryWorksheet, 'Department Summary');
    XLSX.utils.book_append_sheet(workbook, porterWorksheet, 'Porter Activity');
    
    // Generate filename based on shift info
    const shiftDate = shift.value?.start_time 
      ? formatShortDate(shift.value.start_time).replace(/[^a-zA-Z0-9]/g, '_')
      : 'Unknown_Date';
    const shiftType = getShiftTypeDisplayName().replace(' ', '_');
    const filename = `Activity_Sheet_${shiftType}_${shiftDate}.xlsx`;
    
    // Write to file and trigger download
    XLSX.writeFile(workbook, filename);
  } catch (err) {
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
    if (settingsStore.appSettings?.time_format === '24h') {
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
      if (settingsStore.appSettings?.time_format === '24h') {
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

// Get all porters assigned to a task (both legacy single porter and new multiple porter assignments)
function getTaskPorters(task) {
  const porters = [];
  
  // Add legacy single porter assignment if it exists
  if (task.staff) {
    porters.push(task.staff);
  }
  
  // Add multiple porter assignments if they exist
  if (task.shift_task_porter_assignments && task.shift_task_porter_assignments.length > 0) {
    task.shift_task_porter_assignments.forEach(assignment => {
      if (assignment.staff) {
        // Check if this porter is already in the list (to avoid duplicates)
        const exists = porters.some(porter => porter.id === assignment.staff.id);
        if (!exists) {
          porters.push(assignment.staff);
        }
      }
    });
  }
  
  return porters;
}

// Format porter names for display in the activity sheet
function formatTaskPorters(task) {
  const porters = getTaskPorters(task);
  
  if (porters.length === 0) {
    return '-';
  }
  
  if (porters.length === 1) {
    return `${porters[0].first_name} ${porters[0].last_name}`;
  }
  
  if (porters.length === 2) {
    return `${porters[0].first_name} ${porters[0].last_name} & ${porters[1].first_name} ${porters[1].last_name}`;
  }
  
  // For 3 or more porters, show first two and count
  return `${porters[0].first_name} ${porters[0].last_name}, ${porters[1].first_name} ${porters[1].last_name} & ${porters.length - 2} more`;
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
  
  .table-title {
    font-size: 9pt !important;
    font-weight: bold !important;
    margin-bottom: 5pt !important;
    margin-top: 0 !important;
  }
  
  .pending-tasks-section {
    margin-bottom: 15pt !important;
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
    text-align: left;
    margin-bottom: 10px;
  }
  
  .sheet-header {
    font-size: 14pt !important;
    font-weight: bold;
    margin-bottom: 4pt !important;
  }
  
  .sheet-info {
    font-size: 10pt !important;
    margin: 0 !important;
    text-align: left !important;
  }
  
  .tasks-table {
    font-size: 6.5pt !important;
    width: 100%;
    table-layout: fixed;
    border-collapse: collapse;
    letter-spacing: -0.1pt !important;
    margin-bottom: 0.3cm !important;
    
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
    th:nth-child(1) { width: 10%; }   /* Time */
    th:nth-child(2) { width: 20%; }   /* From */
    th:nth-child(3) { width: 20%; }   /* To */
    th:nth-child(4) { width: 25%; }   /* Task Info */
    th:nth-child(5) { width: 15%; }   /* Porter */
    th:nth-child(6) { width: 10%; }   /* Duration */
  }
  
  .department-summary, .porter-summary {
    font-size: 6.5pt !important;
    margin-top: 0.5cm !important;
    padding-top: 0 !important;
    
    .summary-title {
      font-size: 8pt !important;
      font-weight: bold;
      margin-bottom: 5px !important;
    }
  }
  
  .porter-summary {
    margin-top: 0.5cm !important;
  }
  
  .simple-list {
    list-style-type: none !important;
    padding-left: 0 !important;
    margin-left: 0 !important;
    
    li {
      font-size: 6.5pt !important;
      margin-bottom: 2pt !important;
      line-height: 1.1 !important;
    }
    
    .total-item {
      margin-top: 5pt !important;
      padding-top: 3pt !important;
      border-top: 0.5pt solid #333 !important;
    }
    
    .percentage-value {
      color: #666 !important;
      margin-left: 3px !important;
    }
    
    .moved-note {
      font-style: italic !important;
      color: #555 !important;
    }
    
    .empty-state {
      font-style: italic !important;
      color: #666 !important;
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

.pending-tasks-section,
.completed-tasks-section {
  margin-bottom: 40px;
}

.table-title {
  font-size: 1rem;
  font-weight: 600;
  margin-bottom: 15px;
  margin-top: 0;
  color: #333;
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
  th:nth-child(1) { width: 10%; }   /* Time */
  th:nth-child(2) { width: 20%; }   /* From */
  th:nth-child(3) { width: 20%; }   /* To */
  th:nth-child(4) { width: 25%; }   /* Task Info */
  th:nth-child(5) { width: 15%; }   /* Porter */
  th:nth-child(6) { width: 10%; }   /* Duration */
}

.department-summary, .porter-summary {
  margin-top: 30px;
  
  .summary-title {
    font-size: 1rem;
    font-weight: bold;
    margin-bottom: 8px;
    margin-top: 0;
  }
  
  .simple-list {
    list-style-type: none;
    padding-left: 0;
    margin-left: 0;
    
    li {
      font-size: 0.85rem;
      font-weight: 400;
      color: #333;
      margin-bottom: 8px;
      line-height: 1.3;
    }
    
    .total-item {
      margin-top: 15px;
      padding-top: 8px;
      border-top: 1px solid #333;
    }
    
    .percentage-value {
      color: #666;
      margin-left: 4px;
    }
    
    .moved-note {
      font-style: italic;
      color: #555;
      margin-left: 4px;
    }
    
    .empty-state {
      font-style: italic;
      color: #666;
    }
  }
}

.porter-summary {
  margin-top: 25px;
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
