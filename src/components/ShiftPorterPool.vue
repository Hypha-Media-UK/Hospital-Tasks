<template>
  <div class="shift-porter-pool">
    <div class="shift-porter-pool__header">
      <h3 class="section-title">Shift Porters</h3>
      <button class="btn btn--primary" @click="showPorterSelector = true">
        Add Porter
      </button>
    </div>
    
    <div v-if="shiftsStore.loading.porterPool" class="loading">
      Loading shift porters...
    </div>
    
    <div v-else-if="porterPool.length === 0" class="empty-state">
      No porters assigned to this shift yet. Add porters using the button above.
    </div>
    
    <div v-else class="porter-grid">
      <div v-for="entry in porterPool" :key="entry.id" class="porter-card">
        <div class="porter-card__content">
          <div class="porter-card__name">
            {{ entry.porter.first_name }} {{ entry.porter.last_name }}
          </div>
          
          <div class="porter-card__assignments">
            <div v-if="getPorterAssignments(entry.porter_id).length > 0" class="assignments-list">
              <div v-for="assignment in getPorterAssignments(entry.porter_id)" :key="assignment.id" class="assignment-item">
                {{ assignment.department?.name || 'Unknown Department' }} ({{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }})
              </div>
            </div>
            <div v-else class="no-assignments">
              Not assigned to any departments
            </div>
          </div>
        </div>
        
        <div class="porter-card__actions">
          <button 
            @click="removePorter(entry.id)" 
            class="btn btn--icon btn--danger"
            title="Remove porter from shift"
          >
            <span class="icon">🗑️</span>
          </button>
        </div>
      </div>
    </div>
    
    <!-- Porter Selector Modal -->
    <div v-if="showPorterSelector" class="modal-overlay" @click.self="showPorterSelector = false">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">Add Porters to Shift</h3>
          <button class="modal-close" @click="showPorterSelector = false">&times;</button>
        </div>
        
        <div class="modal-body">
          <div v-if="availablePorters.length === 0" class="empty-state">
            No porters available to add. All porters are already assigned to this shift or are assigned to departments in settings.
          </div>
          
          <div v-else class="porter-selector">
            <div class="select-all-container">
              <label class="checkbox-container">
                <input 
                  type="checkbox" 
                  :checked="isAllSelected" 
                  @change="toggleSelectAll"
                >
                <span class="checkmark"></span>
                <span class="select-all-text">Select All Porters</span>
              </label>
              <span v-if="selectedPorters.length > 0" class="selected-count">
                {{ selectedPorters.length }} porter{{ selectedPorters.length > 1 ? 's' : '' }} selected
              </span>
            </div>
            
            <div v-for="porter in availablePorters" :key="porter.id" class="porter-item">
              <label class="checkbox-container">
                <input 
                  type="checkbox" 
                  :value="porter.id" 
                  v-model="selectedPorters"
                >
                <span class="checkmark"></span>
              </label>
              <div class="porter-name">{{ porter.first_name }} {{ porter.last_name }}</div>
            </div>
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            class="btn btn--secondary" 
            @click="showPorterSelector = false"
          >
            Cancel
          </button>
          <button 
            class="btn btn--primary" 
            @click="addSelectedPorters"
            :disabled="selectedPorters.length === 0 || addingPorters"
          >
            {{ addingPorters ? 'Adding...' : 'Add Selected Porters' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useShiftsStore } from '../stores/shiftsStore';
import { useStaffStore } from '../stores/staffStore';
import { useAreaCoverStore } from '../stores/areaCoverStore';

const props = defineProps({
  shiftId: {
    type: String,
    required: true
  }
});

const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();
const areaCoverStore = useAreaCoverStore();

const showPorterSelector = ref(false);
const selectedPorters = ref([]);
const addingPorters = ref(false);

// Computed properties
const porterPool = computed(() => {
  return shiftsStore.shiftPorterPool || [];
});

const availablePorters = computed(() => {
  // Get all porters
  const allPorters = staffStore.porters || [];
  
  // Get porters already in the pool
  const poolPorterIds = porterPool.value.map(p => p.porter_id);
  
  // Get porters assigned to departments in settings
  // Combine all area cover assignments from different shift types
  const allAreaCovers = [
    ...areaCoverStore.weekDayAssignments,
    ...areaCoverStore.weekNightAssignments,
    ...areaCoverStore.weekendDayAssignments,
    ...areaCoverStore.weekendNightAssignments
  ];
  
  const departmentPorterIds = allAreaCovers
    .filter(a => a.porter_id)
    .map(a => a.porter_id);
  
  // Return porters not in either list
  return allPorters.filter(p => 
    !poolPorterIds.includes(p.id) && 
    !departmentPorterIds.includes(p.id)
  );
});

// Check if all porters are selected
const isAllSelected = computed(() => {
  return availablePorters.value.length > 0 && 
         selectedPorters.value.length === availablePorters.value.length;
});

// Methods
const addPorter = async (porterId) => {
  await shiftsStore.addPorterToShift(props.shiftId, porterId);
  showPorterSelector.value = false;
};

// Add multiple selected porters at once
const addSelectedPorters = async () => {
  if (selectedPorters.value.length === 0 || addingPorters.value) return;
  
  addingPorters.value = true;
  
  try {
    // Process each porter sequentially
    for (const porterId of selectedPorters.value) {
      await shiftsStore.addPorterToShift(props.shiftId, porterId);
    }
    
    // Reset selection and close modal
    selectedPorters.value = [];
    showPorterSelector.value = false;
  } catch (error) {
    console.error('Error adding porters to shift:', error);
  } finally {
    addingPorters.value = false;
  }
};

// Toggle select all porters
const toggleSelectAll = () => {
  if (isAllSelected.value) {
    // Deselect all
    selectedPorters.value = [];
  } else {
    // Select all
    selectedPorters.value = availablePorters.value.map(porter => porter.id);
  }
};

const removePorter = async (porterPoolId) => {
  if (confirm('Are you sure you want to remove this porter from the shift?')) {
    await shiftsStore.removePorterFromShift(porterPoolId);
  }
};

const getPorterAssignments = (porterId) => {
  // Get assignments for this porter in this shift
  return shiftsStore.shiftAreaCoverPorterAssignments.filter(
    a => a.porter_id === porterId
  );
};

// Format time (e.g., "9:30 AM")
const formatTime = (timeStr) => {
  if (!timeStr) return '';
  
  // Convert "HH:MM:SS" to "HH:MM AM/PM"
  const [hours, minutes] = timeStr.split(':');
  const hoursNum = parseInt(hours, 10);
  const period = hoursNum >= 12 ? 'PM' : 'AM';
  const hours12 = hoursNum % 12 || 12;
  
  return `${hours12}:${minutes} ${period}`;
};

// Reset selected porters when modal is closed
watch(showPorterSelector, (isOpen) => {
  if (!isOpen) {
    selectedPorters.value = [];
  }
});

// Lifecycle hooks
onMounted(async () => {
  // Load porter pool data
  await shiftsStore.fetchShiftPorterPool(props.shiftId);
  
  // Load porters if not already loaded
  if (!staffStore.porters.length) {
    await staffStore.fetchPorters();
  }
  
  // Load area cover assignments if not already loaded
  if (areaCoverStore.weekDayAssignments.length === 0) {
    await areaCoverStore.initialize();
  }
  
  // Also load area cover assignments for this shift
  await shiftsStore.fetchShiftAreaCover(props.shiftId);
});
</script>

<style lang="scss" scoped>
@use '../assets/scss/mixins' as mix;

.shift-porter-pool {
  &__header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }
}

