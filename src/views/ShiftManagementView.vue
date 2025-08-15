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
          <!-- Activity Sheet and SitRep Buttons -->
          <div class="sheet-buttons">
            <button 
              v-if="shift && allTasks.length > 0"
              @click="showActivitySheet" 
              class="btn btn-primary sheet-btn"
              title="View and print activity sheet"
            >
              Activity Sheet
            </button>
            <button 
              v-if="shift"
              @click="showSitRep" 
              class="btn btn-secondary sheet-btn"
              title="View and print situation report"
            >
              SitRep
            </button>
          </div>
          
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
                  @porter-click="openAllocatePorterModal"
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
      <Transition
        @before-leave="onBeforeLeave"
        @after-leave="onAfterLeave"
      >
        <div v-if="showTaskModal" class="modal">
          <motion.div class="modal-backdrop"
            :initial="{ opacity: 0 }"
            :animate="isClosing ? { opacity: 0 } : { opacity: 1 }"
            :transition="{ 
              duration: 0.45,
              ease: 'easeInOut'
            }"
          ></motion.div>
          <motion.div class="tray"
            :initial="{ y: '100%' }"
            :animate="isClosing ? { y: '100%' } : { y: 0 }"
            :transition="{ 
              type: 'spring',
              stiffness: 300,
              damping: 25,
              mass: 1
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
                  <optgroup v-if="frequentDepartments.length > 0" label="Frequent Departments" class="frequent-departments-group">
                    <option v-for="dept in frequentDepartments" :key="`freq-${dept.id}`" :value="dept.id">
                      {{ dept.name }}
                    </option>
                  </optgroup>
                  
                  <!-- Departments grouped by building -->
                  <template v-for="building in departmentsByBuilding" :key="`from-${building.id}`">
                    <optgroup :label="building.name" class="building-optgroup">
                      <option v-for="dept in building.departments" :key="`from-${dept.id}`" :value="dept.id">
                        {{ dept.name }}
                      </option>
                    </optgroup>
                  </template>
                  
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
                  <optgroup v-if="frequentDepartments.length > 0" label="Frequent Departments" class="frequent-departments-group">
                    <option v-for="dept in frequentDepartments" :key="`freq-${dept.id}`" :value="dept.id">
                      {{ dept.name }}
                    </option>
                  </optgroup>
                  
                  <!-- Departments grouped by building -->
                  <template v-for="building in departmentsByBuilding" :key="`to-${building.id}`">
                    <optgroup :label="building.name" class="building-optgroup">
                      <option v-for="dept in building.departments" :key="`to-${dept.id}`" :value="dept.id">
                        {{ dept.name }}
                      </option>
                    </optgroup>
                  </template>
                  
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
                :initial="{ height: 0, opacity: 0 }"
                :animate="showTimeFields ? { height: timeFieldsHeight || 150, opacity: 1 } : { height: 0, opacity: 0 }"
                :transition="{ 
                  type: 'tween',
                  ease: [0.04, 0.62, 0.23, 0.98],
                  duration: 0.3
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
                    :class="{ 'time-auto-updated': timeFieldsAutoUpdated }"
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
                    :class="{ 'time-auto-updated': timeFieldsAutoUpdated }"
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
      </Transition>
      
      <!-- Change Supervisor Modal -->
      <Transition
        @before-leave="onBeforeLeave"
        @after-leave="onAfterLeave"
      >
        <div v-if="showSupervisorModal" class="modal">
          <motion.div class="modal-backdrop"
            :initial="{ opacity: 0 }"
            :animate="isClosing ? { opacity: 0 } : { opacity: 1 }"
            :transition="{ 
              duration: 0.45,
              ease: 'easeInOut'
            }"
          ></motion.div>
          <motion.div class="tray supervisor-modal-content"
            :initial="{ y: '100%' }"
            :animate="isClosing ? { y: '100%' } : { y: 0 }"
            :transition="{ 
              type: 'spring',
              stiffness: 300,
              damping: 25,
              mass: 1
            }"
          >
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
          </motion.div>
        </div>
      </Transition>

      <!-- Allocate Porter Modal -->
      <AllocatePorterModal 
        v-if="showAllocatePorterModal" 
        :porter="selectedPorter"
        :shift-id="shift.id"
        @close="showAllocatePorterModal = false"
        @allocated="handlePorterAllocation"
      />

      
      <!-- Floating Action Button for Adding Tasks -->
      <div class="floating-action-container">
        <button 
          v-if="shift && shift.is_active" 
          @click="showAddTaskModal" 
          class="floating-action-button"
          :class="{ 'disabled': !isShiftAccessibleComputed }"
          :disabled="!isShiftAccessibleComputed"
          :title="isShiftAccessibleComputed ? 'Add Task' : 'Cannot add tasks now - only available during shift or 1 hour before'"
        >
          <span class="plus-icon">+</span>
          <span class="button-text">New Task</span>
        </button>
        
        <!-- Non-accessible shift message -->
        <div v-if="shift && shift.is_active && !isShiftAccessibleComputed" class="date-warning">
          Tasks can only be added during the shift or 1 hour before it starts
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { motion } from 'motion-v';
import { useRoute, useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useTaskTypesStore } from '../stores/taskTypesStore';
import { useLocationsStore } from '../stores/locationsStore';
import { useSettingsStore } from '../stores/settingsStore';
import { isShiftAccessible, isShiftObjectAccessible } from '../utils/timezone';
import AnimatedTabs from '../components/shared/AnimatedTabs.vue';
import ShiftSetupTabContent from '../components/tabs/tab-contents/ShiftSetupTabContent.vue';
import TasksTabContent from '../components/tabs/tab-contents/TasksTabContent.vue';
import EditIcon from '../components/icons/EditIcon.vue';
import ClockIcon from '../components/icons/ClockIcon.vue';
import AllocatePorterModal from '../components/AllocatePorterModal.vue';

