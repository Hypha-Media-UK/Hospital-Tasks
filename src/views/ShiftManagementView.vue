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
        </div>
        
        <!-- Tasks Section -->
        <div class="card">
          <div class="tasks-header">
            <h2 class="card__title">Tasks</h2>
            <div v-if="shift.is_active" class="tasks-actions">
              <button @click="showAddTaskModal = true" class="btn btn-primary">
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
                  </div>
                </div>
                
                <div class="task-actions">
                  <button 
                    @click="assignPorter(task)" 
                    class="btn btn-small btn-outline"
                    :disabled="updatingTask"
                  >
                    {{ task.porter ? 'Reassign' : 'Assign Porter' }}
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
                      <strong>Completed:</strong> {{ formatTime(task.updated_at) }}
                    </div>
                  </div>
                </div>
                
                <div class="task-actions">
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
      
      <!-- Add Task Modal -->
      <div v-if="showAddTaskModal" class="modal">
        <div class="modal-content">
          <div class="modal-header">
            <h2>Add New Task</h2>
            <button @click="showAddTaskModal = false" class="close-button">&times;</button>
          </div>
          
          <div class="modal-body">
            <div class="form-group">
              <label for="taskType">Task Type</label>
              <select id="taskType" v-model="newTask.taskTypeId" class="form-control" @change="loadTaskItems">
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
                v-model="newTask.taskItemId" 
                class="form-control"
                :disabled="!newTask.taskTypeId || loadingTaskItems"
              >
                <option value="">{{ loadingTaskItems ? 'Loading items...' : 'Select a task item' }}</option>
                <option v-for="item in taskItems" :key="item.id" :value="item.id">
                  {{ item.name }}
                </option>
              </select>
            </div>
            
            <div class="form-group">
              <label for="originDepartment">Origin Department</label>
              <select id="originDepartment" v-model="newTask.originDepartmentId" class="form-control">
                <option value="">Select origin department (optional)</option>
                <option v-for="dept in departments" :key="dept.id" :value="dept.id">
                  {{ dept.name }}
                </option>
              </select>
            </div>
            
            <div class="form-group">
              <label for="destinationDepartment">Destination Department</label>
              <select id="destinationDepartment" v-model="newTask.destinationDepartmentId" class="form-control">
                <option value="">Select destination department (optional)</option>
                <option v-for="dept in departments" :key="dept.id" :value="dept.id">
                  {{ dept.name }}
                </option>
              </select>
            </div>
            
            <div class="form-group">
              <label for="porter">Assign Porter</label>
              <select id="porter" v-model="newTask.porterId" class="form-control">
                <option value="">Select porter (optional)</option>
                <option v-for="porter in porters" :key="porter.id" :value="porter.id">
                  {{ porter.first_name }} {{ porter.last_name }}
                </option>
              </select>
            </div>
            
            <div class="form-group">
              <label for="status">Status</label>
              <select id="status" v-model="newTask.status" class="form-control">
                <option value="pending">Pending</option>
                <option value="completed">Completed</option>
              </select>
            </div>
          </div>
          
          <div class="modal-footer">
            <button @click="addTask" class="btn btn-primary" :disabled="!canAddTask || addingTask">
              {{ addingTask ? 'Adding...' : 'Add Task' }}
            </button>
            <button @click="showAddTaskModal = false" class="btn btn-secondary" :disabled="addingTask">
              Cancel
            </button>
          </div>
          
          <div v-if="addTaskError" class="error-message">
            {{ addTaskError }}
          </div>
        </div>
      </div>
      
      <!-- Assign Porter Modal -->
      <div v-if="showAssignPorterModal" class="modal">
        <div class="modal-content">
          <div class="modal-header">
            <h2>Assign Porter</h2>
            <button @click="showAssignPorterModal = false" class="close-button">&times;</button>
          </div>
          
          <div class="modal-body">
            <div class="form-group">
              <label for="assignPorter">Select Porter</label>
              <select id="assignPorter" v-model="selectedPorterId" class="form-control">
                <option value="">Select porter</option>
                <option v-for="porter in porters" :key="porter.id" :value="porter.id">
                  {{ porter.first_name }} {{ porter.last_name }}
                </option>
              </select>
            </div>
          </div>
          
          <div class="modal-footer">
            <button @click="confirmAssignPorter" class="btn btn-primary" :disabled="!selectedPorterId || assigningPorter">
              {{ assigningPorter ? 'Assigning...' : 'Assign' }}
            </button>
            <button @click="showAssignPorterModal = false" class="btn btn-secondary" :disabled="assigningPorter">
              Cancel
            </button>
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

