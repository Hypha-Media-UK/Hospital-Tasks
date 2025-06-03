<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">
          {{ editing ? 'Edit Absence' : 'Mark Porter as Absent' }}
        </h3>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div v-if="!editing" class="porter-info">
          <strong>{{ porterName }}</strong>
        </div>
        
        <div class="form-group">
          <label>Absence Type</label>
          <div class="radio-group">
            <label class="radio-label">
              <input 
                type="radio" 
                v-model="absenceForm.absenceType" 
                value="illness"
              > 
              Illness
            </label>
            <label class="radio-label">
              <input 
                type="radio" 
                v-model="absenceForm.absenceType" 
                value="annual_leave"
              > 
              Annual Leave
            </label>
          </div>
        </div>
        
        <div class="form-group">
          <label for="start-date">Start Date</label>
          <input 
            type="date" 
            id="start-date" 
            v-model="absenceForm.startDate"
            class="form-control"
            :min="today"
          >
        </div>
        
        <div class="form-group">
          <label for="end-date">End Date</label>
          <input 
            type="date" 
            id="end-date" 
            v-model="absenceForm.endDate"
            class="form-control"
            :min="absenceForm.startDate || today"
          >
        </div>
      </div>
      
      <div class="modal-footer">
        <button 
          @click="saveAbsence" 
          class="btn btn-primary"
          :disabled="!isValid || saving"
        >
          {{ saving ? 'Saving...' : (editing ? 'Update' : 'Save') }}
        </button>
        <button 
          v-if="editing" 
          @click="deleteAbsence" 
          class="btn btn-danger"
          :disabled="saving"
        >
          Delete
        </button>
        <button 
          @click="$emit('close')" 
          class="btn btn-secondary"
          :disabled="saving"
        >
          Cancel
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStaffStore } from '../stores/staffStore';

const props = defineProps({
  porterId: {
    type: String,
    required: true
  },
  absence: {
    type: Object,
    default: null
  }
});

const emit = defineEmits(['close', 'save', 'delete']);

const staffStore = useStaffStore();
const saving = ref(false);
const editing = computed(() => !!props.absence);

const absenceForm = ref({
  absenceType: 'illness',
  startDate: '',
  endDate: ''
});

const today = computed(() => {
  const now = new Date();
  return now.toISOString().split('T')[0]; // Format as YYYY-MM-DD
});

const porterName = computed(() => {
  const porter = staffStore.getStaffById(props.porterId);
  return porter ? `${porter.first_name} ${porter.last_name}` : '';
});

const isValid = computed(() => {
  return absenceForm.value.absenceType && 
         absenceForm.value.startDate && 
         absenceForm.value.endDate &&
         absenceForm.value.startDate <= absenceForm.value.endDate;
});

onMounted(() => {
  if (props.absence) {
    absenceForm.value = {
      absenceType: props.absence.absence_type,
      startDate: props.absence.start_date,
      endDate: props.absence.end_date
    };
  } else {
    // Default to today and one week from today
    const now = new Date();
    const oneWeekLater = new Date();
    oneWeekLater.setDate(now.getDate() + 7);
    
    absenceForm.value = {
      absenceType: 'illness',
      startDate: now.toISOString().split('T')[0],
      endDate: oneWeekLater.toISOString().split('T')[0]
    };
  }
});

const saveAbsence = async () => {
  if (!isValid.value || saving.value) return;
  
  saving.value = true;
  
  try {
    const absenceData = {
      porter_id: props.porterId,
      absence_type: absenceForm.value.absenceType,
      start_date: absenceForm.value.startDate,
      end_date: absenceForm.value.endDate
    };
    
    let result;
    
    if (editing.value) {
      result = await staffStore.updatePorterAbsence(props.absence.id, absenceData);
    } else {
      result = await staffStore.addPorterAbsence(absenceData);
    }
    
    if (result) {
      emit('save', result);
      emit('close');
    }
  } catch (error) {
    console.error('Error saving absence:', error);
  } finally {
    saving.value = false;
  }
};

const deleteAbsence = async () => {
  if (!props.absence || saving.value) return;
  
  if (!confirm('Are you sure you want to delete this absence record?')) {
    return;
  }
  
  saving.value = true;
  
  try {
    const success = await staffStore.deletePorterAbsence(props.absence.id);
    if (success) {
      emit('delete', props.absence.id);
      emit('close');
    }
  } catch (error) {
    console.error('Error deleting absence:', error);
  } finally {
    saving.value = false;
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../assets/scss/mixins' as mix;

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

.porter-info {
  margin-bottom: 16px;
  padding: 8px;
  background-color: rgba(0, 0, 0, 0.05);
  border-radius: mix.radius('md');
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

.radio-group {
  display: flex;
  gap: 16px;
  
  .radio-label {
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    
    input {
      cursor: pointer;
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
  
  &.btn-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#dc3545, $lightness: -10%);
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