const route = useRoute();
const router = useRouter();
const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const taskTypesStore = useTaskTypesStore();
const locationsStore = useLocationsStore();
const settingsStore = useSettingsStore();

// Timer for cleaning up expired absences
let cleanupTimer = null;

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
const completedTimeOffset = ref(0); // Store the random offset for completed time
const allocatedTimeOffset = ref(1); // Store the offset for allocated time (default 1 minute)
const originalTaskTimes = ref({ received: '', allocated: '', completed: '' }); // Store original times for reference
const timeFieldsAutoUpdated = ref(false); // Track when time fields are auto-updated for visual feedback

// Porter allocation modal state
const showAllocatePorterModal = ref(false);
const selectedPorter = ref(null);

// Import nextTick for DOM manipulation after state changes
import { nextTick } from 'vue';

// Motion animation hooks
function onBeforeLeave(el) {
  // We don't need to do anything special here for Motion since we're 
  // setting the exit animations directly on the motion.div elements
}

function onAfterLeave() {
  // Reset state after animation completes and modal is fully hidden
  isClosing.value = false;
}

// Handle time fields visibility toggle
function toggleTimeFields() {
  // Measure height before toggling if we're going to show
  if (!showTimeFields.value) {
    // Get the container
    const container = document.querySelector('.time-fields-container');
    
    // Set temporary styles to make it measurable but invisible
    container.style.height = 'auto';
    container.style.position = 'absolute';
    container.style.visibility = 'hidden';
    container.style.display = 'grid';
    container.classList.add('visible'); // Add padding for accurate measurement
    
    // Measure the full height
    timeFieldsHeight.value = container.offsetHeight;
    
    // Reset the styles
    container.style.height = '';
    container.style.position = '';
    container.style.visibility = '';
    container.style.display = '';
    container.classList.remove('visible');
    
  }
  
  // Toggle the state
  showTimeFields.value = !showTimeFields.value;
  
  // If showing, add visible class for padding after a slight delay
  if (showTimeFields.value) {
    setTimeout(() => {
      const container = document.querySelector('.time-fields-container');
      if (container) container.classList.add('visible');
    }, 250); // Match duration of the animation
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
const isShiftAccessibleComputed = computed(() => {
  if (!shift.value) return false;
  
  return isShiftObjectAccessible(shift.value);
});
const porters = computed(() => {
  // Get current time for absence checking
  const now = new Date();
  const currentTimeStr = now.toTimeString().substring(0, 8); // HH:MM:SS format
  const currentHours = now.getHours();
  const currentMinutes = now.getMinutes();
  const currentTimeInMinutes = (currentHours * 60) + currentMinutes;
  
  // Helper function to convert time string (HH:MM:SS) to minutes
  const timeToMinutes = (timeStr) => {
    if (!timeStr) return 0;
    const [hours, minutes] = timeStr.split(':').map(Number);
    return (hours * 60) + minutes;
  };
  
  // Helper function to check if current time is within a time range, handling overnight ranges
  const isTimeInRange = (currentTimeMinutes, startTimeMinutes, endTimeMinutes) => {
    // Handle overnight ranges (where end time is less than start time)
    if (endTimeMinutes < startTimeMinutes) {
      // Current time is either after start time or before end time
      return currentTimeMinutes >= startTimeMinutes || currentTimeInMinutes <= endTimeMinutes;
    } else {
      // Normal case: current time is between start and end times
      return currentTimeInMinutes >= startTimeMinutes && currentTimeInMinutes <= endTimeMinutes;
    }
  };
  
  // Helper function to check if a time period is active now
  const isTimePeriodActive = (startTimeStr, endTimeStr) => {
    if (!startTimeStr || !endTimeStr) return false;
    
    const startTimeMinutes = timeToMinutes(startTimeStr);
    const endTimeMinutes = timeToMinutes(endTimeStr);
    
    return isTimeInRange(currentTimeInMinutes, startTimeMinutes, endTimeMinutes);
  };
  
  // Helper function to get porter duty status based on contracted hours
  const getPorterDutyStatus = (porterId) => {
    // Get the porter details
    const porter = staffStore.porters.find(p => p.id === porterId);
    if (!porter) return 'on-duty'; // Default to on duty if porter not found
    
    // If no contracted hours set, assume porter is on duty
    if (!porter.contracted_hours_start || !porter.contracted_hours_end) {
      return 'on-duty';
    }
    
    // Convert contracted hours to minutes
    const startTimeMinutes = timeToMinutes(porter.contracted_hours_start);
    const endTimeMinutes = timeToMinutes(porter.contracted_hours_end);
    
    // Check if current time is within contracted hours
    if (isTimeInRange(currentTimeInMinutes, startTimeMinutes, endTimeMinutes)) {
      return 'on-duty';
    }
    
    // Determine if we're before start time or after end time
    if (endTimeMinutes < startTimeMinutes) {
      // Overnight shift (e.g., 22:00 to 06:00)
      if (currentTimeInMinutes > endTimeMinutes && currentTimeInMinutes < startTimeMinutes) {
        // We're in the gap between end and start (e.g., 07:00 when shift is 22:00-06:00)
        // Need to determine if we're closer to the end (off-duty) or start (not-yet-on-duty)
        const timeFromEnd = currentTimeInMinutes - endTimeMinutes;
        const timeToStart = startTimeMinutes - currentTimeInMinutes;
        
        // If we're closer to the end time, consider it "off-duty"
        // If we're closer to the start time, consider it "not-yet-on-duty"
        return timeFromEnd <= timeToStart ? 'off-duty' : 'not-yet-on-duty';
      }
    } else {
      // Normal shift (e.g., 10:00 to 22:00)
      if (currentTimeInMinutes < startTimeMinutes) {
        // We're before the start time, but need to determine if this is:
        // 1. Before today's shift starts (not-yet-on-duty)
        // 2. After yesterday's shift ended (off-duty)
        
        // Calculate time until today's shift starts
        const timeUntilStart = startTimeMinutes - currentTimeInMinutes;
        
        // Calculate time since yesterday's shift ended
        // Yesterday's end time would be endTimeMinutes, but we need to account for the day boundary
        const timeSinceYesterdayEnd = currentTimeInMinutes + (24 * 60 - endTimeMinutes);
        
        // Use a threshold-based approach:
        // PRIORITIZE upcoming shifts over past shifts
        // If their next shift starts in less than 4 hours, they're "not-yet-on-duty"
        // If they've been off duty for more than 4 hours, they're "off-duty"
        const THRESHOLD_HOURS = 4;
        const THRESHOLD_MINUTES = THRESHOLD_HOURS * 60;
        
        // FIRST: Check if their next shift starts within the threshold - prioritize upcoming work
        if (timeUntilStart <= THRESHOLD_MINUTES) {
          return 'not-yet-on-duty';
        }
        
        // SECOND: If they've been off duty for more than the threshold, they're "off-duty"
        if (timeSinceYesterdayEnd > THRESHOLD_MINUTES) {
          return 'off-duty';
        }
        
        // Fallback: if both conditions don't match, default to off-duty
        return 'off-duty';
      } else if (currentTimeInMinutes > endTimeMinutes) {
        return 'off-duty';
      }
    }
    
    // Fallback
    return 'on-duty';
  };
  
  // Helper function to check if porter is on duty (for backward compatibility)
  const isPorterOnDuty = (porterId) => {
    return getPorterDutyStatus(porterId) === 'on-duty';
  };
  
  // Only show porters from the shift pool who are currently available
  return shiftsStore.shiftPorterPool
    .filter(entry => {
      // Check if porter has a global absence (illness, annual leave)
      const isAbsent = staffStore.isPorterAbsent(entry.porter_id, now);
      if (isAbsent) return false;
      
      // Check if porter is not on duty yet based on contracted hours
      if (!isPorterOnDuty(entry.porter_id)) return false;
      
      // Check if porter has an active scheduled absence in the shift
      const hasActiveAbsence = shiftsStore.shiftPorterAbsences && 
        shiftsStore.shiftPorterAbsences.some(absence => {
          if (absence.porter_id !== entry.porter_id) return false;
          
          // Check if current time is within absence period
          return isTimePeriodActive(absence.start_time, absence.end_time);
        });
      if (hasActiveAbsence) return false;
      
      // Check if porter has active area cover assignments
      const hasActiveAreaCoverAssignment = shiftsStore.shiftAreaCoverPorterAssignments.some(
        assignment => {
          if (assignment.porter_id !== entry.porter_id) return false;
          
          // Check if current time is within assignment period
          return isTimePeriodActive(assignment.start_time, assignment.end_time);
        }
      );
      if (hasActiveAreaCoverAssignment) return false;
      
      // Check if porter has active service assignments
      const hasActiveServiceAssignment = shiftsStore.shiftSupportServicePorterAssignments.some(
        assignment => {
          if (assignment.porter_id !== entry.porter_id) return false;
          
          // Check if current time is within assignment period
          return isTimePeriodActive(assignment.start_time, assignment.end_time);
        }
      );
      if (hasActiveServiceAssignment) return false;
      
      // If we've reached here, porter is available
      return true;
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

// Departments grouped by building for dropdowns
const departmentsByBuilding = computed(() => {
  // Get buildings sorted by sort_order
  const sortedBuildings = [...locationsStore.buildings].sort((a, b) => a.sort_order - b.sort_order);
  
  // Create an array of objects with building and its departments
  return sortedBuildings.map(building => {
    const buildingDepartments = locationsStore.departments
      .filter(dept => dept.building_id === building.id && !dept.is_frequent)
      .sort((a, b) => a.sort_order - b.sort_order);
      
    return {
      ...building,
      departments: buildingDepartments
    };
  }).filter(building => building.departments.length > 0); // Only include buildings with departments
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
// Function to check and clean up all expired allocations
const checkAndCleanupExpiredAllocations = async () => {
  if (shift.value && shift.value.id) {
    const result = await shiftsStore.cleanupAllExpiredAssignments();
  }
};

onMounted(async () => {
  loading.value = true;
  
  // Tab indicator positioning is now handled by AnimatedTabs component
  
  // Set up periodic cleanup of all expired allocations (every 30 seconds)
  checkAndCleanupExpiredAllocations(); // Initial check
  cleanupTimer = setInterval(checkAndCleanupExpiredAllocations, 30000);
  
  try {
    const shiftId = route.params.id;
    
    // Load shift and its tasks
    await shiftsStore.fetchShiftById(shiftId);
    
    if (shiftsStore.currentShift) {
      // Load shift tasks
      await shiftsStore.fetchShiftTasks(shiftId);
      
    // Load area cover assignments for this shift
    await shiftsStore.fetchShiftAreaCover(shiftId);
    
    // Check if area cover assignments need initialization
    if (shiftsStore.shiftAreaCoverAssignments.length === 0) {
      // Check the defaults in the area cover store
      const { useAreaCoverStore } = await import('../stores/areaCoverStore');
      const areaCoverStore = useAreaCoverStore();
      await areaCoverStore.initialize();
      
      // Check if defaults exist for this shift type
      const shiftType = shift.value.shift_type;
      const defaultAssignments = areaCoverStore[`${shiftType}Assignments`] || [];
      
      if (defaultAssignments.length > 0) {
        // Try to re-initialize the area cover from defaults
        await shiftsStore.setupShiftAreaCoverFromDefaults(shiftId, shiftType);
        
        // Check if it worked
        await shiftsStore.fetchShiftAreaCover(shiftId);
      }
    }
    
    // Load support service assignments for this shift
    await shiftsStore.fetchShiftSupportServices(shiftId);
    
    // Load porter pool
    await shiftsStore.fetchShiftPorterPool(shiftId);
    }
    
    // Load supporting data for task management
    await Promise.all([
      staffStore.fetchPorters(),
      staffStore.fetchPorterAbsences(), // Explicitly load porter absences
      taskTypesStore.fetchTaskTypes(),
      locationsStore.fetchDepartments(),
      locationsStore.fetchBuildings(), // Also load buildings
      settingsStore.loadSettings()
    ]);
  } catch (error) {
    // Error handling without console logging
  } finally {
    loading.value = false;
  }
});

// Clean up resources when component is unmounted
onUnmounted(() => {
  // Clear timer to prevent memory leaks
  if (cleanupTimer) {
    clearInterval(cleanupTimer);
    cleanupTimer = null;
  }
  
  // Tab indicator positioning is now handled by AnimatedTabs component
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

// Watch for changes to the received time and update other time fields accordingly
watch(() => taskForm.value.timeReceived, (newReceivedTime, oldReceivedTime) => {
  if (!newReceivedTime) return;
  
  // Always update the times whenever received time changes, even when editing
  try {
    // Parse the received time
    const [hours, minutes] = newReceivedTime.split(':').map(Number);
    
    // Create a date object for the received time
    const receivedDate = new Date();
    receivedDate.setHours(hours, minutes, 0, 0);
    
    // Allocated time is always exactly 1 minute after received time
    const allocatedDate = new Date(receivedDate.getTime() + 60000); // Always 1 minute
    
    // Calculate completed time (received + completed offset)
    const completedDate = new Date(receivedDate.getTime() + (completedTimeOffset.value * 60000));
    
    // Update the other time fields
    const newAllocatedTime = formatDateTimeForInput(allocatedDate);
    const newCompletedTime = formatDateTimeForInput(completedDate);
    
    // Always update the times
    taskForm.value.timeAllocated = newAllocatedTime;
    taskForm.value.timeCompleted = newCompletedTime;
    
    // Set flag for visual feedback
    timeFieldsAutoUpdated.value = true;
    
    // Reset the flag after animation completes
    setTimeout(() => {
      timeFieldsAutoUpdated.value = false;
    }, 1500);
  } catch (error) {
    // Don't update fields if there's an error parsing the time
  }
});

// Watch for origin department changes to auto-populate task type and task item
watch(() => taskForm.value.originDepartmentId, (newDepartmentId) => {
  if (!newDepartmentId) return;
  
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
      
      if (typeAssignments.length > 0) {
        // Use the first assignment
        const typeAssignment = typeAssignments[0];
        
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
        
        if (assignment && assignment.task_type_id) {
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

// Note: Tab indicator positioning is now handled by the AnimatedTabs component

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
    // Error handling without console logging
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
  
  // Store original times for reference
  originalTaskTimes.value = {
    received: task.time_received ? formatDateTimeForInput(task.time_received) : '',
    allocated: task.time_allocated ? formatDateTimeForInput(task.time_allocated) : '',
    completed: task.time_completed ? formatDateTimeForInput(task.time_completed) : ''
  };
  
  // Allocated time should always be exactly 1 minute after received time
  allocatedTimeOffset.value = 1;
  
  // Calculate and store time offset for completed time
  if (task.time_received && task.time_completed) {
    const receivedTime = new Date(task.time_received);
    
    // Calculate completed time offset if both received and completed times exist
    if (task.time_completed) {
      const completedTime = new Date(task.time_completed);
      const completedDiffMs = completedTime.getTime() - receivedTime.getTime();
      completedTimeOffset.value = Math.round(completedDiffMs / 60000); // Convert ms to minutes
    } else {
      // Default to a random offset if completed time isn't available
      completedTimeOffset.value = Math.floor(Math.random() * (30 - 15 + 1)) + 15;
    }
  } else {
    // Default values if no received time is available
    allocatedTimeOffset.value = 1;
    completedTimeOffset.value = Math.floor(Math.random() * (30 - 15 + 1)) + 15;
  }
  
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
  
  // Note: We no longer automatically show the time fields section
  // This keeps the UI consistent between adding and editing tasks
  showTimeFields.value = false;
  
  // Reset auto-update visual feedback
  timeFieldsAutoUpdated.value = false;
  
  // Load task items for this task type
  loadTaskItems();
  
  // Show the modal
  showTaskModal.value = true;
}

// Close task modal
function closeTaskModal() {
  // Set the closing state to trigger exit animations
  isClosing.value = true;
  
  // Use a timeout to hide the modal after animation completes
  setTimeout(() => {
    showTaskModal.value = false;
    resetTaskForm();
    isClosing.value = false; // Reset the closing state
  }, 500); // Give spring animation enough time to complete
}

// Reset task form
function resetTaskForm() {
  // Get current time
  const now = new Date();
  
  // Reset offset values for new tasks
  allocatedTimeOffset.value = 1; // 1 minute
  
  // Calculate time_completed (random between 15-30 minutes from now)
  const randomMinutes = Math.floor(Math.random() * (30 - 15 + 1)) + 15; // Random between 15-30
  completedTimeOffset.value = randomMinutes; // Store this offset for later recalculation
  
  // Calculate time values
  const timeAllocated = new Date(now.getTime() + (allocatedTimeOffset.value * 60000));
  const timeCompleted = new Date(now.getTime() + (completedTimeOffset.value * 60000));
  
  // Reset original times
  originalTaskTimes.value = {
    received: '',
    allocated: '',
    completed: ''
  };
  
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
  timeFieldsAutoUpdated.value = false; // Reset auto-update visual feedback
  
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
      taskForm.value.taskItemId = regularItem.id;
      
      // Set the animation flag for visual feedback
      taskItemAutoPopulated.value = true;
      // Reset the flag after animation completes
      setTimeout(() => {
        taskItemAutoPopulated.value = false;
      }, 1500);
    }
  } catch (error) {
    // Error handling without console logging
  } finally {
    loadingTaskItems.value = false;
  }
}

// Check for department assignments for a task type and auto-populate form fields
function checkTaskTypeDepartmentAssignments(taskTypeId) {
  if (!taskTypeId) return;
  
  // Only apply default departments if department fields haven't been touched yet
  if (!departmentFieldTouched.value) {
    const assignments = taskTypesStore.getTypeAssignmentsByTypeId(taskTypeId);
    
    // Look for origin department
    const originAssignment = assignments.find(a => a.is_origin);
    
    if (originAssignment && !taskForm.value.originDepartmentId) {
      taskForm.value.originDepartmentId = originAssignment.department_id;
      originFieldAutoPopulated.value = true;
      // Reset the flag after animation completes
      setTimeout(() => {
        originFieldAutoPopulated.value = false;
      }, 1500);
    }
    
    // Look for destination department
    const destinationAssignment = assignments.find(a => a.is_destination);
    
    if (destinationAssignment && !taskForm.value.destinationDepartmentId) {
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
  
  // Only auto-populate departments if they haven't been touched yet
  if (!departmentFieldTouched.value) {
    const assignments = taskTypesStore.getItemAssignmentsByItemId(taskItemId);
    
    // Look for origin department
    const originAssignment = assignments.find(a => a.is_origin);
    
    if (originAssignment) {
      taskForm.value.originDepartmentId = originAssignment.department_id;
      originFieldAutoPopulated.value = true;
      // Reset the flag after animation completes
      setTimeout(() => {
        originFieldAutoPopulated.value = false;
      }, 1500);
    }
    
    // Look for destination department
    const destinationAssignment = assignments.find(a => a.is_destination);
    
    if (destinationAssignment) {
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
      return null;
    }
    
    return dateTimeStr;
  } catch (error) {
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
    // Error handling without console logging
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
    // Error handling without console logging
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
      return timeString || '';
    }
  }
}

// Open porter allocation modal
function openAllocatePorterModal(porter) {
  selectedPorter.value = porter;
  showAllocatePorterModal.value = true;
}

// Handle porter allocation result
function handlePorterAllocation(allocation) {
  // The store and UI will update automatically due to reactivity
  // Refresh data if needed
  if (allocation.type === 'department') {
    shiftsStore.fetchShiftAreaCover(shift.value.id);
  } else if (allocation.type === 'service') {
    shiftsStore.fetchShiftSupportServices(shift.value.id);
  } else if (allocation.type === 'absence') {
    shiftsStore.fetchShiftPorterAbsences(shift.value.id);
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
  
  // Use the specific shift type directly
  const shiftType = shift.shift_type;
  
  // No need to convert, just use the shift type directly
  return shiftType;
}

// Get color for shift type
function getShiftColor() {
  const shiftDefaults = settingsStore.shiftDefaultsByType;
  
  if (!shift.value) return shiftDefaults.week_day?.color || '#4285F4';
  
  switch (shift.value.shift_type) {
    case 'week_day':
      return shiftDefaults.week_day?.color || '#4285F4';
    case 'week_night':
      return shiftDefaults.week_night?.color || '#673AB7';
    case 'weekend_day':
      return shiftDefaults.weekend_day?.color || '#4285F4';
    case 'weekend_night':
      return shiftDefaults.weekend_night?.color || '#673AB7';
    default:
      return shiftDefaults.week_day?.color || '#4285F4';
  }
}

// Show SitRep view
function showSitRep() {
  // Navigate to the SitRep view
  router.push(`/shift/${shift.value.id}/sitrep`);
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
  // Set the closing state to trigger exit animations
  isClosing.value = true;
  
  // Wait for animation to complete before hiding the modal
  setTimeout(() => {
    showSupervisorModal.value = false;
    selectedSupervisor.value = '';
    isClosing.value = false;
  }, 500); // Give spring animation enough time to complete
}

// Save the new supervisor
async function saveSupervisor() {
  if (!selectedSupervisor.value || changingSupervisor.value) return;
  
  changingSupervisor.value = true;
  
  try {
    await shiftsStore.updateShiftSupervisor(shift.value.id, selectedSupervisor.value);
    closeSupervisorModal();
  } catch (error) {
    // Error handling without console logging
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
  
  @media screen and (max-width: 500px) {
    padding: 0.75rem 1.5rem; /* Increased padding for better touch targets */
    font-size: 1.1rem; /* Slightly larger text */
  }
  
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
  
  .tray {
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
      border-radius: 16px 16px 0 0; /* Keep only top corners rounded on desktop too */
    }
  }
  
  &-content {
    /* Legacy styles for supervisor modal */
    background-color: white;
    border-radius: 16px;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    position: relative;
    z-index: 2;
    width: 90%;
    max-width: 500px;
  }
  
  &-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    border-bottom: 1px solid #e0e0e0;
    
    @media screen and (max-width: 500px) {
      padding: 1.5rem 1.25rem; /* Increased padding on small screens */
    }
    
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
    
    @media screen and (max-width: 500px) {
      padding: 1.5rem 1.25rem; /* Increased padding on small screens */
      padding-bottom: 65px; /* Adjust bottom padding for time fields */
    }
  }
  
  &-footer {
    padding: 1rem;
    border-top: 1px solid #e0e0e0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    
    @media screen and (max-width: 500px) {
      padding: 1.5rem 1.25rem; /* Increased padding on small screens */
    }
    
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
  
  @media (max-width: 360px) {
    /* Switch to single column layout only below 360px */
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

/* Animation for auto-updated time fields */
@keyframes time-field-update {
  0% { 
    box-shadow: 0 0 0 rgba(76, 175, 80, 0); 
    background-color: white;
    border-color: #ccc;
  }
  50% { 
    box-shadow: 0 0 10px rgba(76, 175, 80, 0.6); 
    background-color: rgba(76, 175, 80, 0.1);
    border-color: #4CAF50;
  }
  100% { 
    box-shadow: 0 0 0 rgba(76, 175, 80, 0); 
    background-color: white;
    border-color: #ccc;
  }
}

.time-auto-updated {
  animation: time-field-update 1.5s ease-in-out;
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

/* Sheet Buttons Styling */
.card {
  position: relative; /* Create positioning context for absolute elements */
  padding: 1rem 1.5rem;
  
  @media screen and (min-width: 700px) {
    padding: 1rem 2.5rem;
  }
}

.sheet-buttons {
  position: absolute;
  top: 1rem;
  right: 1.5rem;
  z-index: 10;
  display: flex;
  gap: 0.5rem;
  
  @media screen and (min-width: 700px) {
    right: 2.5rem;
  }
}

.sheet-btn {
  white-space: nowrap;
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

/* Style for the Frequent Departments optgroup */
:deep(.frequent-departments-group) {
  background-color: #f0f7ff; /* Light blue background */
  font-weight: 600;
}

/* Style for the Building optgroups */
:deep(.building-optgroup) {
  background-color: #444; /* Dark grey background */
  color: white; /* White text */
  font-weight: 600; /* Make it bold like the Frequent Departments group */
}
</style>
