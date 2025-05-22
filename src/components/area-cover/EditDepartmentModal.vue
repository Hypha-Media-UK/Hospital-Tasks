<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container">
      <div class="modal-header">
        <h3 class="modal-title">Edit {{ assignment.department.name }}</h3>
        <button class="modal-close" @click="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div class="department-info">
          <div class="department-name">{{ assignment.department.name }}</div>
          <div class="department-building">{{ assignment.department.building?.name || 'Unknown Building' }}</div>
        </div>
        
        <!-- Department Time settings -->
        <div class="section-title">Required Coverage Period</div>
        <div class="time-settings">
          <div class="time-group">
            <label for="startTime">Start Time</label>
            <input 
              type="time" 
              id="startTime" 
              v-model="startTime" 
              @change="updateTimes"
            />
          </div>
          
          <div class="time-group">
            <label for="endTime">End Time</label>
            <input 
              type="time" 
              id="endTime" 
              v-model="endTime" 
              @change="updateTimes"
            />
          </div>
        </div>
        
        <!-- Color picker -->
        <div class="color-settings">
          <label for="color">Color</label>
          <input 
            type="color" 
            id="color" 
            v-model="color" 
            @change="updateColor"
          />
        </div>
        
        <!-- Multiple Porter assignments -->
        <div class="porter-assignments">
          <div class="section-title">
            Porter Assignments
            <span v-if="hasCoverageGap" class="coverage-gap-indicator">
              Coverage Gap Detected
            </span>
          </div>
          
          <div v-if="porterAssignments.length === 0" class="empty-state">
            No porters assigned. Add a porter to provide coverage.
          </div>
          
          <div v-else class="porter-list">
            <div 
              v-for="porterAssignment in porterAssignments" 
              :key="porterAssignment.id"
              class="porter-assignment-item"
            >
              <div class="porter-pill">
                <span class="porter-name">
                  {{ porterAssignment.porter.first_name }} {{ porterAssignment.porter.last_name }}
                </span>
              </div>
              
              <div class="porter-times">
                <div class="time-group">
                  <input 
                    type="time" 
                    v-model="porterAssignment.start_time_display" 
                    @change="updatePorterTime(porterAssignment)"
                  />
                </div>
                <span class="time-separator">to</span>
                <div class="time-group">
                  <input 
                    type="time" 
                    v-model="porterAssignment.end_time_display" 
                    @change="updatePorterTime(porterAssignment)"
                  />
                </div>
              </div>
              
              <button 
                class="btn btn--icon" 
                title="Remove porter assignment"
                @click="removePorterAssignment(porterAssignment.id)"
              >
                &times;
              </button>
            </div>
          </div>
          
          <div class="add-porter">
            <div v-if="!showAddPorter" class="add-porter-button">
              <button 
                class="btn btn--primary" 
                @click="showAddPorter = true"
              >
                Add Porter
              </button>
            </div>
            
            <div v-else class="add-porter-form">
              <div class="form-row">
                <select v-model="newPorterAssignment.porter_id">
                  <option value="">-- Select Porter --</option>
                  <option 
                    v-for="porter in availablePorters" 
                    :key="porter.id" 
                    :value="porter.id"
                  >
                    {{ porter.first_name }} {{ porter.last_name }}
                  </option>
                </select>
                
                <div class="time-group">
                  <input 
                    type="time" 
                    v-model="newPorterAssignment.start_time"
                    placeholder="Start Time"
                  />
                </div>
                
                <div class="time-group">
                  <input 
                    type="time" 
                    v-model="newPorterAssignment.end_time"
                    placeholder="End Time"
                  />
                </div>
                
                <div class="action-buttons">
                  <button 
                    class="btn btn--small btn--primary" 
                    @click="addPorterAssignment"
                    :disabled="!newPorterAssignment.porter_id || !newPorterAssignment.start_time || !newPorterAssignment.end_time"
                  >
                    Add
                  </button>
                  <button 
                    class="btn btn--small btn--secondary" 
                    @click="showAddPorter = false"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <button 
          class="btn btn--danger" 
          @click="confirmRemove"
        >
          Remove
        </button>
        <button 
          class="btn btn--secondary" 
          @click="$emit('close')"
        >
          Close
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAreaCoverStore } from '../../stores/areaCoverStore';
import { useStaffStore } from '../../stores/staffStore';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'update', 'remove']);

