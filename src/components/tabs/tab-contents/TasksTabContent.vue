<template>
  <div class="tasks-tab">
    
    <!-- Tasks List -->
    <div class="tasks-container">
      <!-- Task Tabs and Actions -->
      <div class="tasks-header">
        <AnimatedTabs
          v-model="activeTab"
          :tabs="tabDefinitions"
          @tab-change="handleTabChange"
          class="task-tabs"
        >
          <!-- Pending Tasks -->
          <template #pending>
            <div class="tasks-list">
              <div v-if="pendingTasks.length === 0" class="empty-state">
                <p>No pending tasks.</p>
              </div>
              
              <div 
                v-for="task in pendingTasks" 
                :key="task.id" 
                class="task-item pending"
              >
                <div class="task-details">
                  <!-- <h3 class="task-name">{{ task.task_items.task_types?.name || 'Unknown' }}</h3> -->
                  
                  <div class="task-meta">
                    <div class="meta-line">
                      <span v-if="task.departments_shift_tasks_origin_department_idTodepartments">{{ task.departments_shift_tasks_origin_department_idTodepartments.name }}</span>
                      <span v-if="task.departments_shift_tasks_destination_department_idTodepartments"> - {{ task.departments_shift_tasks_destination_department_idTodepartments.name }}</span>
                      <span> || {{ task.task_items.name }}</span>
                      <span> || Porter{{ getTaskPorters(task).length > 1 ? 's' : '' }}: 
                        <span v-if="getTaskPorters(task).length === 0" class="not-assigned">Not assigned</span>
                        <span v-else>{{ formatPorterNames(getTaskPorters(task)) }}</span>
                      </span>
                    </div>
                    
                    <div class="meta-line">
                      <span>Received: {{ formatTime(task.time_received) }}</span>
                      <span> - Completed: <span class="not-completed">Not completed</span></span>
                    </div>
                  </div>
                </div>
                
                <div class="task-actions">
                  <button 
                    @click="editTask(task)" 
                    class="icon-btn btn-primary"
                    :disabled="updatingTask"
                    title="Edit Task"
                  >
                    <EditIcon :size="18" />
                  </button>
                  <button 
                    @click="markTaskCompleted(task.id)" 
                    class="icon-btn btn-success"
                    :disabled="updatingTask"
                    title="Mark as Completed"
                  >
                    <CheckIcon :size="18" />
                  </button>
                </div>
              </div>
            </div>
          </template>
          
          <!-- Completed Tasks -->
          <template #completed>
            <div class="tasks-list">
              <div v-if="completedTasks.length === 0" class="empty-state">
                <p>No completed tasks.</p>
              </div>
              
              <div 
                v-for="task in completedTasks" 
                :key="task.id" 
                class="task-item completed"
              >
                <div class="task-details">
                  <!-- <h3 class="task-name">{{ task.task_items.task_types?.name || 'Unknown' }}</h3> -->
                  
                  <div class="task-meta">
                    <div class="meta-line">
                      <strong><span>{{ task.task_items.name }}</span></strong>&nbsp;&nbsp;|&nbsp;&nbsp;
                      <span v-if="task.departments_shift_tasks_origin_department_idTodepartments">{{ task.departments_shift_tasks_origin_department_idTodepartments.name }}</span>
                      <span v-if="task.departments_shift_tasks_destination_department_idTodepartments"> - {{ task.departments_shift_tasks_destination_department_idTodepartments.name }}</span>
                    </div>
                    
                    <div class="meta-line">
                      <span>Received: {{ formatTime(task.time_received) }}</span>
                      <span> - Completed: {{ formatTime(task.time_completed) }}</span>
                      <span>&nbsp;&nbsp;|&nbsp;&nbsp;Porter{{ getTaskPorters(task).length > 1 ? 's' : '' }}:&nbsp;
                        <span v-if="getTaskPorters(task).length === 0" class="not-assigned">Not assigned</span>
                        <span v-else>{{ formatPorterNames(getTaskPorters(task)) }}</span>
                      </span>
                    </div>
                  </div>
                </div>
                
                <div class="task-actions">
                  <button 
                    @click="editTask(task)" 
                    class="icon-btn btn-primary"
                    :disabled="updatingTask"
                    title="Edit Task"
                  >
                    <EditIcon :size="18" />
                  </button>
                  <button 
                    @click="markTaskPending(task.id)" 
                    class="icon-btn btn-warning"
                    :disabled="updatingTask"
                    title="Mark as Pending"
                  >
                    <ClockIcon :size="18" />
                  </button>
                </div>
              </div>
            </div>
          </template>
        </AnimatedTabs>
        
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, nextTick } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { motion } from 'motion-v';
import { useShiftsStore } from '../../../stores/shiftsStore';
import { useSettingsStore } from '../../../stores/settingsStore';
import EditIcon from '../../icons/EditIcon.vue';
import CheckIcon from '../../icons/CheckIcon.vue';
import ClockIcon from '../../icons/ClockIcon.vue';
import AnimatedTabs from '../../shared/AnimatedTabs.vue';

