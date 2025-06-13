<template>
  <div class="tasks-tab">
    
    <!-- Tasks List -->
    <div class="tasks-container">
      <!-- Task Tabs and Actions -->
      <div class="tasks-header">
        <div class="task-tabs" ref="tabsContainerRef">
          <motion.button 
            @click="setActiveTab('completed')" 
            class="tab-button" 
            :class="{ active: activeTab === 'completed' }"
            ref="completedTabRef"
            :animate="activeTab === 'completed' ? activeStyle : inactiveStyle"
            :transition="{ 
              type: 'spring',
              stiffness: 300,
              damping: 30
            }"
          >
            Completed ({{ completedTasks.length }})
          </motion.button>
          <motion.button 
            @click="setActiveTab('pending')" 
            class="tab-button" 
            :class="{ active: activeTab === 'pending' }"
            ref="pendingTabRef"
            :animate="activeTab === 'pending' ? activeStyle : inactiveStyle"
            :transition="{ 
              type: 'spring',
              stiffness: 300,
              damping: 30
            }"
          >
            Pending ({{ pendingTasks.length }})
          </motion.button>
          
          <!-- Sliding active indicator -->
          <motion.div 
            class="active-indicator"
            :animate="{ 
              x: indicatorPosition, 
              width: indicatorWidth,
              opacity: 1
            }"
            :initial="{ opacity: 0 }"
            :transition="{ 
              type: 'spring', 
              stiffness: 500, 
              damping: 30 
            }"
          ></motion.div>
        </div>
        
        <button 
          @click="showActivitySheet" 
          class="btn btn-primary activity-sheet-btn"
          :disabled="allTasks.length === 0"
          title="View and print activity sheet"
        >
          Activity Sheet
        </button>
      </div>
      
      <!-- Task Content -->
      <div class="tasks-content-wrapper">
        <!-- Pending Tasks -->
        <motion.div 
          v-if="activeTab === 'pending'" 
          class="tasks-list"
          :initial="{ opacity: 0, x: transitionDirection * 40 }"
          :animate="{ opacity: 1, x: 0 }"
          :exit="{ opacity: 0, x: -transitionDirection * 40 }"
          :transition="{ 
            type: 'spring', 
            stiffness: 300, 
            damping: 30,
            mass: 1
          }"
          :key="'pending-list'"
        >
          <div v-if="pendingTasks.length === 0" class="empty-state">
            <p>No pending tasks.</p>
          </div>
          
          <div 
            v-for="task in pendingTasks" 
            :key="task.id" 
            class="task-item pending"
          >
            <div class="task-details">
              <h3 class="task-name">{{ task.task_item.task_type?.name || 'Unknown' }}</h3>
              
              <div class="task-meta">
                <div class="meta-group">
                  <div v-if="task.origin_department" class="meta-item">
                    <strong>From:</strong> {{ task.origin_department.name }}
                  </div>
                  <div v-if="task.destination_department" class="meta-item">
                    <strong>To:</strong> {{ task.destination_department.name }}
                  </div>
                  <div class="meta-item">
                    <strong>Type:</strong> {{ task.task_item.name }}
                  </div>
                </div>
                
                <div class="meta-group">
                  <div class="meta-item">
                    <strong>Received:</strong> {{ formatTime(task.time_received) }}
                  </div>
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
        </motion.div>
        
        <!-- Completed Tasks -->
        <motion.div 
          v-if="activeTab === 'completed'" 
          class="tasks-list"
          :initial="{ opacity: 0, x: transitionDirection * 40 }"
          :animate="{ opacity: 1, x: 0 }"
          :exit="{ opacity: 0, x: -transitionDirection * 40 }"
          :transition="{ 
            type: 'spring', 
            stiffness: 300, 
            damping: 30,
            mass: 1
          }"
          :key="'completed-list'"
        >
          <div v-if="completedTasks.length === 0" class="empty-state">
            <p>No completed tasks.</p>
          </div>
          
          <div 
            v-for="task in completedTasks" 
            :key="task.id" 
            class="task-item completed"
          >
            <div class="task-details">
              <h3 class="task-name">{{ task.task_item.task_type?.name || 'Unknown' }}</h3>
              
              <div class="task-meta">
                <div class="meta-group">
                  <div v-if="task.origin_department" class="meta-item">
                    <strong>From:</strong> {{ task.origin_department.name }}
                  </div>
                  <div v-if="task.destination_department" class="meta-item">
                    <strong>To:</strong> {{ task.destination_department.name }}
                  </div>
                  <div class="meta-item">
                    <strong>Type:</strong> {{ task.task_item.name }}
                  </div>
                </div>
                
                <div class="meta-group">
                  <div class="meta-item">
                    <strong>Received:</strong> {{ formatTime(task.time_received) }}
                  </div>
                  <div class="meta-item">
                    <strong>Completed:</strong> {{ formatTime(task.time_completed) }}
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
        </motion.div>
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
const activeTab = ref('pending');
const updatingTask = ref(false);
const transitionDirection = ref(1); // 1 for right-to-left, -1 for left-to-right

