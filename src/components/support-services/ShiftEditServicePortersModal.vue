<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">
          {{ assignment.service.name }} Porter Assignments
        </h3>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div class="service-time-info">
          <div class="info-label">Service Coverage Time:</div>
          <div class="info-value">{{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}</div>
        </div>
        
        <!-- Porter Assignments Section -->
        <div class="porter-assignments">
          <h4 class="section-title">Assigned Porters</h4>
          
          <div v-if="porterAssignments.length === 0" class="empty-state">
            <p>No porters assigned to this service yet.</p>
          </div>
          
          <div v-else class="porter-list">
            <div 
              v-for="assignment in porterAssignments" 
              :key="assignment.id"
              class="porter-item"
            >
              <div class="porter-info">
                <div 
                  class="porter-name" 
                  :class="{
                    'porter-absent': staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date()),
                    'porter-illness': staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date())?.absence_type === 'illness',
                    'porter-annual-leave': staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date())?.absence_type === 'annual_leave'
                  }"
                  @click="openAbsenceModal(assignment.porter_id)"
                >
                  {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
                  <span v-if="staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date())?.absence_type === 'illness'" 
                        class="absence-badge illness">ILL</span>
                  <span v-if="staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date())?.absence_type === 'annual_leave'" 
                        class="absence-badge annual-leave">AL</span>
                </div>
                <div class="porter-time">
                  {{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
                </div>
              </div>
              
              <div class="porter-actions">
                <button 
                  @click="editPorterAssignment(assignment)"
                  class="btn btn--icon"
                  title="Edit porter assignment"
                >
                  <span class="icon">✏️</span>
                </button>
                <button 
                  @click="removePorterAssignment(assignment.id)"
                  class="btn btn--icon btn--danger"
                  title="Remove porter assignment"
                >
                  <span class="icon">🗑️</span>
                </button>
              </div>
            </div>
          </div>
          
          <button @click="showAddPorterModal = true" class="btn btn--primary btn--sm mt-2">
            Add Porter
          </button>
        </div>
        
        <!-- Coverage Status -->
        <div class="coverage-status" :class="{ 'has-gap': hasCoverageGap }">
          <div class="status-icon">{{ hasCoverageGap ? '⚠️' : '✅' }}</div>
          <div class="status-text">
            {{ hasCoverageGap ? 'Coverage gap detected! Some time slots are not covered.' : 'Full coverage for this service.' }}
          </div>
        </div>
        
        <!-- Absent porters section -->
        <div v-if="absentPorters.length > 0" class="absent-porters-section">
          <h4 class="section-title">Absent Porters</h4>
          <div v-for="porter in absentPorters" :key="porter.id" class="absent-porter-item">
            <span class="absent-porter-name" 
                  :class="{'illness': getPorterAbsence(porter.porter_id)?.absence_type === 'illness',
                          'annual-leave': getPorterAbsence(porter.porter_id)?.absence_type === 'annual_leave'}">
              {{ porter.porter.first_name }} {{ porter.porter.last_name }}
              <span v-if="getPorterAbsence(porter.porter_id)?.absence_type === 'illness'" class="absence-badge illness">ILL</span>
              <span v-if="getPorterAbsence(porter.porter_id)?.absence_type === 'annual_leave'" class="absence-badge annual-leave">AL</span>
            </span>
            <div class="absent-porter-dates">
              {{ formatAbsenceDates(getPorterAbsence(porter.porter_id)) }}
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <button 
          @click="$emit('close')" 
          class="btn btn--primary"
        >
          Close
        </button>
      </div>
    </div>
    
    <!-- Add/Edit Porter Modal -->
    <div v-if="showPorterModal" class="nested-modal-overlay" @click.self="closePorterModal">
      <div class="nested-modal-container" @click.stop>
        <div class="modal-header">
          <h3 class="modal-title">
            {{ editingPorterAssignment ? 'Edit Porter Assignment' : 'Add Porter' }}
          </h3>
          <button class="modal-close" @click.stop="closePorterModal">&times;</button>
        </div>
        
        <div class="modal-body">
          <div v-if="editingPorterAssignment" class="action-menu">
            <button 
              class="btn btn-sm btn-outline" 
              @click="openAbsenceModal(porterForm.porterId)"
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
            @click="savePorterAssignment" 
            class="btn btn--primary"
            :disabled="!canSavePorter || savingPorter"
          >
            {{ savingPorter ? 'Saving...' : (editingPorterAssignment ? 'Update' : 'Add') }}
          </button>
          <button 
            @click.stop="closePorterModal" 
            class="btn btn--secondary"
            :disabled="savingPorter"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
  
  <Teleport to="body">
    <PorterAbsenceModal
      v-if="showAbsenceModal && selectedPorterId"
      :porter-id="selectedPorterId"
      :absence="currentPorterAbsence"
      @close="showAbsenceModal = false"
      @save="handleAbsenceSave"
    />
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useShiftsStore } from '../../stores/shiftsStore';
import { useStaffStore } from '../../stores/staffStore';
import PorterAbsenceModal from '../../components/PorterAbsenceModal.vue';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close']);

const shiftsStore = useShiftsStore();
const staffStore = useStaffStore();

// Form data for porter assignment
const porterForm = ref({
  porterId: '',
  startTime: '',
  endTime: ''
});

// UI state
const showPorterModal = ref(false);
const showAddPorterModal = ref(false);
const editingPorterAssignment = ref(false);
const editingPorterAssignmentId = ref(null);
const savingPorter = ref(false);
const showAbsenceModal = ref(false);
const selectedPorterId = ref(null);
const currentPorterAbsence = ref(null);

// Initialize data
onMounted(async () => {
  // Load porters if not already loaded
  if (!staffStore.porters.length) {
    await staffStore.fetchPorters();
  }
  
  // Load porter absences if not already loaded
  if (!staffStore.porterAbsences.length) {
    await staffStore.fetchPorterAbsences();
  }
});

// Computed properties
const porterAssignments = computed(() => {
  return shiftsStore.getPorterAssignmentsByServiceId(props.assignment.id);
});

// Get all available (non-absent) porters
const availablePorters = computed(() => {
  const today = new Date();
  
  // Get porters from the shift pool
  const shiftPorters = shiftsStore.shiftPorterPool.map(p => p.porter);
  
  // If editing an existing assignment, include the current porter
  if (editingPorterAssignment.value && porterForm.value.porterId) {
    // Check if the current porter is in the shift pool
    const currentPorterInPool = shiftPorters.some(p => p.id === porterForm.value.porterId);
    
    // If not in pool, add them to the available porters list
    if (!currentPorterInPool) {
      const currentPorter = staffStore.porters.find(p => p.id === porterForm.value.porterId);
      if (currentPorter) {
        return [...shiftPorters, currentPorter];
      }
    }
  }
  
  // Return porters from the shift pool
  return shiftPorters;
});

// Get all absent porters
const absentPorters = computed(() => {
  const today = new Date();
  return porterAssignments.value.filter(assignment => {
    return staffStore.isPorterAbsent(assignment.porter_id, today);
  });
});

// Get porter absence details
const getPorterAbsence = (porterId) => {
  const today = new Date();
  return staffStore.getPorterAbsenceDetails(porterId, today);
};

// Format absence dates
const formatAbsenceDates = (absence) => {
  if (!absence) return '';
  
  const startDate = new Date(absence.start_date);
  const endDate = new Date(absence.end_date);
  
  const formatDate = (date) => {
    return date.toLocaleDateString('en-GB', {
      day: 'numeric',
      month: 'short',
      year: 'numeric'
    });
  };
  
  return `${formatDate(startDate)} to ${formatDate(endDate)}`;
};

const hasCoverageGap = computed(() => {
  return shiftsStore.hasServiceCoverageGap(props.assignment.id);
});

const canSavePorter = computed(() => {
  return porterForm.value.porterId && 
         porterForm.value.startTime && 
         porterForm.value.endTime;
});

// Porter assignment methods
const editPorterAssignment = (assignment) => {
  editingPorterAssignment.value = true;
  editingPorterAssignmentId.value = assignment.id;
  
  porterForm.value = {
    porterId: assignment.porter_id,
    startTime: assignment.start_time ? assignment.start_time.substring(0, 5) : '08:00',
    endTime: assignment.end_time ? assignment.end_time.substring(0, 5) : '16:00'
  };
  
  showPorterModal.value = true;
};

// Open absence modal for a specific porter
const openAbsenceModal = (porterId) => {
  if (!porterId) return;
  
  selectedPorterId.value = porterId;
  const today = new Date();
  currentPorterAbsence.value = staffStore.getPorterAbsenceDetails(porterId, today);
  showAbsenceModal.value = true;
};

// Handle absence save
const handleAbsenceSave = () => {
  // Refresh the absence data
  currentPorterAbsence.value = null;
};

const closePorterModal = () => {
  showPorterModal.value = false;
  showAddPorterModal.value = false;
  editingPorterAssignment.value = false;
  editingPorterAssignmentId.value = null;
  
  // Reset form
  porterForm.value = {
    porterId: '',
    startTime: '',
    endTime: ''
  };
};

const savePorterAssignment = async () => {
  if (!canSavePorter.value || savingPorter.value) return;
  
  savingPorter.value = true;
  
  try {
    // Format times for storage (add seconds)
    const startTime = porterForm.value.startTime + ':00';
    const endTime = porterForm.value.endTime + ':00';
    
    if (editingPorterAssignment.value) {
      // Update existing assignment
      await shiftsStore.updateShiftSupportServicePorter(editingPorterAssignmentId.value, {
        start_time: startTime,
        end_time: endTime
      });
    } else {
      // Add new assignment
      await shiftsStore.addShiftSupportServicePorter(
        props.assignment.id,
        porterForm.value.porterId,
        startTime,
        endTime
      );
    }
    
    closePorterModal();
  } catch (error) {
    console.error('Error saving porter assignment:', error);
  } finally {
    savingPorter.value = false;
  }
};

const removePorterAssignment = async (assignmentId) => {
  if (confirm('Are you sure you want to remove this porter assignment?')) {
    await shiftsStore.removeShiftSupportServicePorter(assignmentId);
  }
};

// Helper methods
const formatTime = (timeStr) => {
  if (!timeStr) return '';
  return timeStr.substring(0, 5); // Extract HH:MM from HH:MM:SS
};

// Watch for "Add Porter" button click
watch(showAddPorterModal, (newValue) => {
  if (newValue) {
    // Set default values for the form
    porterForm.value = {
      porterId: '',
      startTime: props.assignment.start_time ? props.assignment.start_time.substring(0, 5) : '08:00',
      endTime: props.assignment.end_time ? props.assignment.end_time.substring(0, 5) : '16:00'
    };
    
    showPorterModal.value = true;
  }
});
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.modal-overlay, .nested-modal-overlay {
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

.nested-modal-overlay {
  z-index: 1001;
}

.modal-container, .nested-modal-container {
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

.action-menu {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 16px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  padding-bottom: 12px;
}

.service-time-info {
  display: flex;
  align-items: center;
  gap: 8px;
  background-color: rgba(66, 133, 244, 0.05);
  padding: 12px;
  border-radius: mix.radius('md');
  margin-bottom: 16px;
  
  .info-label {
    font-weight: 500;
  }
  
  .info-value {
    background-color: white;
    padding: 4px 8px;
    border-radius: mix.radius('sm');
    font-weight: 500;
  }
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
  }
}

.section-title {
  font-size: mix.font-size('md');
  font-weight: 600;
  margin: 24px 0 16px;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
}

.porter-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 16px;
}

.porter-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: mix.radius('md');
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.04);
  }
}

