<template>
  <div class="view">
    <div class="view__content">
      <div v-if="loading" class="loading">
        <p>Loading shift information...</p>
      </div>
      
      <div v-else-if="!shift" class="error-state">
        <p>Shift not found or has been deleted.</p>
        <button @click="navigateToHome" class="btn btn-primary">Back to Home</button>
      </div>
      
      <template v-else>
        <!-- Simplified Shift Information Header -->
        <div 
          class="shift-info-header mb-4" 
          :class="{ 'archived-shift': !shift.is_active }"
        >
          <div class="shift-header-content">
            <h2>
              <span class="shift-type" :style="{ color: getShiftColor() }">
                {{ getShiftTypeDisplayName() }}:
              </span>&nbsp;
              {{ formatShortDate(shift.start_time) }}
              <span class="separator">|</span>
              <span class="supervisor-section">
                Supervisor: {{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}
                <button v-if="shift.is_active" @click="showChangeSupervisorModal" class="btn-edit-supervisor" title="Change Supervisor">
                  <EditIcon class="edit-icon" />
                </button>
              </span>
              <span v-if="!shift.is_active" class="archived-badge">Archived</span>
            </h2>
          </div>
          
          <div class="shift-actions">
            <button 
              v-if="shift.is_active" 
              @click="confirmEndShift" 
              class="btn btn-danger"
            >
              End Shift
            </button>
            <button 
              v-else 
              @click="navigateToHome" 
              class="btn btn-secondary"
            >
              Back to Home
            </button>
          </div>
          
          <!-- End Shift Confirmation -->
          <div v-if="showEndShiftConfirm" class="confirmation-box">
            <p>Are you sure you want to end this shift? This will archive the shift and all its tasks.</p>
            <div class="confirmation-actions">
              <button @click="endShift" class="btn btn-danger" :disabled="endingShift">
                {{ endingShift ? 'Ending...' : 'Yes, End Shift' }}
              </button>
              <button @click="cancelEndShift" class="btn btn-secondary" :disabled="endingShift">
                Cancel
              </button>
            </div>
          </div>
        </div>
        
        <!-- Removed the old action bar and moved Add Task button to floating action button -->
        
        <!-- Tabs Section -->
        <div class="card">
          <!-- Activity Sheet Button -->
          <button 
            v-if="shift && allTasks.length > 0"
            @click="showActivitySheet" 
            class="btn btn-primary activity-sheet-btn"
            title="View and print activity sheet"
          >
            Activity Sheet
          </button>
          
          <div class="tabs">
            <AnimatedTabs
              v-model="activeTabId"
              :tabs="formattedTabs"
              @tab-change="handleTabChange"
            >
              <template #shiftSetup>
                <ShiftSetupTabContent 
                  :shift-id="shift.id" 
                  :shift-type="determineAreaCoverType(shift)"
                />
              </template>
              <template #tasks>
                <TasksTabContent 
                  :shift-id="shift.id"
                  @edit-task="editTask"
                  @mark-task-completed="markTaskCompleted"
                  @mark-task-pending="markTaskPending"
                />
              </template>
            </AnimatedTabs>
          </div>
        </div>
      </template>
      
      <!-- Add/Edit Task Modal -->
      <div v-if="showTaskModal" class="modal">
        <motion.div class="modal-backdrop"
          :initial="{ opacity: 0 }"
          :animate="{ opacity: 1 }"
          :exit="isClosing ? { opacity: 0 } : {}"
          :transition="{ duration: 0.3 }"
        ></motion.div>
        <motion.div class="modal-content"
          :initial="{ y: '100%', opacity: 0 }"
          :animate="{ y: '0%', opacity: 1 }"
          :exit="isClosing ? { y: '100%', opacity: 0 } : {}"
          :transition="{ 
            type: 'tween',
            ease: 'easeInOut',
            duration: 0.3
          }"
        >
          <div class="modal-header">
            <h2>{{ isEditingTask ? 'Edit Task' : 'Add New Task' }}</h2>
            <button @click="closeTaskModal" class="close-button">&times;</button>
          </div>
          
          <div class="modal-body">
            <div class="form-grid">
              <!-- Task Type -->
              <div class="form-group">
                <label for="taskType">Task Type</label>
                <select 
                  id="taskType" 
                  v-model="taskForm.taskTypeId" 
                  class="form-control"
                  :class="{ 'field-auto-populated': taskTypeAutoPopulated }"
                  @change="loadTaskItems"
                >
                  <option value="">Select a task type</option>
                  <option v-for="type in taskTypes" :key="type.id" :value="type.id">
                    {{ type.name }}
                  </option>
                </select>
              </div>
              
              <!-- From -->
              <div class="form-group">
                <label for="originDepartment">From</label>
                <select 
                  id="originDepartment" 
                  v-model="taskForm.originDepartmentId" 
                  class="form-control"
                  :class="{ 'field-auto-populated': originFieldAutoPopulated }"
                >
                  <option value="">Select origin department (optional)</option>
                  
                  <!-- Frequent departments (if any) -->
                  <optgroup v-if="frequentDepartments.length > 0" label="Frequent Departments">
                    <option v-for="dept in frequentDepartments" :key="`freq-${dept.id}`" :value="dept.id">
                      {{ dept.name }}
                    </option>
                  </optgroup>
                  
                  <!-- All departments -->
                  <optgroup v-if="frequentDepartments.length > 0" label="All Departments">
                    <option v-for="dept in regularDepartments" :key="dept.id" :value="dept.id">
                      {{ dept.name }}
                    </option>
                  </optgroup>
                  
                  <!-- If no frequent departments, just show all departments without grouping -->
                  <template v-if="frequentDepartments.length === 0">
                    <option v-for="dept in sortedDepartments" :key="dept.id" :value="dept.id">
                      {{ dept.name }}
                    </option>
                  </template>
                </select>
              </div>
              
              <!-- To -->
              <div class="form-group">
                <label for="destinationDepartment">To</label>
                <select 
                  id="destinationDepartment" 
                  v-model="taskForm.destinationDepartmentId" 
                  class="form-control"
                  :class="{ 'field-auto-populated': destinationFieldAutoPopulated }"
                >
                  <option value="">Select destination department (optional)</option>
                  
                  <!-- Frequent departments (if any) -->
                  <optgroup v-if="frequentDepartments.length > 0" label="Frequent Departments">
                    <option v-for="dept in frequentDepartments" :key="`freq-${dept.id}`" :value="dept.id">
                      {{ dept.name }}
                    </option>
                  </optgroup>
                  
                  <!-- All departments -->
                  <optgroup v-if="frequentDepartments.length > 0" label="All Departments">
                    <option v-for="dept in regularDepartments" :key="dept.id" :value="dept.id">
                      {{ dept.name }}
                    </option>
                  </optgroup>
                  
                  <!-- If no frequent departments, just show all departments without grouping -->
                  <template v-if="frequentDepartments.length === 0">
                    <option v-for="dept in sortedDepartments" :key="dept.id" :value="dept.id">
                      {{ dept.name }}
                    </option>
                  </template>
                </select>
              </div>
              
              <!-- Task Item -->
              <div class="form-group">
                <label for="taskItem">Task Item</label>
                <select 
                  id="taskItem" 
                  v-model="taskForm.taskItemId" 
                  class="form-control"
                  :class="{ 'field-auto-populated': taskItemAutoPopulated }"
                  :disabled="!taskForm.taskTypeId || loadingTaskItems"
                >
                  <option value="">{{ loadingTaskItems ? 'Loading items...' : 'Select a task item' }}</option>
                  <option v-for="item in taskItems" :key="item.id" :value="item.id">
                    {{ item.name }}{{ item.is_regular ? ' (Regular)' : '' }}
                  </option>
                </select>
              </div>
              
              <!-- Porter -->
              <div class="form-group">
                <label for="porter">Porter</label>
                <select id="porter" v-model="taskForm.porterId" class="form-control">
                  <option value="">Select porter (optional)</option>
                  <option v-for="porter in porters" :key="porter.id" :value="porter.id">
                    {{ porter.first_name }} {{ porter.last_name }}
                  </option>
                </select>
              </div>
              
              <!-- Status buttons removed from here and moved to footer -->
            </div>
            
            <!-- Time fields wrapper moved inside modal-body -->
            <div class="time-fields-wrapper">
              <button 
                type="button"
                @click="toggleTimeFields" 
                class="timing-toggle-btn"
                :class="{ 'expanded': showTimeFields }"
              >
                <ClockIcon class="timing-toggle-icon" :size="20" />
              </button>
              
              <!-- Time fields container -->
              <motion.div class="time-fields-container" 
                :class="{ 'visible': showTimeFields }"
                :initial="{ height: 0, opacity: 0.5 }"
                :animate="showTimeFields ? { height: 'auto', opacity: 1 } : { height: 0, opacity: 0.5 }"
                :transition="{ 
                  type: 'tween',
                  ease: 'easeInOut',
                  duration: 0.25
                }"
              >
                <!-- Allocated -->
                <div class="form-group">
                  <label for="timeAllocated">Allocated</label>
                  <input 
                    type="time" 
                    id="timeAllocated" 
                    v-model="taskForm.timeAllocated" 
                    class="form-control"
                  />
                </div>
                
                <!-- Received -->
                <div class="form-group">
                  <label for="timeReceived">Received</label>
                  <input 
                    type="time" 
                    id="timeReceived" 
                    v-model="taskForm.timeReceived" 
                    class="form-control"
                  />
                </div>
                
                <!-- Exp. Completion -->
                <div class="form-group">
                  <label for="timeCompleted">Exp. Completion</label>
                  <input 
                    type="time" 
                    id="timeCompleted" 
                    v-model="taskForm.timeCompleted" 
                    class="form-control"
                  />
                </div>
              </motion.div>
            </div>
          </div>
          
          <!-- Different footer for new vs edit task -->
          <div class="modal-footer">
            <!-- Edit mode: Update | Status Change | Cancel -->
            <template v-if="isEditingTask">
              <button 
                @click="closeTaskModal" 
                class="btn btn-secondary" 
                :disabled="processingTask"
              >
                Cancel
              </button>
              <!-- Show "Pending" button only for completed tasks -->
              <button 
                v-if="taskForm.status === 'completed'"
                @click="taskForm.status = 'pending'; saveTask()" 
                class="btn pending-btn" 
                :disabled="processingTask"
              >
                {{ processingTask ? 'Updating...' : 'Mark Pending' }}
              </button>
              <!-- Show "Completed" button only for pending tasks -->
              <button 
                v-if="taskForm.status === 'pending'"
                @click="taskForm.status = 'completed'; saveTask()" 
                class="btn completed-btn" 
                :disabled="processingTask"
              >
                {{ processingTask ? 'Updating...' : 'Mark Completed' }}
              </button>
              <button 
                @click="saveTask()" 
                class="btn btn-primary" 
                :disabled="!canSaveTask || processingTask"
              >
                {{ processingTask ? 'Updating...' : 'Update Task' }}
              </button>
            </template>
            
            <!-- Add mode: Cancel | Pending | Completed -->
            <template v-else>
              <button 
                @click="closeTaskModal" 
                class="btn btn-secondary" 
                :disabled="processingTask"
              >
                Cancel
              </button>
              <button 
                @click="saveTaskWithStatus('pending')" 
                class="btn pending-btn" 
                :disabled="!canSaveTask || processingTask"
              >
                {{ processingTask && taskForm.status === 'pending' ? 'Saving...' : 'Pending' }}
              </button>
              <button 
                @click="saveTaskWithStatus('completed')" 
                class="btn completed-btn" 
                :disabled="!canSaveTask || processingTask"
              >
                {{ processingTask && taskForm.status === 'completed' ? 'Saving...' : 'Completed' }}
              </button>
            </template>
          </div>
          
          <div v-if="taskFormError" class="error-message">
            {{ taskFormError }}
          </div>
        </motion.div>
      </div>
      
      <!-- Change Supervisor Modal -->
      <div v-if="showSupervisorModal" class="modal">
        <div class="modal-content supervisor-modal-content">
          <div class="modal-header">
            <h2>Change Shift Supervisor</h2>
            <button @click="closeSupervisorModal" class="close-button">&times;</button>
          </div>
          
          <div class="modal-body">
            <p class="current-supervisor">
              Current Supervisor: 
              <strong>{{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}</strong>
            </p>
            
            <div class="form-group">
              <label for="newSupervisor">New Supervisor</label>
              <select 
                id="newSupervisor" 
                v-model="selectedSupervisor" 
                class="form-control"
                :disabled="changingSupervisor"
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
          </div>
          
          <div class="modal-footer">
            <button 
              @click="closeSupervisorModal" 
              class="btn btn-secondary" 
              :disabled="changingSupervisor"
            >
              Cancel
            </button>
            <button 
              @click="saveSupervisor" 
              class="btn btn-primary" 
              :disabled="!selectedSupervisor || changingSupervisor"
            >
              {{ changingSupervisor ? 'Saving...' : 'Save Changes' }}
            </button>
          </div>
        </div>
      </div>

      
      <!-- Floating Action Button for Adding Tasks -->
      <div class="floating-action-container">
        <button 
          v-if="shift && shift.is_active" 
          @click="showAddTaskModal" 
          class="floating-action-button"
          :class="{ 'disabled': !isShiftAccessible }"
          :disabled="!isShiftAccessible"
          :title="isShiftAccessible ? 'Add Task' : 'Cannot add tasks now - only available during shift or 1 hour before'"
        >
          <span class="plus-icon">+</span>
          <span class="button-text">New Task</span>
        </button>
        
        <!-- Non-accessible shift message -->
        <div v-if="shift && shift.is_active && !isShiftAccessible" class="date-warning">
          Tasks can only be added during the shift or 1 hour before it starts
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { motion } from 'motion-v';
import { useRoute, useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useTaskTypesStore } from '../stores/taskTypesStore';
import { useLocationsStore } from '../stores/locationsStore';
import { useSettingsStore } from '../stores/settingsStore';
import AnimatedTabs from '../components/shared/AnimatedTabs.vue';
import ShiftSetupTabContent from '../components/tabs/tab-contents/ShiftSetupTabContent.vue';
import TasksTabContent from '../components/tabs/tab-contents/TasksTabContent.vue';
import EditIcon from '../components/icons/EditIcon.vue';
import ClockIcon from '../components/icons/ClockIcon.vue';

const route = useRoute();
const router = useRouter();
const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const taskTypesStore = useTaskTypesStore();
const locationsStore = useLocationsStore();
const settingsStore = useSettingsStore();

// Local state
const loading = ref(true);
const activeTab = ref('pending'); // For task list tabs (pending/completed)
const activeTabId = ref('tasks'); // For main view tabs (shift setup/tasks)
const showSupervisorModal = ref(false);
const changingSupervisor = ref(false);
const selectedSupervisor = ref('');
const tabs = [
  { id: 'tasks', label: 'Tasks' },
  { id: 'shiftSetup', label: 'Shift Setup' }
];

// Tab animation states
const tabChangeDirection = ref(0);
const showEndShiftConfirm = ref(false);
const endingShift = ref(false);
const loadingTaskItems = ref(false);
const updatingTask = ref(false);
const taskItems = ref([]);

// Format tabs for AnimatedTabs component
const formattedTabs = computed(() => {
  return tabs.map(tab => ({
    id: tab.id,
    label: tab.label,
    count: tab.id === 'tasks' ? totalTasksCount.value : undefined
  }));
});

// Handle tab change from AnimatedTabs component
function handleTabChange(tabId) {
  // Calculate direction of tab change
  const oldIndex = tabs.findIndex(tab => tab.id === activeTabId.value);
  const newIndex = tabs.findIndex(tab => tab.id === tabId);
  
  if (oldIndex !== -1 && newIndex !== -1) {
    tabChangeDirection.value = newIndex > oldIndex ? 1 : -1;
  } else {
    tabChangeDirection.value = 0;
  }
}

// Task modal state
const showTaskModal = ref(false);
const isEditingTask = ref(false);
const editingTaskId = ref(null);
const editingTask = ref(null);
const processingTask = ref(false);
const taskFormError = ref('');
const showTimeFields = ref(false); // Controls visibility of time fields
const isClosing = ref(false); // Track closing state for exit animations
const timeFieldsHeight = ref(0); // Track height for time fields animation

// Import nextTick for DOM manipulation after state changes
import { nextTick } from 'vue';

// Handle time fields visibility toggle
function toggleTimeFields() {
  // Simply toggle the state, animation is handled by motion.div
  showTimeFields.value = !showTimeFields.value;
  
  // If showing, add visible class for padding after a slight delay to allow animation
  if (showTimeFields.value) {
    setTimeout(() => {
      const container = document.querySelector('.time-fields-container');
      if (container) container.classList.add('visible');
    }, 300);
  } else {
    // Remove visible class immediately when hiding
    const container = document.querySelector('.time-fields-container');
    if (container) container.classList.remove('visible');
  }
}

// Track fields auto-population for visual feedback
const originFieldAutoPopulated = ref(false);
const destinationFieldAutoPopulated = ref(false);
const taskItemAutoPopulated = ref(false);
const taskTypeAutoPopulated = ref(false);

// Track which fields have been touched first to prevent circular auto-population
const taskTypeFieldTouched = ref(false);
const departmentFieldTouched = ref(false);

// Task form data
const taskForm = ref({
  taskTypeId: '',
  taskItemId: '',
  originDepartmentId: '',
  destinationDepartmentId: '',
  porterId: '',
  status: 'pending',
  timeReceived: '',
  timeAllocated: '',
  timeCompleted: ''
});

// Computed properties
const shift = computed(() => shiftsStore.currentShift);
const pendingTasks = computed(() => shiftsStore.pendingTasks);
const completedTasks = computed(() => shiftsStore.completedTasks);
const allTasks = computed(() => [...pendingTasks.value, ...completedTasks.value]);
const totalTasksCount = computed(() => pendingTasks.value.length + completedTasks.value.length);
// Check if tasks can be added to this shift (current date and within time window)
const isShiftAccessible = computed(() => {
  if (!shift.value || !shift.value.start_time) return false;
  
  const shiftDate = new Date(shift.value.start_time);
  const today = new Date();
  const shiftType = shift.value.shift_type;
  
  // First check if dates match
  const isSameDate = shiftDate.getDate() === today.getDate() && 
                     shiftDate.getMonth() === today.getMonth() && 
                     shiftDate.getFullYear() === today.getFullYear();
  
  if (!isSameDate) return false; // Different date, not accessible
  
  // Get shift times from settings
  const startTimeStr = settingsStore.shiftDefaults[shiftType]?.startTime;
  const endTimeStr = settingsStore.shiftDefaults[shiftType]?.endTime;
  
  if (!startTimeStr || !endTimeStr) return false; // No time settings found
  
  // Convert times to minutes for easier comparison
  const [startHours, startMinutes] = startTimeStr.split(':').map(Number);
  const [endHours, endMinutes] = endTimeStr.split(':').map(Number);
  
  const startTimeInMinutes = startHours * 60 + startMinutes;
  const endTimeInMinutes = endHours * 60 + endMinutes;
  
  // Calculate time 1 hour before shift starts
  const oneHourBeforeStartInMinutes = startTimeInMinutes - 60;
  
  // Get current time in minutes
  const currentHours = today.getHours();
  const currentMinutes = today.getMinutes();
  const currentTimeInMinutes = currentHours * 60 + currentMinutes;
  
  // Check if night shift (spans midnight)
  const isNightShift = endTimeInMinutes < startTimeInMinutes;
  
  if (isNightShift) {
    // For night shifts that span midnight
    return currentTimeInMinutes >= oneHourBeforeStartInMinutes || 
           currentTimeInMinutes < endTimeInMinutes;
  } else {
    // For day shifts
    return currentTimeInMinutes >= oneHourBeforeStartInMinutes && 
           currentTimeInMinutes < endTimeInMinutes;
  }
});
const porters = computed(() => {
  // Only show porters from the shift pool who are "Runners" (no assignments)
  return shiftsStore.shiftPorterPool
    .filter(entry => {
      // Get area cover assignments for this porter
      const areaCoverAssignments = shiftsStore.shiftAreaCoverPorterAssignments.filter(
        a => a.porter_id === entry.porter_id
      );
      
      // Get service assignments for this porter
      const serviceAssignments = shiftsStore.shiftSupportServicePorterAssignments.filter(
        a => a.porter_id === entry.porter_id
      );
      
      // Only include porters with no assignments (Runners)
      return areaCoverAssignments.length === 0 && serviceAssignments.length === 0;
    })
    .map(p => p.porter);
});
const taskTypes = computed(() => taskTypesStore.taskTypes);
// Supervisors list for the supervisor change modal
const supervisors = computed(() => staffStore.sortedSupervisors);
// Regular departments list for dropdowns
const departments = computed(() => locationsStore.departments);

// Get only frequent departments for task form dropdowns
const frequentDepartments = computed(() => locationsStore.frequentDepartments);

// Get regular (non-frequent) departments for task form dropdowns
const regularDepartments = computed(() => {
  return locationsStore.departments
    .filter(dept => !dept.is_frequent)
    .sort((a, b) => a.name.localeCompare(b.name));
});

// All departments, properly sorted for dropdowns when no frequent departments exist
const sortedDepartments = computed(() => {
  return [...locationsStore.departments].sort((a, b) => a.name.localeCompare(b.name));
});
const canSaveTask = computed(() => {
  // For a new task, we need a task item
  if (!isEditingTask.value) {
    return taskForm.value.taskItemId;
  }
  // For editing, we always allow saving since the form is pre-populated
  return true;
});

// Load data on component mount
onMounted(async () => {
  loading.value = true;
  console.log('ShiftManagementView mounted - loading shift data');
  
  // Initialize the tab indicator position
  nextTick(() => {
    updateIndicatorPosition();
  });
  
  // Update indicator position on window resize
  window.addEventListener('resize', updateIndicatorPosition);
  
  try {
    const shiftId = route.params.id;
    
    // Load shift and its tasks
    await shiftsStore.fetchShiftById(shiftId);
    console.log('Shift loaded:', shiftsStore.currentShift?.id);
    
    if (shiftsStore.currentShift) {
      // Load shift tasks
      await shiftsStore.fetchShiftTasks(shiftId);
      
    // Load area cover assignments for this shift
    console.log('Loading area cover assignments for shift:', shiftId);
    await shiftsStore.fetchShiftAreaCover(shiftId);
    console.log(`Loaded ${shiftsStore.shiftAreaCoverAssignments.length} area cover assignments`);
    
    // Log all area cover assignments in detail
    if (shiftsStore.shiftAreaCoverAssignments.length > 0) {
      console.log('Area cover assignments details:');
      shiftsStore.shiftAreaCoverAssignments.forEach(assignment => {
        console.log(`- Department: ${assignment.department?.name || 'Unknown'} (ID: ${assignment.department_id})`);
        console.log(`  Time: ${assignment.start_time} - ${assignment.end_time}`);
        console.log(`  For shift: ${assignment.shift_id}`);
      });
    } else {
      console.log('No area cover assignments were loaded!');
      
      // Check the defaults in the area cover store
      const { useAreaCoverStore } = await import('../stores/areaCoverStore');
      const areaCoverStore = useAreaCoverStore();
      await areaCoverStore.initialize();
      
      // Log the shift type
      console.log('Current shift type:', shift.value.shift_type);
      
      // Check if defaults exist for this shift type
      const shiftType = shift.value.shift_type;
      const defaultAssignments = areaCoverStore[`${shiftType}Assignments`] || [];
      console.log(`Found ${defaultAssignments.length} default ${shiftType} assignments`);
      
      if (defaultAssignments.length > 0) {
        console.log('Default assignments:');
        defaultAssignments.forEach(assignment => {
          console.log(`- Department: ${assignment.department?.name || 'Unknown'} (ID: ${assignment.department_id})`);
        });
        
        // Try to re-initialize the area cover from defaults
        console.log('Attempting to re-initialize area cover from defaults...');
        await shiftsStore.setupShiftAreaCoverFromDefaults(shiftId, shiftType);
        
        // Check if it worked
        await shiftsStore.fetchShiftAreaCover(shiftId);
        console.log(`After re-init: ${shiftsStore.shiftAreaCoverAssignments.length} area cover assignments`);
      }
    }
    
    // Load support service assignments for this shift
    console.log('Loading support service assignments for shift:', shiftId);
    await shiftsStore.fetchShiftSupportServices(shiftId);
    console.log(`Loaded ${shiftsStore.shiftSupportServiceAssignments.length} support service assignments`);
    
    // Log all support service assignments in detail
    if (shiftsStore.shiftSupportServiceAssignments.length > 0) {
      console.log('Support service assignments details:');
      shiftsStore.shiftSupportServiceAssignments.forEach(assignment => {
        console.log(`- Service: ${assignment.service?.name || 'Unknown'} (ID: ${assignment.service_id})`);
        console.log(`  Time: ${assignment.start_time} - ${assignment.end_time}`);
      });
      
      // Load porter assignments for service assignments
      console.log('Loading porter assignments for service assignments...');
      for (const assignment of shiftsStore.shiftSupportServiceAssignments) {
        // The porter assignments are loaded automatically in fetchShiftSupportServices
        const porterAssignments = shiftsStore.getPorterAssignmentsByServiceId(assignment.id);
        console.log(`Service ${assignment.service?.name}: ${porterAssignments.length} porter assignments`);
      }
    }
    
    // Load porter pool
    await shiftsStore.fetchShiftPorterPool(shiftId);
    console.log(`Loaded ${shiftsStore.shiftPorterPool.length} porters in pool`);
    }
    
    // Load supporting data for task management
    await Promise.all([
      staffStore.fetchPorters(),
      staffStore.fetchPorterAbsences(), // Explicitly load porter absences
      taskTypesStore.fetchTaskTypes(),
      locationsStore.fetchDepartments(),
      settingsStore.loadSettings()
    ]);
  } catch (error) {
    console.error('Error loading shift data:', error);
  } finally {
    loading.value = false;
    console.log('ShiftManagementView loading complete');
  }
});

// Watch route param changes to reload data
watch(() => route.params.id, async (newId, oldId) => {
  if (newId && newId !== oldId) {
    loading.value = true;
    await shiftsStore.fetchShiftById(newId);
    if (shiftsStore.currentShift) {
      await shiftsStore.fetchShiftTasks(newId);
    }
    loading.value = false;
  }
});

// Watch for task type changes to set the taskTypeFieldTouched flag
watch(() => taskForm.value.taskTypeId, (newTaskTypeId) => {
  if (newTaskTypeId) {
    // Mark that task type was touched first
    taskTypeFieldTouched.value = true;
  }
});

// Watch for task item changes to auto-populate department fields
watch(() => taskForm.value.taskItemId, (newTaskItemId) => {
  if (newTaskItemId && taskTypeFieldTouched.value && !departmentFieldTouched.value) {
    // Only auto-populate departments if task type/item was selected first
    // and department hasn't been touched yet
    checkTaskItemDepartmentAssignments(newTaskItemId);
  }
});

// Watch for origin department changes to auto-populate task type and task item
watch(() => taskForm.value.originDepartmentId, (newDepartmentId) => {
  if (!newDepartmentId) return;
  
  console.log('Origin department changed to:', newDepartmentId);
  
  // Mark that department was touched
  departmentFieldTouched.value = true;
  
  // Only auto-populate task type/item if department was touched first
  // and task type hasn't been touched yet
  if (!taskTypeFieldTouched.value) {
    // First, check task type assignments where this department is an origin
    // This is our single source of truth
    let foundAssignment = false;
    
    // Make sure task type assignments are loaded
    taskTypesStore.fetchTypeAssignments().then(() => {
      // Find assignments where this department is an origin
      const typeAssignments = taskTypesStore.typeAssignments.filter(
        a => a.department_id === newDepartmentId && a.is_origin
      );
      
      console.log('Task type assignments for department:', typeAssignments);
      
      if (typeAssignments.length > 0) {
        // Use the first assignment
        const typeAssignment = typeAssignments[0];
        console.log('Setting task type to:', typeAssignment.task_type_id);
        
        // Set task type ID
        taskForm.value.taskTypeId = typeAssignment.task_type_id;
        foundAssignment = true;
        
        // Visual feedback for auto-population
        taskTypeAutoPopulated.value = true;
        // Reset the flag after animation completes
        setTimeout(() => {
          taskTypeAutoPopulated.value = false;
        }, 1500);
        
        // Load task items for this type and auto-select regular item
        loadTaskItems().then(() => {
          // Look for regular item
          const regularItem = taskItems.value.find(item => item.is_regular);
          if (regularItem) {
            console.log('Setting task item to regular item:', regularItem.id);
            taskForm.value.taskItemId = regularItem.id;
            
            // Visual feedback for auto-population
            taskItemAutoPopulated.value = true;
            setTimeout(() => {
              taskItemAutoPopulated.value = false;
            }, 1500);
          }
          
          // Now look for a destination department in task type assignments
          const destinationAssignment = taskTypesStore.typeAssignments.find(
            a => a.task_type_id === typeAssignment.task_type_id && a.is_destination
          );
          
          if (destinationAssignment) {
            console.log('Setting destination department to:', destinationAssignment.department_id);
            taskForm.value.destinationDepartmentId = destinationAssignment.department_id;
            
            // Visual feedback for auto-population
            destinationFieldAutoPopulated.value = true;
            setTimeout(() => {
              destinationFieldAutoPopulated.value = false;
            }, 1500);
          }
        });
      }
      
      // Fallback to department task assignment if no type assignment found
      if (!foundAssignment) {
        // Check if this department has a task assignment
        const assignment = locationsStore.getDepartmentTaskAssignment(newDepartmentId);
        console.log('Department task assignment:', assignment);
        
        if (assignment && assignment.task_type_id) {
          console.log('Setting task type to:', assignment.task_type_id);
          
          // Set task type ID
          taskForm.value.taskTypeId = assignment.task_type_id;
          
          // Visual feedback for auto-population
          taskTypeAutoPopulated.value = true;
          // Reset the flag after animation completes
          setTimeout(() => {
            taskTypeAutoPopulated.value = false;
          }, 1500);
          
          // Load task items for this type
          loadTaskItems().then(() => {
            // After loading items, set task item if specified in assignment
            if (assignment.task_item_id) {
              console.log('Setting task item to:', assignment.task_item_id);
              
              // Check if this task item exists in the loaded items
              const itemExists = taskItems.value.some(item => item.id === assignment.task_item_id);
              
              if (itemExists) {
                taskForm.value.taskItemId = assignment.task_item_id;
                
                // Visual feedback for auto-population
                taskItemAutoPopulated.value = true;
                setTimeout(() => {
                  taskItemAutoPopulated.value = false;
                }, 1500);
              }
            }
          });
        } else {
          // Check task type assignments from taskTypesStore as a last resort
          checkTaskTypeDepartmentAssignments(taskForm.value.taskTypeId);
        }
      }
    });
  }
});

  // Methods
function setActiveTab(tabId) {
  // Calculate direction of tab change
  const oldIndex = tabs.findIndex(tab => tab.id === activeTabId.value);
  const newIndex = tabs.findIndex(tab => tab.id === tabId);
  
  if (oldIndex !== -1 && newIndex !== -1) {
    tabChangeDirection.value = newIndex > oldIndex ? 1 : -1;
  } else {
    tabChangeDirection.value = 0;
  }
  
  activeTabId.value = tabId;
  
  // Update indicator position on next tick
  nextTick(() => {
    updateIndicatorPosition();
  });
}

// Calculate the indicator position based on the active tab
function updateIndicatorPosition() {
  if (!tabRefs.value || tabRefs.value.length === 0 || !tabsHeaderRef.value) return;
  
  const activeIndex = tabs.findIndex(tab => tab.id === activeTabId.value);
  if (activeIndex === -1 || !tabRefs.value[activeIndex]) return;
  
  // The ref might be an object with a tabRef property, or it might be a direct DOM ref
  // Handle both cases safely
  const activeTabRef = tabRefs.value[activeIndex];
  if (!activeTabRef) return;
  
  // Get the actual DOM element, whether from tabRef property or direct ref
  const activeTabElement = activeTabRef.tabRef || activeTabRef.$el || activeTabRef;
  if (!activeTabElement || typeof activeTabElement.getBoundingClientRect !== 'function') return;
  
  // Make sure tabsHeaderRef exists and is a DOM element
  if (!tabsHeaderRef.value || typeof tabsHeaderRef.value.getBoundingClientRect !== 'function') return;
  
  const tabHeaderRect = tabsHeaderRef.value.getBoundingClientRect();
  const activeTabRect = activeTabElement.getBoundingClientRect();
  
  // Calculate position relative to the tab header
  indicatorPosition.value = activeTabRect.left - tabHeaderRect.left;
  indicatorWidth.value = activeTabRect.width;
}

function navigateToHome() {
  router.push('/');
}

function showActivitySheet() {
  // Navigate to the activity sheet view
  router.push(`/shift/${shift.value.id}/activity-sheet`);
}


function confirmEndShift() {
  showEndShiftConfirm.value = true;
}

function cancelEndShift() {
  showEndShiftConfirm.value = false;
}

async function endShift() {
  if (!shift.value || endingShift.value) return;
  
  endingShift.value = true;
  
  try {
    await shiftsStore.endShift(shift.value.id);
    showEndShiftConfirm.value = false;
    // Navigate back to home after ending the shift
    router.push('/');
  } catch (error) {
    console.error('Error ending shift:', error);
  } finally {
    endingShift.value = false;
  }
}

// Show add task modal
async function showAddTaskModal() {
  isEditingTask.value = false;
  editingTaskId.value = null;
  resetTaskForm();
  
  // Make sure all task type assignments are loaded
  await taskTypesStore.fetchTypeAssignments();
  await taskTypesStore.fetchItemAssignments();
  
  showTaskModal.value = true;
}

// Edit task
function editTask(task) {
  isEditingTask.value = true;
  editingTaskId.value = task.id;
  editingTask.value = task; // Store the full task object for time fields display
  
  // Set up the form with the current task data
  taskForm.value = {
    taskTypeId: task.task_item.task_type_id,
    taskItemId: task.task_item_id,
    originDepartmentId: task.origin_department_id || '',
    destinationDepartmentId: task.destination_department_id || '',
    porterId: task.porter_id || '',
    status: task.status,
    timeReceived: task.time_received ? formatDateTimeForInput(task.time_received) : '',
    timeAllocated: task.time_allocated ? formatDateTimeForInput(task.time_allocated) : '',
    timeCompleted: task.time_completed ? formatDateTimeForInput(task.time_completed) : ''
  };
  
  // If any time field has a value, show the time fields section
  if (task.time_received || task.time_allocated || task.time_completed) {
    showTimeFields.value = true;
  }
  
  // Load task items for this task type
  loadTaskItems();
  
  // Show the modal
  showTaskModal.value = true;
}

// Close task modal
function closeTaskModal() {
  // Set the closing state to trigger exit animations
  isClosing.value = true;
  
  // Wait for animation to complete before hiding the modal
  setTimeout(() => {
    showTaskModal.value = false;
    resetTaskForm();
    isClosing.value = false;
  }, 300); // Match this duration with the exit animation duration
}

// Reset task form
function resetTaskForm() {
  // Get current time
  const now = new Date();
  
  // Calculate time_allocated (+1 minute from now)
  const timeAllocated = new Date(now.getTime() + 60000); // 60000 ms = 1 minute
  
  // Calculate time_completed (random between 15-30 minutes from now)
  const randomMinutes = Math.floor(Math.random() * (30 - 15 + 1)) + 15; // Random between 15-30
  const timeCompleted = new Date(now.getTime() + (randomMinutes * 60000)); // Convert minutes to ms
  
  taskForm.value = {
    taskTypeId: '',
    taskItemId: '',
    originDepartmentId: '',
    destinationDepartmentId: '',
    porterId: '',
    status: 'pending',
    timeReceived: formatDateTimeForInput(now),
    timeAllocated: formatDateTimeForInput(timeAllocated),
    timeCompleted: formatDateTimeForInput(timeCompleted)
  };
  taskItems.value = [];
  taskFormError.value = '';
  showTimeFields.value = false; // Reset time fields visibility
  
  // Reset touch tracking flags
  taskTypeFieldTouched.value = false;
  departmentFieldTouched.value = false;
}

// Load task items for a task type
async function loadTaskItems() {
  if (!taskForm.value.taskTypeId) {
    taskItems.value = [];
    return;
  }
  
  loadingTaskItems.value = true;
  
  try {
    await taskTypesStore.fetchTaskItemsByType(taskForm.value.taskTypeId);
    taskItems.value = taskTypesStore.getTaskItemsByType(taskForm.value.taskTypeId);
    
    // Check for task type department assignments and auto-populate
    // but only if task type was touched first
    if (taskTypeFieldTouched.value && !departmentFieldTouched.value) {
      // Also load task type assignments if they haven't been loaded
      await taskTypesStore.fetchTypeAssignments();
      checkTaskTypeDepartmentAssignments(taskForm.value.taskTypeId);
    }
    
    // Check for regular task item and auto-select it
    const regularItem = taskItems.value.find(item => item.is_regular);
    if (regularItem) {
      console.log('Found regular task item:', regularItem.name, '- auto-selecting');
      taskForm.value.taskItemId = regularItem.id;
      
      // Set the animation flag for visual feedback
      taskItemAutoPopulated.value = true;
      // Reset the flag after animation completes
      setTimeout(() => {
        taskItemAutoPopulated.value = false;
      }, 1500);
    }
  } catch (error) {
    console.error('Error loading task items:', error);
  } finally {
    loadingTaskItems.value = false;
  }
}

// Check for department assignments for a task type and auto-populate form fields
function checkTaskTypeDepartmentAssignments(taskTypeId) {
  if (!taskTypeId) return;
  
  console.log('Checking task type assignments for type ID:', taskTypeId);
  
  // Get the task type name for better logging
  const taskType = taskTypesStore.taskTypes.find(t => t.id === taskTypeId);
  console.log('Task type name:', taskType?.name);
  
  // Only apply default departments if department fields haven't been touched yet
  if (!departmentFieldTouched.value) {
    const assignments = taskTypesStore.getTypeAssignmentsByTypeId(taskTypeId);
    console.log('Found assignments for this task type:', assignments);
    
    // Look for origin department
    const originAssignment = assignments.find(a => a.is_origin);
    console.log('Origin assignment:', originAssignment);
    
    if (originAssignment && !taskForm.value.originDepartmentId) {
      console.log('Setting origin department ID to:', originAssignment.department_id);
      taskForm.value.originDepartmentId = originAssignment.department_id;
      originFieldAutoPopulated.value = true;
      // Reset the flag after animation completes
      setTimeout(() => {
        originFieldAutoPopulated.value = false;
      }, 1500);
    }
    
    // Look for destination department
    const destinationAssignment = assignments.find(a => a.is_destination);
    console.log('Destination assignment:', destinationAssignment);
    
    if (destinationAssignment && !taskForm.value.destinationDepartmentId) {
      console.log('Setting destination department ID to:', destinationAssignment.department_id);
      taskForm.value.destinationDepartmentId = destinationAssignment.department_id;
      destinationFieldAutoPopulated.value = true;
      // Reset the flag after animation completes
      setTimeout(() => {
        destinationFieldAutoPopulated.value = false;
      }, 1500);
    }
  }
}

// Check for department assignments for a task item and auto-populate form fields
function checkTaskItemDepartmentAssignments(taskItemId) {
  if (!taskItemId) return;
  
  console.log('Checking task item assignments for item ID:', taskItemId);
  
  // Get the task item name for better logging
  const taskItem = taskItems.value.find(i => i.id === taskItemId);
  console.log('Task item name:', taskItem?.name);
  
  // Only auto-populate departments if they haven't been touched yet
  if (!departmentFieldTouched.value) {
    const assignments = taskTypesStore.getItemAssignmentsByItemId(taskItemId);
    console.log('Found assignments for this task item:', assignments);
    
    // Look for origin department
    const originAssignment = assignments.find(a => a.is_origin);
    console.log('Origin assignment:', originAssignment);
    
    if (originAssignment) {
      console.log('Setting origin department ID to:', originAssignment.department_id);
      taskForm.value.originDepartmentId = originAssignment.department_id;
      originFieldAutoPopulated.value = true;
      // Reset the flag after animation completes
      setTimeout(() => {
        originFieldAutoPopulated.value = false;
      }, 1500);
    }
    
    // Look for destination department
    const destinationAssignment = assignments.find(a => a.is_destination);
    console.log('Destination assignment:', destinationAssignment);
    
    if (destinationAssignment) {
      console.log('Setting destination department ID to:', destinationAssignment.department_id);
      taskForm.value.destinationDepartmentId = destinationAssignment.department_id;
      destinationFieldAutoPopulated.value = true;
      // Reset the flag after animation completes
      setTimeout(() => {
        destinationFieldAutoPopulated.value = false;
      }, 1500);
    }
  }
}

// Helper function to safely create a valid ISO date string
function createValidDateTimeString(dateStr, timeStr) {
  if (!timeStr) return null;
  
  try {
    // Make sure time format is valid (HH:MM)
    if (!/^\d{1,2}:\d{2}$/.test(timeStr)) {
      console.warn("Invalid time format:", timeStr);
      return null;
    }
    
    // Get current date if no date string provided
    const currentDate = new Date().toISOString().split('T')[0];
    const baseDate = dateStr || currentDate;
    
    // Create the datetime string
    const dateTimeStr = `${baseDate}T${timeStr}:00`;
    
    // Validate by creating a date object and checking if it's valid
    const testDate = new Date(dateTimeStr);
    if (isNaN(testDate.getTime())) {
      console.warn("Invalid date created:", dateTimeStr);
      return null;
    }
    
    return dateTimeStr;
  } catch (error) {
    console.error("Error creating date string:", error);
    return null;
  }
}

// Save task (add or update)
async function saveTask() {
  if (!canSaveTask.value || processingTask.value) return;
  
  processingTask.value = true;
  taskFormError.value = '';
  
  try {
    // Transform form data to match the API requirements
    const taskData = {
      taskItemId: taskForm.value.taskItemId,
      porterId: taskForm.value.porterId || null,
      originDepartmentId: taskForm.value.originDepartmentId || null,
      destinationDepartmentId: taskForm.value.destinationDepartmentId || null,
      status: taskForm.value.status
    };
    
    // Get base dates for each time field if we're editing
    let receivedBaseDate, allocatedBaseDate, completedBaseDate;
    
    // Helper function to safely extract date part from a date string
    function extractDatePart(dateString) {
      if (!dateString) return null;
      
      // If it's already in YYYY-MM-DD format, use it directly
      if (typeof dateString === 'string' && /^\d{4}-\d{2}-\d{2}/.test(dateString)) {
        return dateString.split('T')[0];
      }
      
      // Otherwise, try to create a date and extract the date part
      try {
        const date = new Date(dateString);
        
        // Check if date is valid before calling toISOString()
        if (isNaN(date.getTime())) {
          return null;
        }
        
        return date.toISOString().split('T')[0];
      } catch (e) {
        return null;
      }
    }
    
    // Silently handle date extraction without console errors
    receivedBaseDate = isEditingTask.value && editingTask.value.time_received 
      ? extractDatePart(editingTask.value.time_received)
      : null;
      
    allocatedBaseDate = isEditingTask.value && editingTask.value.time_allocated
      ? extractDatePart(editingTask.value.time_allocated)
      : null;
      
    completedBaseDate = isEditingTask.value && editingTask.value.time_completed
      ? extractDatePart(editingTask.value.time_completed)
      : null;
      
    // Fallback to current date if extraction failed
    const currentDate = new Date().toISOString().split('T')[0];
    receivedBaseDate = receivedBaseDate || currentDate;
    allocatedBaseDate = allocatedBaseDate || currentDate;
    completedBaseDate = completedBaseDate || currentDate;
    
    // Only include time fields if they are provided and valid
    const receivedDateTime = createValidDateTimeString(receivedBaseDate, taskForm.value.timeReceived);
    if (receivedDateTime) {
      taskData.time_received = receivedDateTime;
    }
    
    const allocatedDateTime = createValidDateTimeString(allocatedBaseDate, taskForm.value.timeAllocated);
    if (allocatedDateTime) {
      taskData.time_allocated = allocatedDateTime;
    }
    
    const completedDateTime = createValidDateTimeString(completedBaseDate, taskForm.value.timeCompleted);
    if (completedDateTime) {
      taskData.time_completed = completedDateTime;
    }
    
    let result;
    
    if (isEditingTask.value) {
      // Update existing task
      result = await shiftsStore.updateTask(editingTaskId.value, taskData);
    } else {
      // Add new task
      result = await shiftsStore.addTaskToShift(shift.value.id, taskData);
    }
    
    if (result) {
      // Reset form and close modal
      resetTaskForm();
      showTaskModal.value = false;
    } else {
      taskFormError.value = shiftsStore.error || `Failed to ${isEditingTask.value ? 'update' : 'add'} task`;
    }
  } catch (error) {
    console.error(`Error ${isEditingTask.value ? 'updating' : 'adding'} task:`, error);
    
    // Provide more helpful error messages for time-related errors
    if (error instanceof RangeError && error.message.includes('Invalid time value')) {
      taskFormError.value = 'Invalid time format. Please check all time fields.';
    } else {
      taskFormError.value = 'An unexpected error occurred';
    }
  } finally {
    processingTask.value = false;
  }
}

async function markTaskCompleted(taskId) {
  if (updatingTask.value) return;
  
  updatingTask.value = true;
  
  try {
    await shiftsStore.updateTaskStatus(taskId, 'completed');
  } catch (error) {
    console.error('Error marking task as completed:', error);
  } finally {
    updatingTask.value = false;
  }
}

async function markTaskPending(taskId) {
  if (updatingTask.value) return;
  
  updatingTask.value = true;
  
  try {
    await shiftsStore.updateTaskStatus(taskId, 'pending');
  } catch (error) {
    console.error('Error marking task as pending:', error);
  } finally {
    updatingTask.value = false;
  }
}

// Save task with specific status
async function saveTaskWithStatus(status) {
  if (!canSaveTask.value || processingTask.value) return;
  
  // Set the status
  taskForm.value.status = status;
  
  // Process the save
  processingTask.value = true;
  taskFormError.value = '';
  
  try {
    // Transform form data to match the API requirements
    const taskData = {
      taskItemId: taskForm.value.taskItemId,
      porterId: taskForm.value.porterId || null,
      originDepartmentId: taskForm.value.originDepartmentId || null,
      destinationDepartmentId: taskForm.value.destinationDepartmentId || null,
      status: taskForm.value.status
    };
    
    // Only include time fields if they are provided and valid
    const receivedDateTime = createValidDateTimeString(null, taskForm.value.timeReceived);
    if (receivedDateTime) {
      taskData.time_received = receivedDateTime;
    }
    
    const allocatedDateTime = createValidDateTimeString(null, taskForm.value.timeAllocated);
    if (allocatedDateTime) {
      taskData.time_allocated = allocatedDateTime;
    }
    
    const completedDateTime = createValidDateTimeString(null, taskForm.value.timeCompleted);
    if (completedDateTime) {
      taskData.time_completed = completedDateTime;
    }
    
    // Add new task
    const result = await shiftsStore.addTaskToShift(shift.value.id, taskData);
    
    if (result) {
      // Reset form and close modal
      resetTaskForm();
      showTaskModal.value = false;
    } else {
      taskFormError.value = shiftsStore.error || 'Failed to add task';
    }
  } catch (error) {
    console.error('Error adding task:', error);
    
    // Provide more helpful error messages for time-related errors
    if (error instanceof RangeError && error.message.includes('Invalid time value')) {
      taskFormError.value = 'Invalid time format. Please check all time fields.';
    } else {
      taskFormError.value = 'An unexpected error occurred';
    }
  } finally {
    processingTask.value = false;
  }
}


// Format date and time (e.g., "May 23, 2025, 9:30 AM")
function formatDateTime(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  
  // Format date part
  const dateFormatted = date.toLocaleDateString('en-US', { 
    month: 'short', 
    day: 'numeric', 
    year: 'numeric'
  });
  
  // Use settings for time formatting
  const timeFormatted = formatTime(dateString);
  
  return `${dateFormatted}, ${timeFormatted}`;
}

// Format time (e.g., "9:30 AM" or "09:30") without the date based on app settings
function formatTime(timeString) {
  if (!timeString) return '';
  
  // Check if the input is already in HH:MM format
  if (typeof timeString === 'string' && /^\d{1,2}:\d{2}$/.test(timeString)) {
    // Already in the right format, just format according to settings
    const [hours, minutes] = timeString.split(':').map(Number);
    
    // Use 24h or 12h format based on settings
    if (settingsStore.appSettings.timeFormat === '24h') {
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
      if (settingsStore.appSettings.timeFormat === '24h') {
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
      return timeString || '';
    }
  }
}

// Format time for time input (HH:MM)
function formatDateTimeForInput(timeString) {
  if (!timeString) return '';
  
  // Check if the input is already in HH:MM format
  if (typeof timeString === 'string' && /^\d{1,2}:\d{2}$/.test(timeString)) {
    // Already in the right format, ensure it's padded correctly for the input
    const [hours, minutes] = timeString.split(':').map(Number);
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  } else {
    // For backward compatibility - if it's still a date string
    try {
      const date = new Date(timeString);
      
      // Get time parts
      const hours = String(date.getHours()).padStart(2, '0');
      const minutes = String(date.getMinutes()).padStart(2, '0');
      
      // Format for time input (HH:MM)
      return `${hours}:${minutes}`;
    } catch (e) {
      console.error('Error formatting time for input:', e);
      return timeString || '';
    }
  }
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

// Determine the appropriate area cover type for a shift
function determineAreaCoverType(shift) {
  if (!shift) return 'week_day'; // Default to week_day if no shift
  
  console.log('Determining area cover type for shift:', shift.id, 'type:', shift.shift_type);
  
  // Get the shift start time
  const shiftStart = new Date(shift.start_time);
  
  // Determine if it's a weekend
  const isWeekendDay = isWeekend(shiftStart);
  console.log('Is weekend day?', isWeekendDay);
  
  // Use the specific shift type directly
  const shiftType = shift.shift_type;
  
  // No need to convert, just use the shift type directly
  console.log('Using shift type directly:', shiftType);
  return shiftType;
  
  console.log('Determined area cover type:', areaCoverType);
  return areaCoverType;
}

// Get color for shift type
function getShiftColor() {
  if (!shift.value) return settingsStore.shiftDefaults.week_day.color;
  
  switch (shift.value.shift_type) {
    case 'week_day':
      return settingsStore.shiftDefaults.week_day.color;
    case 'week_night':
      return settingsStore.shiftDefaults.week_night.color;
    case 'weekend_day':
      return settingsStore.shiftDefaults.weekend_day.color;
    case 'weekend_night':
      return settingsStore.shiftDefaults.weekend_night.color;
    default:
      return settingsStore.shiftDefaults.week_day.color;
  }
}

// Show the change supervisor modal
function showChangeSupervisorModal() {
  // Initialize the supervisor dropdown with current supervisor
  if (shift.value && shift.value.supervisor_id) {
    selectedSupervisor.value = shift.value.supervisor_id;
  } else {
    selectedSupervisor.value = '';
  }
  
  // Need to load supervisors if not already loaded
  if (!supervisors.value || supervisors.value.length === 0) {
    staffStore.fetchSupervisors();
  }
  
  showSupervisorModal.value = true;
}

// Close the supervisor modal
function closeSupervisorModal() {
  showSupervisorModal.value = false;
  selectedSupervisor.value = '';
}

// Save the new supervisor
async function saveSupervisor() {
  if (!selectedSupervisor.value || changingSupervisor.value) return;
  
  changingSupervisor.value = true;
  
  try {
    await shiftsStore.updateShiftSupervisor(shift.value.id, selectedSupervisor.value);
    closeSupervisorModal();
  } catch (error) {
    console.error('Error updating supervisor:', error);
  } finally {
    changingSupervisor.value = false;
  }
}

// Helper function to determine if a date is on a weekend
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}
</script>

<style lang="scss" scoped>
@use "sass:color";
.mb-4 {
  margin-bottom: 1rem;
}

.duplicate-controls-section {
  margin-top: 1.5rem;
  padding: 1rem;
  background-color: #f8f9fa;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
}

.duplicate-controls-header {
  font-size: 1.1rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: #333;
}

.duplicate-controls {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  
  @media screen and (min-width: 500px) {
    flex-direction: row;
    align-items: center;
  }
}

.duplicate-label {
  font-weight: 500;
  margin-right: 0.75rem;
}

.date-picker {
  padding: 0.5rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-family: inherit;
  font-size: 0.9rem;
}

.shift-actions {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  margin-top: 0.5rem;
  width: 100%;
  
  @media screen and (min-width: 500px) {
    flex-direction: row;
    align-items: center;
  }
  
  @media screen and (min-width: 700px) {
    width: auto;
    margin-top: 0;
  }
}

.loading, .error-state {
  text-align: center;
  padding: 2rem;
}

.shift-info-header {
  display: flex;
  flex-direction: column;
  padding: 1rem 1.5rem;
  background-color: #f8f9fa;
  border-radius: 8px;
  
  @media screen and (min-width: 700px) {
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 2.5rem;
  }
  
  .shift-type {
    font-weight: 700; /* Make the colored text bolder */
  }
  
  &.archived-shift {
    .shift-type {
      color: #9e9e9e !important;
    }
  }
  
  .shift-header-content {
    h2 {
      margin: 0 0 0.5rem 0;
      font-size: 0.875rem;
      font-weight: 600;
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      
      .separator {
        margin: 0 0.5rem;
        color: #6c757d;
        display: none;
        
        @media screen and (min-width: 500px) {
          display: inline;
        }
      }
      
      @media screen and (min-width: 500px) {
        font-size: 0.95rem;
      }
      
      @media screen and (min-width: 700px) {
        margin-bottom: 0;
        font-size: 1rem;
      }
    }
  }
}

.archived-badge {
  font-size: 0.8rem;
  font-weight: normal;
  background-color: #9e9e9e;
  color: white;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  margin-left: 0.5rem;
}

.shift-details {
  margin: 0.5rem 0;
}

.shift-porter-pool-container {
  margin-top: 1.5rem;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  padding-top: 1rem;
}

.shift-area-coverage {
  margin-top: 1.5rem;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  padding-top: 1rem;
}

.section-title {
  font-size: 1.1rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: #333;
}

.confirmation-box {
  margin-top: 1rem;
  padding: 1rem;
  background-color: rgba(220, 53, 69, 0.1);
  border: 1px solid rgba(220, 53, 69, 0.3);
  border-radius: 4px;
  
  p {
    margin-top: 0;
  }
  
  .confirmation-actions {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-top: 1rem;
    
    @media screen and (min-width: 500px) {
      flex-direction: row;
    }
  }
}

.tasks-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.task-tabs {
  display: flex;
  border-bottom: 1px solid #e0e0e0;
  margin-bottom: 1rem;
  
  .tab-button {
    padding: 0.75rem 1rem;
    background: none;
    border: none;
    cursor: pointer;
    font-weight: 500;
    color: #666;
    
    &.active {
      color: #4285F4;
      border-bottom: 2px solid #4285F4;
    }
    
    &:hover:not(.active) {
      background-color: #f5f5f5;
    }
  }
}

.tasks-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.task-item {
  display: flex;
  justify-content: space-between;
  padding: 1rem;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  
  &.completed {
    background-color: #f9f9f9;
    border-left: 3px solid #34A853;
  }
  
  .task-details {
    flex: 1;
    
    .task-name {
      margin-top: 0;
      margin-bottom: 0.25rem;
    }
    
    .task-description {
      margin: 0.25rem 0 0.75rem;
      color: #666;
    }
  }
  
  .task-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    
    .meta-item {
      font-size: 0.9rem;
    }
    
    .not-assigned {
      color: #888;
      font-style: italic;
    }
  }
  
  .task-actions {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    align-self: center;
  }
}

.empty-state {
  text-align: center;
  padding: 2rem;
  color: #666;
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
  
  &-secondary {
    background-color: #f1f1f1;
    color: #1D1D1F;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#f1f1f1, $lightness: -5%);
    }
  }
  
  &-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#dc3545, $lightness: -10%);
    }
  }
  
  &-success {
    background-color: #34A853;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#34A853, $lightness: -10%);
    }
  }
  
  &-outline {
    background-color: transparent;
    border: 1px solid #9e9e9e;
    color: #333;
    
    &:hover:not(:disabled) {
      background-color: #f5f5f5;
    }
  }
  
  &.pending-btn {
    background-color: #FBBC05;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#FBBC05, $lightness: -10%);
    }
  }
  
  &.completed-btn {
    background-color: #34A853;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#34A853, $lightness: -10%);
    }
  }
  
  &-small {
    padding: 0.25rem 0.5rem;
    font-size: 0.9rem;
  }
}

.modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: flex-end; /* Changed from center to bottom alignment */
  justify-content: center;
  z-index: 1000;
  
  &-backdrop {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.5);
    z-index: 1; /* Lower z-index */
  }
  
  &-content {
    background-color: white;
    border-radius: 16px 16px 0 0; /* Rounded corners only on top */
    width: 100%; /* Full width on mobile */
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.1); /* Shadow coming from top */
    position: relative; /* Create stacking context */
    z-index: 2; /* Higher z-index than backdrop */
    
    @media screen and (min-width: 768px) {
      width: 90%;
      max-width: 500px;
      border-radius: 16px; /* Full rounded corners on desktop */
    }
  }
  
  &-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid #e0e0e0;
    
    h2 {
      margin: 0;
      font-size: 1.25rem;
    }
    
    .close-button {
      background: none;
      border: none;
      font-size: 1.5rem;
      cursor: pointer;
      padding: 0;
      line-height: 1;
    }
  }
  
  &-body {
    padding: 1rem;
    position: relative; /* Create positioning context for absolute elements */
    padding-bottom: 80px; /* Add padding to accommodate the time fields when hidden */
  }
  
  &-footer {
    padding: 1rem;
    border-top: 1px solid #e0e0e0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    
    @media screen and (min-width: 500px) {
      flex-direction: row;
      justify-content: flex-end;
    }
    
    /* Use grid layout for buttons on smaller screens */
    @media screen and (max-width: 499px) {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0.5rem;
      
      .btn {
        width: 100%;
        justify-content: center;
        text-align: center;
      }
      
      .completed-btn {
        grid-column: span 2;
      }
    }
    
    .btn {
      width: 100%;
      
      @media screen and (min-width: 500px) {
        width: auto;
      }
    }
  }
}

