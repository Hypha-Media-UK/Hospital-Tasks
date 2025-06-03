<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">
          {{ editingPorterAssignment ? 'Edit Porter Assignment' : 'Add Porter' }}
        </h3>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div v-if="editingPorterAssignment" class="action-menu">
          <button 
            class="btn btn-sm btn-outline" 
            @click="openAbsenceModal"
          >
            Mark as Absent
          </button>
        </div>
        <div class="form-group">
          <label for="porter">Select Porter</label>
          <select 
            id="porter"
            v-model="porterForm.porterId"
            class="form-control"
            :disabled="editingPorterAssignment"
          >
            <option value="">Select a porter</option>
            <option 
              v-for="porter in availablePorters" 
              :key="porter.id" 
              :value="porter.id"
            >
              {{ porter.first_name }} {{ porter.last_name }}
            </option>
          </select>
        </div>
        
        <div class="form-group">
          <label for="porter-start-time">Start Time</label>
          <input 
            type="time"
            id="porter-start-time"
            v-model="porterForm.startTime"
            class="form-control"
          />
        </div>
        
        <div class="form-group">
          <label for="porter-end-time">End Time</label>
          <input 
            type="time"
            id="porter-end-time"
            v-model="porterForm.endTime"
            class="form-control"
          />
        </div>
      </div>
      
      <div class="modal-footer">
        <button 
          @click.stop="savePorterAssignment" 
          class="btn btn-primary"
          :disabled="!canSave || saving"
        >
          {{ saving ? 'Saving...' : (editingPorterAssignment ? 'Update' : 'Add') }}
        </button>
        <button 
          @click.stop="$emit('close')" 
          class="btn btn-secondary"
          :disabled="saving"
        >
          Cancel
        </button>
      </div>
    </div>
  </div>
  
  <Teleport to="body">
    <PorterAbsenceModal
      v-if="showAbsenceModal && porterForm.porterId"
      :porter-id="porterForm.porterId"
      :absence="currentPorterAbsence"
      @close="showAbsenceModal = false"
      @save="handleAbsenceSave"
    />
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStaffStore } from '../../stores/staffStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';
import PorterAbsenceModal from '../PorterAbsenceModal.vue';

// Helper function to get porter absence
const getPorterAbsence = (porterId) => {
  const today = new Date();
  const staffStore = useStaffStore();
  return staffStore.getPorterAbsenceDetails(porterId, today);
};

const props = defineProps({
  serviceAssignment: {
    type: Object,
    required: true
  },
  porterAssignment: {
    type: Object,
    default: null
  },
  defaultTimes: {
    type: Object,
    default: () => ({ startTime: '08:00', endTime: '16:00' })
  }
});

const emit = defineEmits(['close', 'save']);

const staffStore = useStaffStore();
const supportServicesStore = useSupportServicesStore();

// State
const porterForm = ref({
  porterId: '',
  startTime: '',
  endTime: ''
});
const saving = ref(false);
const editingPorterAssignment = computed(() => !!props.porterAssignment);
const showAbsenceModal = ref(false);
const currentPorterAbsence = ref(null);

// Available porters
const availablePorters = computed(() => {
  // Get all porters
  const allPorters = staffStore.porters.filter(p => p.role === 'porter' || p.role === 'runner');
  
  // Get current date for absence check
  const today = new Date();
  
  // Filter out absent porters
  const nonAbsentPorters = allPorters.filter(porter => !staffStore.isPorterAbsent(porter.id, today));
  
  // If editing, make sure current porter is included even if absent
  if (editingPorterAssignment.value && porterForm.value.porterId) {
    const currentPorter = staffStore.porters.find(p => p.id === porterForm.value.porterId);
    const alreadyInList = nonAbsentPorters.some(p => p.id === porterForm.value.porterId);
    
    if (currentPorter && !alreadyInList) {
      return [...nonAbsentPorters, currentPorter];
    }
  }
  
  return nonAbsentPorters;
});

// Get the absence for the current porter
const porterAbsence = computed(() => {
  if (!editingPorterAssignment.value || !porterForm.value.porterId) return null;
  
  const today = new Date();
  return staffStore.getPorterAbsenceDetails(porterForm.value.porterId, today);
});

// Validation
const canSave = computed(() => {
  return porterForm.value.porterId && 
         porterForm.value.startTime && 
         porterForm.value.endTime;
});

// Initialize
onMounted(async () => {
  // Load porters if needed
  if (!staffStore.porters.length) {
    await staffStore.fetchPorters();
  }
  
  // Format time helper
  const formatTime = (timeStr) => {
    if (!timeStr) return '';
    return timeStr.substring(0, 5); // Gets only HH:MM part
  };
  
  // Initialize form
  if (props.porterAssignment) {
    // Editing existing assignment
    porterForm.value = {
      porterId: props.porterAssignment.porter_id,
      startTime: formatTime(props.porterAssignment.start_time),
      endTime: formatTime(props.porterAssignment.end_time)
    };
  } else {
    // New assignment - use default times from parent
    porterForm.value = {
      porterId: '',
      startTime: props.defaultTimes.startTime || '08:00',
      endTime: props.defaultTimes.endTime || '16:00'
    };
  }
});

// Open absence modal
const openAbsenceModal = async () => {
  if (!porterForm.value.porterId) return;
  
  const today = new Date();
  currentPorterAbsence.value = staffStore.getPorterAbsenceDetails(porterForm.value.porterId, today);
  showAbsenceModal.value = true;
};

// Handle absence save
const handleAbsenceSave = () => {
  // Refresh the porterAbsence computed property
  currentPorterAbsence.value = null;
};

// Save porter assignment
const savePorterAssignment = async () => {
  if (!canSave.value || saving.value) return;
  
  saving.value = true;
  
  try {
    // Format times for storage (add seconds)
    const startTime = porterForm.value.startTime + ':00';
    const endTime = porterForm.value.endTime + ':00';
    
    if (editingPorterAssignment.value) {
      // Update existing assignment
      await supportServicesStore.updatePorterAssignment(props.porterAssignment.id, {
        start_time: startTime,
        end_time: endTime
      });
    } else {
      // Add new assignment
      await supportServicesStore.addPorterToServiceAssignment(
        props.serviceAssignment.id,
        porterForm.value.porterId,
        startTime,
        endTime
      );
    }
    
    emit('save');
    emit('close');
  } catch (error) {
    console.error('Error saving porter assignment:', error);
  } finally {
    saving.value = false;
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1001;
}

.modal-container {
  background-color: white;
  border-radius: mix.radius('lg');
  width: 90%;
  max-width: 500px;
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
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.form-group {
  margin-bottom: 16px;
  
  label {
    display: block;
    margin-bottom: 8px;
    font-weight: 500;
  }
  
  .form-control {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.2);
    }
  }
}

.action-menu {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 16px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  padding-bottom: 12px;
}

.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &.btn-sm {
    padding: 4px 10px;
    font-size: mix.font-size('sm');
  }
  
  &.btn-outline {
    border: 1px solid rgba(0, 0, 0, 0.2);
    background-color: transparent;
    
    &:hover {
      background-color: rgba(0, 0, 0, 0.05);
    }
  }
  
  &.btn-primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
  }
  
  &.btn-secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: color.scale(#f1f1f1, $lightness: -5%);
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