.porter-info {
  .porter-name {
    font-weight: 500;
    cursor: pointer;
    position: relative;
    display: inline-block;
    border-radius: mix.radius('sm');
    padding: 2px 6px;
    
    &.porter-absent {
      opacity: 0.9;
    }
    
    &.porter-illness {
      color: #d32f2f;
      background-color: rgba(234, 67, 53, 0.1);
    }
    
    &.porter-annual-leave {
      color: #f57c00;
      background-color: rgba(251, 192, 45, 0.1);
    }
    
    .absence-badge {
      display: inline-block;
      font-size: 9px;
      font-weight: 700;
      padding: 2px 4px;
      border-radius: 3px;
      margin-left: 5px;
      
      &.illness {
        background-color: #d32f2f;
        color: white;
      }
      
      &.annual-leave {
        background-color: #f57c00;
        color: white;
      }
    }
  }
  
  .porter-time {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
  }
}

.porter-actions {
  display: flex;
  gap: 4px;
}

.empty-state {
  padding: 16px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: mix.radius('md');
  
  p {
    margin: 0;
  }
}

.coverage-status {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px;
  border-radius: mix.radius('md');
  margin-top: 16px;
  background-color: rgba(52, 168, 83, 0.1);
  
  &.has-gap {
    background-color: rgba(234, 67, 53, 0.1);
  }
  
  .status-text {
    font-weight: 500;
  }
}