const route = useRoute();
const router = useRouter();
const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const taskTypesStore = useTaskTypesStore();
const locationsStore = useLocationsStore();

// Local state
const loading = ref(true);
const activeTab = ref('pending');
const showEndShiftConfirm = ref(false);
const endingShift = ref(false);
const showAddTaskModal = ref(false);
const loadingTaskItems = ref(false);
const addingTask = ref(false);
const addTaskError = ref('');
const updatingTask = ref(false);
const showAssignPorterModal = ref(false);
const assigningPorter = ref(false);
const selectedPorterId = ref('');
const selectedTaskId = ref('');
const taskItems = ref([]);

// New task form data
const newTask = ref({
  taskTypeId: '',
  taskItemId: '',
  originDepartmentId: '',
  destinationDepartmentId: '',
  porterId: '',
  status: 'pending'
});

// Computed properties
const shift = computed(() => shiftsStore.currentShift);
const pendingTasks = computed(() => shiftsStore.pendingTasks);
const completedTasks = computed(() => shiftsStore.completedTasks);
const porters = computed(() => staffStore.sortedPorters);
const taskTypes = computed(() => taskTypesStore.taskTypes);
const departments = computed(() => locationsStore.departments);
const canAddTask = computed(() => newTask.value.taskItemId);

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

async function loadTaskItems() {
  if (!newTask.value.taskTypeId) {
    taskItems.value = [];
    return;
  }
  
  loadingTaskItems.value = true;
  
  try {
    await taskTypesStore.fetchTaskItemsByType(newTask.value.taskTypeId);
    taskItems.value = taskTypesStore.getTaskItemsByType(newTask.value.taskTypeId);
  } catch (error) {
    console.error('Error loading task items:', error);
  } finally {
    loadingTaskItems.value = false;
  }
}

async function addTask() {
  if (!canAddTask.value || addingTask.value) return;
  
  addingTask.value = true;
  addTaskError.value = '';
  
  try {
    // Transform form data to match the API requirements
    const taskData = {
      taskItemId: newTask.value.taskItemId,
      porterId: newTask.value.porterId || null,
      originDepartmentId: newTask.value.originDepartmentId || null,
      destinationDepartmentId: newTask.value.destinationDepartmentId || null,
      status: newTask.value.status
    };
    
    const result = await shiftsStore.addTaskToShift(shift.value.id, taskData);
    
    if (result) {
      // Reset form and close modal
      resetTaskForm();
      showAddTaskModal.value = false;
    } else {
      addTaskError.value = shiftsStore.error || 'Failed to add task';
    }
  } catch (error) {
    console.error('Error adding task:', error);
    addTaskError.value = 'An unexpected error occurred';
  } finally {
    addingTask.value = false;
  }
}

function resetTaskForm() {
  newTask.value = {
    taskTypeId: '',
    taskItemId: '',
    originDepartmentId: '',
    destinationDepartmentId: '',
    porterId: '',
    status: 'pending'
  };
  taskItems.value = [];
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

function assignPorter(task) {
  selectedTaskId.value = task.id;
  selectedPorterId.value = task.porter ? task.porter.id : '';
  showAssignPorterModal.value = true;
}

async function confirmAssignPorter() {
  if (!selectedTaskId.value || assigningPorter.value) return;
  
  assigningPorter.value = true;
  
  try {
    await shiftsStore.assignPorterToTask(selectedTaskId.value, selectedPorterId.value || null);
    showAssignPorterModal.value = false;
  } catch (error) {
    console.error('Error assigning porter:', error);
  } finally {
    assigningPorter.value = false;
  }
}

// Format date and time (e.g., "May 23, 2025, 9:30 AM")
function formatDateTime(dateString) {
  if (!dateString) return '';
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

// Format time (e.g., "9:30 AM")
function formatTime(dateString) {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
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
