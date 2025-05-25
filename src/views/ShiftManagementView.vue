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
        <!-- Shift Information Card -->
        <div 
          class="card shift-info mb-4" 
          :class="{ 'archived-shift': !shift.is_active }"
        >
          <div class="shift-header">
            <div>
              <h2>
                {{ getShiftTypeDisplayName() }}
                <span v-if="!shift.is_active" class="archived-badge">Archived</span>
              </h2>
              <p class="shift-details">
                <strong>Supervisor:</strong> 
                {{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}
              </p>
              <p class="shift-details">
                <strong>Started:</strong> {{ formatDateTime(shift.start_time) }}
              </p>
              <p v-if="shift.end_time" class="shift-details">
                <strong>Ended:</strong> {{ formatDateTime(shift.end_time) }}
              </p>
              <p v-else class="shift-details">
                <strong>Duration:</strong> {{ calculateDuration(shift.start_time) }}
              </p>
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
          <div class="tabs">
            <div class="tabs__header">
              <TabHeader 
                v-for="tab in tabs" 
                :key="tab.id"
                :label="tab.label"
                :isActive="activeTabId === tab.id"
                :badge-count="tab.id === 'tasks' ? totalTasksCount : 0"
                @click="setActiveTab(tab.id)"
              />
            </div>
            
            <TabContent :activeTab="activeTabId">
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
            </TabContent>
          </div>
        </div>
      </template>
      
      <!-- Add/Edit Task Modal -->
      <div v-if="showTaskModal" class="modal">
        <div class="modal-content">
          <div class="modal-header">
            <h2>{{ isEditingTask ? 'Edit Task' : 'Add New Task' }}</h2>
            <button @click="closeTaskModal" class="close-button">&times;</button>
          </div>
          
          <div class="modal-body">
            <div class="form-grid">
              <!-- Task Type | Task Item -->
              <div class="form-group">
                <label for="taskType">Task Type</label>
                <select 
                  id="taskType" 
                  v-model="taskForm.taskTypeId" 
                  class="form-control" 
                  @change="loadTaskItems"
                  :disabled="isEditingTask"
                >
                  <option value="">Select a task type</option>
                  <option v-for="type in taskTypes" :key="type.id" :value="type.id">
                    {{ type.name }}
                  </option>
                </select>
              </div>
              
              <div class="form-group">
                <label for="taskItem">Task Item</label>
                <select 
                  id="taskItem" 
                  v-model="taskForm.taskItemId" 
                  class="form-control"
                  :disabled="!taskForm.taskTypeId || loadingTaskItems || isEditingTask"
                >
                  <option value="">{{ loadingTaskItems ? 'Loading items...' : 'Select a task item' }}</option>
                  <option v-for="item in taskItems" :key="item.id" :value="item.id">
                    {{ item.name }}
                  </option>
                </select>
              </div>
              
<!-- From | To -->
<div class="form-group">
  <label for="originDepartment">From</label>
  <select 
    id="originDepartment" 
    v-model="taskForm.originDepartmentId" 
    class="form-control"
    :class="{ 'field-auto-populated': originFieldAutoPopulated }"
  >
    <option value="">Select origin department (optional)</option>
    <option v-for="dept in departments" :key="dept.id" :value="dept.id">
      {{ dept.name }}
    </option>
  </select>
</div>

<div class="form-group">
  <label for="destinationDepartment">To</label>
  <select 
    id="destinationDepartment" 
    v-model="taskForm.destinationDepartmentId" 
    class="form-control"
    :class="{ 'field-auto-populated': destinationFieldAutoPopulated }"
  >
    <option value="">Select destination department (optional)</option>
    <option v-for="dept in departments" :key="dept.id" :value="dept.id">
      {{ dept.name }}
    </option>
  </select>
</div>
              
              <!-- Received | Porter -->
              <div class="form-group">
                <label for="timeReceived">Received</label>
                <input 
                  type="time" 
                  id="timeReceived" 
                  v-model="taskForm.timeReceived" 
                  class="form-control"
                />
              </div>
              
              <div class="form-group">
                <label for="porter">Porter</label>
                <select id="porter" v-model="taskForm.porterId" class="form-control">
                  <option value="">Select porter (optional)</option>
                  <option v-for="porter in porters" :key="porter.id" :value="porter.id">
                    {{ porter.first_name }} {{ porter.last_name }}
                  </option>
                </select>
              </div>
              
              <!-- Allocated | Exp. Completion -->
              <div class="form-group">
                <label for="timeAllocated">Allocated</label>
                <input 
                  type="time" 
                  id="timeAllocated" 
                  v-model="taskForm.timeAllocated" 
                  class="form-control"
                />
              </div>
              
              <div class="form-group">
                <label for="timeCompleted">Exp. Completion</label>
                <input 
                  type="time" 
                  id="timeCompleted" 
                  v-model="taskForm.timeCompleted" 
                  class="form-control"
                />
              </div>
              
              <!-- Status buttons moved to footer for new tasks, but kept here for editing -->
              <div v-if="isEditingTask" class="form-group">
                <label>Status</label>
                <div class="status-buttons">
                  <button 
                    type="button"
                    @click="taskForm.status = 'pending'"
                    class="status-btn pending-btn" 
                    :class="{ active: taskForm.status === 'pending' }"
                  >
                    Pending
                  </button>
                  <button 
                    type="button"
                    @click="taskForm.status = 'completed'"
                    class="status-btn completed-btn" 
                    :class="{ active: taskForm.status === 'completed' }"
                  >
                    Completed
                  </button>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Different footer for new vs edit task -->
          <div class="modal-footer">
            <!-- Edit mode: Update | Cancel -->
            <template v-if="isEditingTask">
              <button 
                @click="closeTaskModal" 
                class="btn btn-secondary" 
                :disabled="processingTask"
              >
                Cancel
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
        </div>
      </div>
      
      <!-- Floating Action Button for Adding Tasks -->
      <button 
        v-if="shift && shift.is_active" 
        @click="showAddTaskModal" 
        class="floating-action-button"
        title="Add Task"
      >
        <span class="plus-icon">+</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useTaskTypesStore } from '../stores/taskTypesStore';