.form-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); /* Prevent columns from growing beyond available space */
  gap: 1rem;
  
  @media (max-width: 500px) {
    /* Keep 2 columns for all screens */
    .form-group {
      grid-column: span 2; /* Make all form groups span both columns by default */
    }
    
    /* Exception: Make these two fields take one column each on the same row */
    .form-group:nth-child(6), /* Allocated - inside time-fields-container */
    .form-group:nth-child(7) { /* Received - inside time-fields-container */
      grid-column: span 1;
    }
  }
}

.form-group {
  margin-bottom: 0;
  
  label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
  }
  
  .form-control {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 1rem;
    color: #666; /* Mid-grey color for form field text */
    font-weight: normal; /* Prevent bold text on iOS */
    -webkit-appearance: none; /* Remove iOS default styling */
    -moz-appearance: none;
    appearance: none;
    background-color: white; /* Ensure consistent background */
    font-family: inherit; /* Use the same font as the rest of the app */
  }
  
  /* Special handling for select elements */
  select.form-control {
    background-image: url("data:image/svg+xml;charset=utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 5'%3E%3Cpath fill='%23333' d='M2 0L0 2h4zm0 5L0 3h4z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 0.5rem center;
    background-size: 8px 10px;
    padding-right: 1.5rem; /* Space for the arrow */
  }
  
  /* Special handling for time inputs on iOS */
  input[type="time"].form-control {
    min-height: 38px; /* Ensure consistent height on iOS */
    line-height: normal; /* Fix vertical alignment */
    text-align: left; /* Left align text */
  }
}

