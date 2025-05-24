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
                {{ shift.shift_type === 'day' ? 'Day' : 'Night' }} Shift
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
          
          <!-- Area Coverage Section (Nested inside shift-info) -->
          <div class="shift-area-coverage">
            <h3 class="section-title">Area Coverage</h3>
            <ShiftAreaCoverList 
              :shift-id="shift.id" 
              :shift-type="determineAreaCoverType(shift)"
              :show-header="false"
            />
          </div>
        </div>
        
        <!-- Porter Pool Section -->
        <div class="card mb-4">
          <ShiftPorterPool :shift-id="shift.id" />
        </div>
        
        <!-- Tasks Section -->
        <div class="card">
          <div class="tasks-header">
            <h2 class="card__title">Tasks</h2>
            <div v-if="shift.is_active" class="tasks-actions">
              <button @click="showAddTaskModal()" class="btn btn-primary">
                Add Task
              </button>
            </div>
          </div>
          
          <!-- Task Tabs -->
          <div class="task-tabs">
            <button 
              @click="activeTab = 'pending'" 
              class="tab-button" 
              :class="{ active: activeTab === 'pending' }"
            >
              Pending ({{ pendingTasks.length }})
            </button>
            <button 
              @click="activeTab = 'completed'" 
              class="tab-button" 
              :class="{ active: activeTab === 'completed' }"
            >
              Completed ({{ completedTasks.length }})
            </button>
          </div>
          
          <!-- Tasks List -->
          <div class="tasks-container">
            <!-- Pending Tasks -->
            <div v-if="activeTab === 'pending'" class="tasks-list">
              <div v-if="pendingTasks.length === 0" class="empty-state">
                <p>No pending tasks.</p>
              </div>
              
              <div 
                v-for="task in pendingTasks" 
                :key="task.id" 
                class="task-item"
              >
                <div class="task-details">
                  <h3 class="task-name">{{ task.task_item.name }}</h3>
                  <p v-if="task.task_item.description" class="task-description">
                    {{ task.task_item.description }}
                  </p>
                  
                  <div class="task-meta">
                    <div v-if="task.origin_department" class="meta-item">
                      <strong>From:</strong> {{ task.origin_department.name }}
                    </div>
                    <div v-if="task.destination_department" class="meta-item">
                      <strong>To:</strong> {{ task.destination_department.name }}
                    </div>
                    <div class="meta-item">
                      <strong>Porter:</strong> 
                      <span v-if="task.porter">
                        {{ task.porter.first_name }} {{ task.porter.last_name }}
                      </span>
                      <span v-else class="not-assigned">Not assigned</span>
                    </div>
                    <div class="meta-item">
                      <strong>Received:</strong> {{ formatTime(task.time_received) }}
                    </div>
                    <div class="meta-item">
                      <strong>Allocated:</strong> {{ formatTime(task.time_allocated) }}
                    </div>
                    <div class="meta-item">
                      <strong>Expected completion:</strong> {{ formatTime(task.time_completed) }}
                    </div>
                  </div>
                </div>
                
                <div class="task-actions">
                  <button 
                    @click="editTask(task)" 
                    class="btn btn-small btn-primary"
                    :disabled="updatingTask"
                  >
                    Edit
                  </button>
                  <button 
                    @click="markTaskCompleted(task.id)" 
                    class="btn btn-small btn-success"
                    :disabled="updatingTask"
                  >
                    Mark Completed
                  </button>
                </div>
              </div>
            </div>
            
            <!-- Completed Tasks -->
            <div v-if="activeTab === 'completed'" class="tasks-list">
              <div v-if="completedTasks.length === 0" class="empty-state">
                <p>No completed tasks.</p>
              </div>
              
              <div 
                v-for="task in completedTasks" 
                :key="task.id" 
                class="task-item completed"
              >
                <div class="task-details">
                  <h3 class="task-name">{{ task.task_item.name }}</h3>
                  <p v-if="task.task_item.description" class="task-description">
                    {{ task.task_item.description }}
                  </p>
                  
                  <div class="task-meta">
                    <div v-if="task.origin_department" class="meta-item">
                      <strong>From:</strong> {{ task.origin_department.name }}
                    </div>
                    <div v-if="task.destination_department" class="meta-item">
                      <strong>To:</strong> {{ task.destination_department.name }}
                    </div>
                    <div class="meta-item">
                      <strong>Porter:</strong> 
                      <span v-if="task.porter">
                        {{ task.porter.first_name }} {{ task.porter.last_name }}
                      </span>
                      <span v-else class="not-assigned">Not assigned</span>
                    </div>
                    <div class="meta-item">
                      <strong>Received:</strong> {{ formatTime(task.time_received) }}
                    </div>
                    <div class="meta-item">
                      <strong>Allocated:</strong> {{ formatTime(task.time_allocated) }}
                    </div>
                    <div class="meta-item">
                      <strong>Completed:</strong> {{ formatTime(task.time_completed) }}
                    </div>
                  </div>
                </div>
                
                <div class="task-actions">
                  <button 
                    @click="editTask(task)" 
                    class="btn btn-small btn-primary"
                    :disabled="updatingTask"
                  >
                    Edit
                  </button>
                  <button 
                    @click="markTaskPending(task.id)" 
                    class="btn btn-small btn-outline"
                    :disabled="updatingTask"
                  >
                    Mark Pending
                  </button>
                </div>
              </div>
            </div>
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
                <select id="originDepartment" v-model="taskForm.originDepartmentId" class="form-control">
                  <option value="">Select origin department (optional)</option>
                  <option v-for="dept in departments" :key="dept.id" :value="dept.id">
                    {{ dept.name }}
                  </option>
                </select>
              </div>
              
              <div class="form-group">
                <label for="destinationDepartment">To</label>
                <select id="destinationDepartment" v-model="taskForm.destinationDepartmentId" class="form-control">
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
import ShiftAreaCoverList from '../components/area-cover/ShiftAreaCoverList.vue';
import ShiftPorterPool from '../components/ShiftPorterPool.vue';