// Define props to receive shift ID and functions from parent
const props = defineProps({
  shiftId: {
    type: String,
    required: true
  }
});

// Define emits to communicate with parent
const emit = defineEmits(['editTask', 'markTaskCompleted', 'markTaskPending']);

// Store instances
const shiftsStore = useShiftsStore();
const settingsStore = useSettingsStore();
const router = useRouter();

// Local state
const activeTab = ref('completed');
const updatingTask = ref(false);
const transitionDirection = ref(1); // 1 for right-to-left, -1 for left-to-right

// Tab animation states
const tabsContainerRef = ref(null);
const completedTabRef = ref(null);
const pendingTabRef = ref(null);
const indicatorPosition = ref(0);
const indicatorWidth = ref(0);

// Define styles for active and inactive states
// Font weight is now handled via CSS classes instead of animation
const activeStyle = {
  color: '#4285F4'
};

const inactiveStyle = {
  color: '#666'
};

// Computed properties
const pendingTasks = computed(() => shiftsStore.pendingTasks);
const completedTasks = computed(() => shiftsStore.completedTasks);
const allTasks = computed(() => [...pendingTasks.value, ...completedTasks.value]);
const currentShift = computed(() => shiftsStore.currentShift);

// Tab definitions for the AnimatedTabs component
const tabDefinitions = computed(() => [
  { id: 'completed', label: `Completed (${completedTasks.value.length})` },
  { id: 'pending', label: `Pending (${pendingTasks.value.length})` }
]);

// Handle tab change events from the AnimatedTabs component
function handleTabChange(tabId) {
  // Calculate transition direction
  if (activeTab.value === 'pending' && tabId === 'completed') {
    transitionDirection.value = -1; // Moving left
  } else if (activeTab.value === 'completed' && tabId === 'pending') {
    transitionDirection.value = 1; // Moving right
  }
}

// Methods
function editTask(task) {
  emit('editTask', task);
}

function showActivitySheet() {
  // Navigate to the activity sheet view
  router.push(`/shift/${props.shiftId}/activity-sheet`);
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

function setActiveTab(tabId) {
  // Calculate transition direction
  if (activeTab.value === 'pending' && tabId === 'completed') {
    transitionDirection.value = -1; // Moving left
  } else if (activeTab.value === 'completed' && tabId === 'pending') {
    transitionDirection.value = 1; // Moving right
  }
  
  activeTab.value = tabId;
  
  // Update indicator position
  nextTick(() => {
    updateIndicatorPosition();
  });
}

// Calculate the indicator position based on the active tab
function updateIndicatorPosition() {
  if (!tabsContainerRef.value) return;
  
  // Make sure tabsContainerRef is a DOM element with getBoundingClientRect method
  if (typeof tabsContainerRef.value.getBoundingClientRect !== 'function') return;
  
  const containerRect = tabsContainerRef.value.getBoundingClientRect();
  
  // Get the reference to the active tab
  const activeTabRef = activeTab.value === 'completed' ? completedTabRef.value : pendingTabRef.value;
  if (!activeTabRef) return;
  
  // Get the actual DOM element, whether from a property or direct ref
  const activeTabElement = activeTabRef.$el || activeTabRef;
  if (!activeTabElement || typeof activeTabElement.getBoundingClientRect !== 'function') return;
  
  const tabRect = activeTabElement.getBoundingClientRect();
  
  // Calculate position relative to the container
  indicatorPosition.value = tabRect.left - containerRect.left;
  indicatorWidth.value = tabRect.width;
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

// Format porter names for display
function formatPorterNames(porters) {
  if (!porters || porters.length === 0) return '';
  
  if (porters.length === 1) {
    return `${porters[0].first_name} ${porters[0].last_name}`;
  }
  
  if (porters.length === 2) {
    return `${porters[0].first_name} ${porters[0].last_name} & ${porters[1].first_name} ${porters[1].last_name}`;
  }
  
  // For 3 or more porters, show first two and count
  return `${porters[0].first_name} ${porters[0].last_name}, ${porters[1].first_name} ${porters[1].last_name} & ${porters.length - 2} more`;
}

// Format time for display in 24-hour format
function formatTime(timeString) {
  if (!timeString) return '';
  
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

// Initialize the indicator position
nextTick(() => {
  updateIndicatorPosition();
  
  // Update on window resize
  window.addEventListener('resize', updateIndicatorPosition);
});
</script>

<!-- Styles are now handled by the global CSS layers -->