.status-buttons {
  display: flex;
  gap: 0.5rem;
  
  .status-btn {
    flex: 1;
    padding: 0.5rem;
    border: 1px solid #ccc;
    border-radius: 4px;
    background-color: #f8f8f8;
    cursor: pointer;
    transition: all 0.2s;
    
    &.pending-btn {
      &.active {
        background-color: #FBBC05;
        color: white;
        border-color: #FBBC05;
      }
    }
    
    &.completed-btn {
      &.active {
        background-color: #34A853;
        color: white;
        border-color: #34A853;
      }
    }
    
    &:hover:not(.active) {
      background-color: #e8e8e8;
    }
  }
}

.time-info {
  background-color: #f8f9fa;
  border-radius: 4px;
  padding: 0.75rem;
  border: 1px solid #e9ecef;
  
  h4 {
    margin-top: 0;
    margin-bottom: 0.75rem;
    color: #495057;
    font-size: 0.95rem;
  }
  
  .time-info-item {
    margin-bottom: 0.5rem;
    font-size: 0.9rem;
    
    &:last-child {
      margin-bottom: 0;
    }
  }
}

.error-message {
  margin-top: 0.5rem;
  padding: 0.5rem 1rem;
  background-color: rgba(220, 53, 69, 0.1);
  border: 1px solid rgba(220, 53, 69, 0.3);
  border-radius: 4px;
  color: #dc3545;
  font-size: 0.9rem;
}