import { useLocationsStore } from '../stores/locationsStore';
import { useSettingsStore } from '../stores/settingsStore';
import TabHeader from '../components/tabs/TabHeader.vue';
import TabContent from '../components/tabs/TabContent.vue';
import ShiftSetupTabContent from '../components/tabs/tab-contents/ShiftSetupTabContent.vue';
import TasksTabContent from '../components/tabs/tab-contents/TasksTabContent.vue';

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
const activeTabId = ref('shiftSetup'); // For main view tabs (shift setup/tasks)
const tabs = [
  { id: 'shiftSetup', label: 'Shift Setup' },
  { id: 'tasks', label: 'Tasks' }
];
const showEndShiftConfirm = ref(false);
const endingShift = ref(false);
const loadingTaskItems = ref(false);
const updatingTask = ref(false);
const taskItems = ref([]);

// Task modal state
const showTaskModal = ref(false);
const isEditingTask = ref(false);
const editingTaskId = ref(null);
const editingTask = ref(null);
const processingTask = ref(false);
const taskFormError = ref('');

// Track fields auto-population for visual feedback
const originFieldAutoPopulated = ref(false);
const destinationFieldAutoPopulated = ref(false);

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
const totalTasksCount = computed(() => pendingTasks.value.length + completedTasks.value.length);
const porters = computed(() => {
  // Only show porters from the shift pool
  return shiftsStore.shiftPorterPool.map(p => p.porter);
});
const taskTypes = computed(() => taskTypesStore.taskTypes);
const departments = computed(() => locationsStore.departments);
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
    }
    
    // Load porter pool
    await shiftsStore.fetchShiftPorterPool(shiftId);
    console.log(`Loaded ${shiftsStore.shiftPorterPool.length} porters in pool`);
    }
    
    // Load supporting data for task management
    await Promise.all([
      staffStore.fetchPorters(),
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

// Watch for task item changes to auto-populate department fields
watch(() => taskForm.value.taskItemId, (newTaskItemId) => {
  if (newTaskItemId) {
    // Check for item-specific department assignments and auto-populate
    checkTaskItemDepartmentAssignments(newTaskItemId);
  }
});

  // Methods
function setActiveTab(tabId) {
  activeTabId.value = tabId;
}

function navigateToHome() {
  router.push('/');
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
  
  // Load task items for this task type
  loadTaskItems();
  
  // Show the modal
  showTaskModal.value = true;
}

// Close task modal
function closeTaskModal() {
  showTaskModal.value = false;
  resetTaskForm();
}

// Reset task form
function resetTaskForm() {
  // Get current time
  const now = new Date();
  
  // Calculate time_allocated (+1 minute from now)
  const timeAllocated = new Date(now.getTime() + 60000); // 60000 ms = 1 minute
  
  // Calculate time_completed (+20 minutes from now)
  const timeCompleted = new Date(now.getTime() + 1200000); // 1200000 ms = 20 minutes
  
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
    checkTaskTypeDepartmentAssignments(taskForm.value.taskTypeId);
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
  
  // Only apply default departments if fields are empty
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

// Check for department assignments for a task item and auto-populate form fields
function checkTaskItemDepartmentAssignments(taskItemId) {
  if (!taskItemId) return;
  
  console.log('Checking task item assignments for item ID:', taskItemId);
  
  // Get the task item name for better logging
  const taskItem = taskItems.value.find(i => i.id === taskItemId);
  console.log('Task item name:', taskItem?.name);
  
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

// Save task (add or update)
async function saveTask() {
  if (!canSaveTask.value || processingTask.value) return;
  
  processingTask.value = true;
  taskFormError.value = '';
  
  try {
    // For time inputs, we need to create proper datetime objects with the current date
    // but using the times from the form
    const currentDate = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    
    // Transform form data to match the API requirements
    const taskData = {
      taskItemId: taskForm.value.taskItemId,
      porterId: taskForm.value.porterId || null,
      originDepartmentId: taskForm.value.originDepartmentId || null,
      destinationDepartmentId: taskForm.value.destinationDepartmentId || null,
      status: taskForm.value.status
    };
    
    // Only include time fields if they are provided
    if (taskForm.value.timeReceived) {
      // Use original date with new time for editing
      const originalDate = isEditingTask.value && editingTask.value.time_received 
        ? new Date(editingTask.value.time_received).toISOString().split('T')[0]
        : currentDate;
      taskData.time_received = `${originalDate}T${taskForm.value.timeReceived}:00`;
    }
    
    if (taskForm.value.timeAllocated) {
      const originalDate = isEditingTask.value && editingTask.value.time_allocated
        ? new Date(editingTask.value.time_allocated).toISOString().split('T')[0]
        : currentDate;
      taskData.time_allocated = `${originalDate}T${taskForm.value.timeAllocated}:00`;
    }
    
    if (taskForm.value.timeCompleted) {
      const originalDate = isEditingTask.value && editingTask.value.time_completed
        ? new Date(editingTask.value.time_completed).toISOString().split('T')[0]
        : currentDate;
      taskData.time_completed = `${originalDate}T${taskForm.value.timeCompleted}:00`;
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
    taskFormError.value = 'An unexpected error occurred';
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
    // For time inputs, we need to create proper datetime objects with the current date
    // but using the times from the form
    const currentDate = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    
    // Transform form data to match the API requirements
    const taskData = {
      taskItemId: taskForm.value.taskItemId,
      porterId: taskForm.value.porterId || null,
      originDepartmentId: taskForm.value.originDepartmentId || null,
      destinationDepartmentId: taskForm.value.destinationDepartmentId || null,
      status: taskForm.value.status
    };
    
    // Only include time fields if they are provided
    if (taskForm.value.timeReceived) {
      taskData.time_received = `${currentDate}T${taskForm.value.timeReceived}:00`;
    }
    
    if (taskForm.value.timeAllocated) {
      taskData.time_allocated = `${currentDate}T${taskForm.value.timeAllocated}:00`;
    }
    
    if (taskForm.value.timeCompleted) {
      taskData.time_completed = `${currentDate}T${taskForm.value.timeCompleted}:00`;
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
    taskFormError.value = 'An unexpected error occurred';
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

// Get display name for shift type
function getShiftTypeDisplayName() {
  if (!shift.value) return 'Shift';
  
  switch (shift.value.shift_type) {
    case 'week_day':
      return 'Week Day Shift';
    case 'week_night':
      return 'Week Night Shift';
    case 'weekend_day':
      return 'Weekend Day Shift';
    case 'weekend_night':
      return 'Weekend Night Shift';
    default:
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

.loading, .error-state {
  text-align: center;
  padding: 2rem;
}

.shift-info {
  border-left: 4px solid v-bind('getShiftColor()');
  
  &.archived-shift {
    border-left-color: #9e9e9e;
  }
}

.shift-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  
  h2 {
    margin-top: 0;
    margin-bottom: 0.5rem;
    display: flex;
    align-items: center;
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
    gap: 0.5rem;
    margin-top: 1rem;
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
    background-color: #9e9e9e;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#9e9e9e, $lightness: -10%);
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
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  
  &-content {
    background-color: white;
    border-radius: 6px;
    width: 90%;
    max-width: 500px;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
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
  }
  
  &-footer {
    padding: 1rem;
    border-top: 1px solid #e0e0e0;
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
  }
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  
  @media (max-width: 500px) {
    grid-template-columns: 1fr;
  }
}

.form-group {
  margin-bottom: 1rem;
  
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

/* Floating Action Button */
.floating-action-button {
  position: fixed;
  bottom: 24px;
  right: 24px;
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
  z-index: 900;
  
  &:hover {
    transform: scale(1.05);
    filter: brightness(0.9);
    box-shadow: 0 6px 12px rgba(0, 0, 0, 0.3);
  }
  
  &:active {
    transform: scale(0.95);
  }
  
  .plus-icon {
    font-size: 32px;
    font-weight: 300;
    line-height: 1;
  }
}
</style>