.absent-porters-section {
  margin-top: 20px;
  
  .absent-porter-item {
    padding: 8px 12px;
    background-color: rgba(0, 0, 0, 0.02);
    border-radius: mix.radius('md');
    margin-bottom: 8px;
    
    .absent-porter-name {
      font-weight: 500;
      display: inline-block;
      padding: 2px 6px;
      border-radius: mix.radius('sm');
      
      &.illness {
        color: #d32f2f;
        background-color: rgba(234, 67, 53, 0.1);
      }
      
      &.annual-leave {
        color: #f57c00;
        background-color: rgba(251, 192, 45, 0.1);
      }
      
      .absence-badge {
        display: inline-block;
        font-size: 9px;
        font-weight: 700;
        padding: 2px 4px;
        border-radius: 3px;
        margin-left: 5px;
        
        &.illness {
          background-color: #d32f2f;
          color: white;
        }
        
        &.annual-leave {
          background-color: #f57c00;
          color: white;
        }
      }
    }
    
    .absent-porter-dates {
      margin-top: 4px;
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.6);
    }
  }
}

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
      background-color: rgba(66, 133, 244, 0.8);
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
    background-color: #EA4335;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#EA4335, $lightness: -10%);
    }
  }
  
  &--sm {
    padding: 6px 12px;
    font-size: mix.font-size('sm');
  }
  
  &--icon {
    padding: 4px;
    border-radius: 4px;
    background: transparent;
    
    &:hover {
      background-color: rgba(0, 0, 0, 0.05);
    }
    
    &.btn--danger:hover {
      background-color: rgba(234, 67, 53, 0.1);
    }
    
    .icon {
      font-size: 16px;
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.btn-sm {
  padding: 4px 10px;
  font-size: mix.font-size('sm');
}

.btn-outline {
  border: 1px solid rgba(0, 0, 0, 0.2);
  background-color: transparent;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.05);
  }
}

.mt-2 {
  margin-top: 8px;
}
</style>