/* Animation for auto-populated fields */
@keyframes field-glow {
  0% { 
    box-shadow: 0 0 0 rgba(33, 150, 243, 0); 
    background-color: white;
    border-color: #ccc;
    transform: scale(1);
  }
  50% { 
    box-shadow: 0 0 15px rgba(33, 150, 243, 0.8); 
    background-color: rgba(33, 150, 243, 0.1);
    border-color: #2196F3;
    transform: scale(1.03);
  }
  100% { 
    box-shadow: 0 0 0 rgba(33, 150, 243, 0); 
    background-color: white;
    border-color: #ccc;
    transform: scale(1);
  }
}

.field-auto-populated {
  animation: field-glow 2s ease-in-out;
}

/* Active indicator styling */
.active-indicator {
  position: absolute;
  bottom: -1px;
  height: 2px;
  background-color: #4285F4; /* Primary color */
  z-index: 1;
}

/* Floating Action Container and Button */
.floating-action-container {
  position: fixed;
  bottom: 24px;
  right: 24px;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  z-index: 900;
  
  @media (max-width: 499px) {
    left: 24px; /* Add left position to stretch across */
    right: 24px; /* Keep right position */
    align-items: stretch; /* Make children stretch full width */
  }
}

.floating-action-button {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background-color: v-bind('getShiftColor()');
  color: white;
  border: none;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease-in-out;
  
  @media (max-width: 499px) {
    width: 100%; /* Make button full width */
    border-radius: 8px; /* Make it rectangular with rounded corners */
    height: 50px; /* Slightly shorter height for better proportions */
  }
  
  &:hover:not(:disabled) {
    transform: scale(1.05);
    filter: brightness(0.9);
    box-shadow: 0 6px 12px rgba(0, 0, 0, 0.3);
  }
  
  &:active:not(:disabled) {
    transform: scale(0.95);
  }
  
  &.disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .plus-icon {
    font-size: 45px;
    font-weight: 300;
    line-height: 0.8;
    margin-top: -4px;
    display: block; /* Ensures the text is treated as a block */
    
    @media (max-width: 499px) {
      font-size: 32px; /* Slightly smaller plus icon */
      margin-right: 8px; /* Add spacing for text */
    }
  }
  
  .button-text {
    display: none; /* Hidden by default on larger screens */
    
    @media (max-width: 499px) {
      display: inline; /* Show on small screens */
      font-size: 16px;
      font-weight: 500;
    }
  }
}