.section-title {
  font-size: 1.25rem;
  font-weight: 600;
  margin: 0;
}

.loading, .empty-state {
  padding: 24px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
}

.porter-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 16px;
}

.porter-card {
  display: flex;
  justify-content: space-between;
  padding: 12px 16px;
  background-color: white;
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
  
  &__content {
    flex: 1;
  }
  
  &__name {
    font-weight: 600;
    margin-bottom: 8px;
  }
  
  &__assignments {
    font-size: 0.9rem;
    color: rgba(0, 0, 0, 0.6);
    
    .assignments-list {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    
    .assignment-item {
      background-color: rgba(66, 133, 244, 0.1);
      padding: 2px 8px;
      border-radius: 4px;
      display: inline-block;
    }
    
    .no-assignments {
      font-style: italic;
    }
  }
  
  &__actions {
    display: flex;
    align-items: flex-start;
  }
}

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
  border-radius: 8px;
  width: 90%;
  max-width: 500px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  overflow: hidden;
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
  font-size: 1.25rem;
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
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.porter-selector {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.select-all-container {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 12px;
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: 6px;
  margin-bottom: 8px;
  
  .select-all-text {
    font-weight: 500;
    margin-left: 8px;
  }
  
  .selected-count {
    font-size: 0.9rem;
    color: #4285F4;
    font-weight: 500;
    padding: 2px 8px;
    background-color: rgba(66, 133, 244, 0.1);
    border-radius: 100px;
  }
}

.porter-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 6px;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.02);
  }
  
  .porter-name {
    margin-left: 8px;
  }
}

/* Checkbox styling */
.checkbox-container {
  display: flex;
  align-items: center;
  position: relative;
  cursor: pointer;
  user-select: none;
  
  input {
    position: absolute;
    opacity: 0;
    cursor: pointer;
    height: 0;
    width: 0;
  }
  
  .checkmark {
    position: relative;
    height: 20px;
    width: 20px;
    background-color: #fff;
    border: 2px solid #ccc;
    border-radius: 4px;
    transition: all 0.2s;
    
    &:after {
      content: "";
      position: absolute;
      display: none;
      left: 6px;
      top: 2px;
      width: 5px;
      height: 10px;
      border: solid white;
      border-width: 0 2px 2px 0;
      transform: rotate(45deg);
    }
  }
  
  input:checked ~ .checkmark {
    background-color: #4285F4;
    border-color: #4285F4;
  }
  
  input:checked ~ .checkmark:after {
    display: block;
  }
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: #4285F4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#4285F4, 10%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: #333;
    
    &:hover:not(:disabled) {
      background-color: darken(#f1f1f1, 5%);
    }
  }
  
  &--danger {
    color: #EA4335;
    
    &:hover:not(:disabled) {
      background-color: rgba(234, 67, 53, 0.1);
    }
  }
  
  &--small {
    padding: 4px 10px;
    font-size: 0.9rem;
  }
  
  &--icon {
    padding: 6px;
    background: transparent;
    
    .icon {
      font-size: 16px;
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