const route = useRoute();
const router = useRouter();
const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const taskTypesStore = useTaskTypesStore();
const locationsStore = useLocationsStore();
const settingsStore = useSettingsStore();

// Local state
const loading = ref(true);
const activeTab = ref('pending');
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
  
  try {
    const shiftId = route.params.id;
    
    // Load shift and its tasks
    await shiftsStore.fetchShiftById(shiftId);
    if (shiftsStore.currentShift) {
      await shiftsStore.fetchShiftTasks(shiftId);
    }
    
    // Load supporting data for task management
    await Promise.all([
      staffStore.fetchPorters(),
      taskTypesStore.fetchTaskTypes(),
      locationsStore.fetchDepartments()
    ]);
  } catch (error) {
    console.error('Error loading shift data:', error);
  } finally {
    loading.value = false;
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

// Methods
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
function showAddTaskModal() {
  isEditingTask.value = false;
  editingTaskId.value = null;
  resetTaskForm();
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
  } catch (error) {
    console.error('Error loading task items:', error);
  } finally {
    loadingTaskItems.value = false;
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
function formatTime(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  
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
}

// Format time for time input (HH:MM)
function formatDateTimeForInput(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  
  // Get time parts
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  
  // Format for time input (HH:MM)
  return `${hours}:${minutes}`;
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

// Determine the appropriate area cover type for a shift
function determineAreaCoverType(shift) {
  if (!shift) return 'week_day'; // Default to week_day if no shift
  
  // Get the shift start time
  const shiftStart = new Date(shift.start_time);
  
  // Determine if it's a weekend
  const isWeekendDay = isWeekend(shiftStart);
  
  // Get shift type from the shift
  const isDaytime = shift.shift_type === 'day';
  
  // Combine to get the appropriate area cover type
  if (isWeekendDay) {
    return isDaytime ? 'weekend_day' : 'weekend_night';
  } else {
    return isDaytime ? 'week_day' : 'week_night';
  }
}

// Helper function to determine if a date is on a weekend
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}
</script>

<style lang="scss" scoped>
.mb-4 {
  margin-bottom: 1rem;
}

.loading, .error-state {
  text-align: center;
  padding: 2rem;
}

.shift-info {
  border-left: 4px solid #4285F4;
  
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
      background-color: darken(#4285F4, 10%);
    }
  }
  
  &-secondary {
    background-color: #9e9e9e;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#9e9e9e, 10%);
    }
  }
  
  &-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#dc3545, 10%);
    }
  }
  
  &-success {
    background-color: #34A853;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#34A853, 10%);
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
      background-color: darken(#FBBC05, 10%);
    }
  }
  
  &.completed-btn {
    background-color: #34A853;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#34A853, 10%);
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
</style>