.date-warning {
  background-color: rgba(220, 53, 69, 0.1);
  border: 1px solid rgba(220, 53, 69, 0.3);
  color: #dc3545;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  font-size: 0.9rem;
  margin-bottom: 0.75rem;
  max-width: 300px;
  text-align: center;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.supervisor-section {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-edit-supervisor {
  background: none;
  border: none;
  padding: 0.25rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  transition: background-color 0.2s;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.05);
  }
  
  .edit-icon {
    width: 14px;
    height: 14px;
    color: #666;
  }
}

.current-supervisor {
  margin-bottom: 1.5rem;
  font-size: 1.1rem;
}

.supervisor-modal-content {
  max-width: 400px;
}

/* Time fields animation and styling */
.time-fields-container {
  position: relative;
  height: 0;
  overflow: hidden;
  /* Removed transition since Motion will handle it */
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  border-top: 1px solid #e0e0e0;
  padding: 0 1rem;
  background-color: #f8f8f8; /* Very pale grey background */
  
  &.visible {
    padding-top: 1rem;
    padding-bottom: 1rem;
  }
}

/* Timing toggle and fields styling */
.time-fields-wrapper {
  position: absolute;
  bottom: 0; /* Position at bottom of modal-body */
  left: 0;
  width: 100%;
  z-index: 10; /* Ensure it sits above other content */
}

.timing-toggle-btn {
  position: absolute;
  top: -35px; /* 1px less than the height (36px - 1px = 35px) */
  left: 50%;
  transform: translateX(-50%); /* Center horizontally */
  width: 60px; /* Fixed width for square button */
  height: 36px;
  background-color: #555; /* Darker grey background */
  border: none;
  border-radius: 8px 8px 0 0; /* Rounded corners only at top */
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  z-index: 11; /* Higher than the wrapper to stay on top */
  transition: background-color 0.2s;
  
  &:hover {
    background-color: #444; /* Darker hover state */
  }
  
  .timing-toggle-icon {
    color: white; /* Icon color changed to white */
  }
}

/* Activity Sheet Button Styling */
.card {
  position: relative; /* Create positioning context for absolute elements */
  padding: 1rem 1.5rem;
  
  @media screen and (min-width: 700px) {
    padding: 1rem 2.5rem;
  }
}

.activity-sheet-btn {
  position: absolute;
  top: 1rem;
  right: 1.5rem;
  z-index: 10;
  white-space: nowrap;
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  
  @media screen and (min-width: 700px) {
    right: 2.5rem;
  }
}
</style>