// Tab animation states
const tabsContainerRef = ref(null);
const completedTabRef = ref(null);
const pendingTabRef = ref(null);
const indicatorPosition = ref(0);
const indicatorWidth = ref(0);

// Define styles for active and inactive states
const activeStyle = {
  color: '#4285F4',
  fontWeight: '600'
};

const inactiveStyle = {
  color: '#666',
  fontWeight: '500'
};

// Computed properties
const pendingTasks = computed(() => shiftsStore.pendingTasks);
const completedTasks = computed(() => shiftsStore.completedTasks);
const allTasks = computed(() => [...pendingTasks.value, ...completedTasks.value]);
const currentShift = computed(() => shiftsStore.currentShift);

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
  
  const containerRect = tabsContainerRef.value.getBoundingClientRect();
  const activeTabRef = activeTab.value === 'completed' ? completedTabRef.value : pendingTabRef.value;
  
  if (!activeTabRef) return;
  
  const tabRect = activeTabRef.getBoundingClientRect();
  
  // Calculate position relative to the container
  indicatorPosition.value = tabRect.left - containerRect.left;
  indicatorWidth.value = tabRect.width;
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

// Initialize the indicator position
nextTick(() => {
  updateIndicatorPosition();
  
  // Update on window resize
  window.addEventListener('resize', updateIndicatorPosition);
});
</script>

<style lang="scss" scoped>
@use "sass:color";

.tasks-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.activity-sheet-btn {
  white-space: nowrap;
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
}

.task-tabs {
  display: flex;
  border-bottom: 1px solid #e0e0e0;
  margin-bottom: 1rem;
  position: relative;
  
  .tab-button {
    padding: 0.75rem 1rem;
    background: none;
    border: none;
    cursor: pointer;
    font-weight: 500;
    color: #666;
    position: relative;
    z-index: 1;
    
    &:hover:not(.active) {
      background-color: #f5f5f5;
    }
  }
  
  .active-indicator {
    position: absolute;
    bottom: -1px;
    height: 2px;
    background-color: #4285F4;
    z-index: 2;
  }
}

.tasks-content-wrapper {
  position: relative;
  overflow: hidden;
}

.tasks-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  position: relative;
  width: 100%;
}

.task-item {
  display: flex;
  justify-content: space-between;
  padding: 1rem;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  
  &.completed {
    background-color: #f1f8e9;
    border-left: 3px solid #34A853;
  }
  
  &.pending {
    background-color: #fefaf0;
    border-left: 3px solid #F4B400;
  }
  
  .task-details {
    flex: 1;
    
    .task-name {
      margin-top: 0;
      margin-bottom: 0.5rem;
      font-size: 0.95rem;
    }
  }
  
  .task-meta {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-top: 0.25rem;
    
    .meta-group {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
    }
    
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
    
    @media (min-width: 500px) {
      flex-direction: row;
      gap: 0.5rem;
    }
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
  
  &-warning {
    background-color: #F4B400;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#F4B400, $lightness: -10%);
    }
  }
  
  &-small {
    padding: 0.25rem 0.5rem;
    font-size: 0.9rem;
  }
}

.icon-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: opacity 0.2s, background-color 0.2s;
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