const areaCoverStore = useAreaCoverStore();
const staffStore = useStaffStore();

// Local state
const startTime = ref('');
const endTime = ref('');
const color = ref('#4285F4');
const showAddPorter = ref(false);
const newPorterAssignment = ref({
  porter_id: '',
  start_time: '',
  end_time: ''
});

// Computed properties
const porterAssignments = computed(() => {
  const assignments = areaCoverStore.getPorterAssignmentsByAreaId(props.assignment.id);
  
  // Add display time properties for the UI
  return assignments.map(pa => ({
    ...pa,
    start_time_display: pa.start_time ? pa.start_time.slice(0, 5) : '',
    end_time_display: pa.end_time ? pa.end_time.slice(0, 5) : ''
  }));
});

const availablePorters = computed(() => {
  // Get all porters
  const allPorters = staffStore.sortedPorters || [];
  
  // Filter out porters that are already assigned to this area cover
  const assignedPorterIds = porterAssignments.value.map(pa => pa.porter_id);
  return allPorters.filter(porter => !assignedPorterIds.includes(porter.id));
});

const hasCoverageGap = computed(() => {
  return areaCoverStore.hasCoverageGap(props.assignment.id);
});

// Methods
const updateTimes = () => {
  emit('update', props.assignment.id, {
    start_time: startTime.value + ':00',
    end_time: endTime.value + ':00'
  });
};

const updateColor = () => {
  emit('update', props.assignment.id, { color: color.value });
};

const updatePorterTime = (porterAssignment) => {
  areaCoverStore.updatePorterAssignment(porterAssignment.id, {
    start_time: porterAssignment.start_time_display + ':00',
    end_time: porterAssignment.end_time_display + ':00'
  });
};

const addPorterAssignment = async () => {
  if (!newPorterAssignment.value.porter_id || 
      !newPorterAssignment.value.start_time || 
      !newPorterAssignment.value.end_time) {
    return;
  }
  
  await areaCoverStore.addPorterAssignment(
    props.assignment.id,
    newPorterAssignment.value.porter_id,
    newPorterAssignment.value.start_time + ':00',
    newPorterAssignment.value.end_time + ':00'
  );
  
  // Reset form
  newPorterAssignment.value = {
    porter_id: '',
    start_time: '',
    end_time: ''
  };
  
  showAddPorter.value = false;
};

const removePorterAssignment = async (porterAssignmentId) => {
  if (confirm('Are you sure you want to remove this porter assignment?')) {
    await areaCoverStore.removePorterAssignment(porterAssignmentId);
  }
};

const confirmRemove = () => {
  if (confirm(`Are you sure you want to remove ${props.assignment.department.name} from coverage?`)) {
    emit('remove', props.assignment.id);
  }
};

// Initialize component state from props
const initializeState = () => {
  // Parse times from HH:MM:SS format to HH:MM for the time input
  if (props.assignment.start_time) {
    startTime.value = props.assignment.start_time.slice(0, 5);
  }
  
  if (props.assignment.end_time) {
    endTime.value = props.assignment.end_time.slice(0, 5);
  }
  
  // Set color
  color.value = props.assignment.color || '#4285F4';
};

// Fetch porters if not already loaded
onMounted(async () => {
  initializeState();
  
  if (staffStore.porters.length === 0) {
    await staffStore.fetchPorters();
  }
});
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

