<template>
  <BaseModal
    :title="porter ? `${porter.first_name} ${porter.last_name} Absence` : 'Porter Absence'"
    size="medium"
    @close="$emit('close')"
  >
        <div v-if="loading" class="loading-state">
          Loading porter details...
        </div>
        
        <div v-else-if="!porter" class="error-state">
          Porter not found. Please try again.
        </div>
        
        <form v-else @submit.prevent="saveAbsence">
          <div class="form-group">
            <label for="absence-type">Absence Type</label>
            <select id="absence-type" v-model="absenceData.absence_type" class="form-control" required>
              <option value="" disabled>Select an absence type</option>
              <option value="illness">Illness</option>
              <option value="annual_leave">Annual Leave</option>
            </select>
          </div>
          
          <div class="form-group">
            <label for="start-date">Start Date</label>
            <input
              type="date"
              id="start-date"
              v-model="absenceData.start_date"
              class="form-control"
              required
              :min="today"
            />
          </div>
          
          <div class="form-group">
            <label for="end-date">End Date</label>
            <input
              type="date"
              id="end-date"
              v-model="absenceData.end_date"
              class="form-control"
              required
              :min="absenceData.start_date || today"
            />
          </div>
          
          <div class="form-group">
            <label for="notes">Notes (Optional)</label>
            <textarea
              id="notes"
              v-model="absenceData.notes"
              class="form-control textarea"
              placeholder="Additional details about this absence"
              rows="3"
            ></textarea>
          </div>
          
          <div v-if="hasExistingAbsence" class="existing-absence-warning">
            <p>This porter already has an absence record for the selected period. Saving will update the existing record.</p>
          </div>
        </form>

    <template #footer>
      <button
        v-if="absence && absence.id"
        @click="confirmDelete"
        class="btn btn--danger"
        :disabled="saving"
      >
        Delete Absence
      </button>

      <button
        @click="saveAbsence"
        class="btn btn--primary"
        :disabled="!canSave || saving"
      >
        {{ saving ? 'Saving...' : 'Save' }}
      </button>
      <button
        @click.stop="$emit('close')"
        class="btn btn--secondary"
        :disabled="saving"
      >
        Cancel
      </button>
    </template>
  </BaseModal>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStaffStore } from '../stores/staffStore';
import BaseModal from './shared/BaseModal.vue';

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

const emit = defineEmits(['close', 'save']);

const staffStore = useStaffStore();
const loading = ref(false);
const saving = ref(false);
const porter = ref(null);

// Absence data form
const absenceData = ref({
  porter_id: props.porterId,
  absence_type: '',
  start_date: '',
  end_date: '',
  notes: ''
});

// Get today's date in YYYY-MM-DD format for date input min attribute
const today = computed(() => {
  const today = new Date();
  return today.toISOString().split('T')[0];
});

// Check if there's an existing absence that overlaps with the selected dates
const hasExistingAbsence = computed(() => {
  if (!absenceData.value.start_date || !absenceData.value.end_date) {
    return false;
  }
  
  const startDate = new Date(absenceData.value.start_date);
  const endDate = new Date(absenceData.value.end_date);
  
  // Check if any existing absence overlaps with these dates
  return staffStore.porterAbsences.some(absence => {
    // Skip the current absence being edited
    if (props.absence && absence.id === props.absence.id) {
      return false;
    }
    
    const absStart = new Date(absence.start_date);
    const absEnd = new Date(absence.end_date);
    
    // Check for overlap
    return absence.porter_id === props.porterId && (
      (startDate <= absEnd && endDate >= absStart) // Dates overlap
    );
  });
});

// Check if the form can be saved
const canSave = computed(() => {
  return absenceData.value.absence_type && 
         absenceData.value.start_date && 
         absenceData.value.end_date &&
         new Date(absenceData.value.start_date) <= new Date(absenceData.value.end_date);
});

// Load porter details and populate form if editing existing absence
onMounted(async () => {
  loading.value = true;
  
  try {
    // Make sure porters are loaded
    if (staffStore.porters.length === 0) {
      await staffStore.fetchPorters();
    }
    
    // Get the porter
    porter.value = staffStore.porters.find(p => p.id === props.porterId);
    
    // If we have an existing absence, populate the form
    if (props.absence) {
      absenceData.value = {
        porter_id: props.porterId,
        absence_type: props.absence.absence_type || '',
        start_date: props.absence.start_date ? new Date(props.absence.start_date).toISOString().split('T')[0] : '',
        end_date: props.absence.end_date ? new Date(props.absence.end_date).toISOString().split('T')[0] : '',
        notes: props.absence.notes || ''
      };
    }
  } catch (error) {
  } finally {
    loading.value = false;
  }
});

// Save the absence
const saveAbsence = async () => {
  if (!canSave.value || saving.value) return;
  
  saving.value = true;
  
  try {
    // Make sure absence dates are in the correct format (YYYY-MM-DD)
    const formattedData = {
      ...absenceData.value,
      start_date: new Date(absenceData.value.start_date).toISOString().split('T')[0],
      end_date: new Date(absenceData.value.end_date).toISOString().split('T')[0]
    };
    
    let result;
    
    if (props.absence && props.absence.id) {
      // Update existing absence
      result = await staffStore.updatePorterAbsence(props.absence.id, formattedData);
    } else {
      // Create new absence
      result = await staffStore.addPorterAbsence(formattedData);
    }
    
    if (result) {
      emit('save', result);
      emit('close');
    }
  } catch (error) {
  } finally {
    saving.value = false;
  }
};

// Delete the absence
const confirmDelete = async () => {
  if (!props.absence || !props.absence.id || saving.value) return;
  
  if (confirm('Are you sure you want to delete this absence record?')) {
    saving.value = true;
    
    try {
      const success = await staffStore.deletePorterAbsence(props.absence.id);
      
      if (success) {
        emit('save', null); // Notify parent that absence was deleted
        emit('close');
      }
    } catch (error) {
    } finally {
      saving.value = false;
    }
  }
};
</script>

<!-- Styles are now handled by the global CSS layers -->