// Modal styles
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-container {
  background-color: white;
  border-radius: mix.radius('lg');
  width: 90%;
  max-width: 550px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.modal-header {
  padding: 16px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  margin: 0;
  font-size: mix.font-size('lg');
  font-weight: 600;
}

.modal-close {
  background: transparent;
  border: none;
  font-size: 24px;
  cursor: pointer;
  padding: 0;
  line-height: 1;
}

.modal-body {
  padding: 16px;
  overflow-y: auto;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

// Section title
.section-title {
  font-weight: 600;
  font-size: mix.font-size('md');
  margin-bottom: 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

// Department info
.department-info {
  margin-bottom: 4px;
  
  .department-name {
    font-weight: 600;
    font-size: mix.font-size('lg');
  }
  
  .department-building {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
  }
}

// Time settings
.time-settings {
  display: flex;
  gap: 16px;
  
  .time-group {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
    
    label {
      font-size: mix.font-size('sm');
      font-weight: 500;
      color: rgba(0, 0, 0, 0.7);
    }
    
    input[type="time"] {
      padding: 6px 8px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('md');
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
      }
    }
  }
}

// Color settings
.color-settings {
  display: flex;
  flex-direction: column;
  gap: 4px;
  
  label {
    font-size: mix.font-size('sm');
    font-weight: 500;
    color: rgba(0, 0, 0, 0.7);
  }
  
  input[type="color"] {
    height: 32px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: mix.radius('sm');
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
}

// Porter assignments
.porter-assignments {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.empty-state {
  padding: 12px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
  background-color: rgba(0, 0, 0, 0.03);
  border-radius: mix.radius('md');
}

.porter-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.porter-assignment-item {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: mix.radius('md');
  background-color: white;
  
  .porter-pill {
    min-width: 120px;
    margin-right: 12px;
    
    .porter-name {
      display: inline-block;
      background-color: rgba(66, 133, 244, 0.1);
      color: mix.color('primary');
      border-radius: 100px;
      padding: 4px 12px;
      font-size: mix.font-size('sm');
      font-weight: 500;
      white-space: nowrap;
    }
  }
  
  .porter-times {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 8px;
    
    .time-group {
      input[type="time"] {
        padding: 4px 6px;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('sm');
        font-size: mix.font-size('sm');
      }
    }
    
    .time-separator {
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.6);
    }
  }
  
  .btn--icon {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    padding: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: rgba(0, 0, 0, 0.05);
    color: rgba(0, 0, 0, 0.6);
    
    &:hover {
      background-color: rgba(234, 67, 53, 0.1);
      color: #EA4335;
    }
  }
}

.add-porter {
  margin-top: 8px;
}

.add-porter-button {
  display: flex;
  justify-content: center;
}

.add-porter-form {
  padding: 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: mix.radius('md');
  background-color: rgba(0, 0, 0, 0.02);
  
  .form-row {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    align-items: center;
    
    select {
      flex: 1;
      min-width: 150px;
      padding: 6px 8px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('sm');
    }
    
    .time-group {
      width: 90px;
      
      input[type="time"] {
        width: 100%;
        padding: 6px 8px;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('sm');
        font-size: mix.font-size('sm');
      }
    }
    
    .action-buttons {
      display: flex;
      gap: 8px;
    }
  }
  
  @media (max-width: 600px) {
    .form-row {
      flex-direction: column;
      align-items: stretch;
      
      select, .time-group {
        width: 100%;
      }
      
      .action-buttons {
        margin-top: 8px;
        justify-content: flex-end;
      }
    }
  }
}

// Coverage gap indicator
.coverage-gap-indicator {
  background-color: rgba(234, 67, 53, 0.1);
  color: #EA4335;
  font-size: mix.font-size('xs');
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 100px;
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.adjust(mix.color('primary'), $lightness: -5%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: #e5e5e5;
    }
  }
  
  &--danger {
    background-color: rgba(234, 67, 53, 0.1);
    color: #EA4335;
    
    &:hover:not(:disabled) {
      background-color: rgba(234, 67, 53, 0.2);
    }
  }
  
  &--small {
    padding: 4px 8px;
    font-size: mix.font-size('sm');
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
