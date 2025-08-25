<template>
  <div class="shift-setup-tab">
    <!-- Shift Porters Section -->
    <div class="shift-porter-section">
      <div class="section-header">
        <h3 class="section-title">Shift Porters</h3>
      </div>
      <ShiftPorterPool 
        :shift-id="shiftId" 
        ref="porterPoolRef"
        @openAllocationModal="handlePorterClick" 
      />
    </div>
        
    <!-- Area Coverage Section -->
    <div class="area-coverage-section">
      <div class="section-header">
        <h3 class="section-title">Area Coverage</h3>
        <button class="btn btn-primary" @click="areaCoverListRef?.openDepartmentSelector()">
          Add Department
        </button>
      </div>
      <ShiftAreaCoverList 
        :shift-id="shiftId" 
        :shift-type="shiftType"
        :show-header="false"
        ref="areaCoverListRef"
      />
    </div>
        
    <!-- Support Services Section -->
    <div class="support-services-section">
      <div class="section-header">
        <h3 class="section-title">Service Coverage</h3>
        <button class="btn btn-primary" @click="supportServicesListRef?.openAddServiceModal()">
          Add Service
        </button>
      </div>
      <SupportServicesShiftList 
        :shift-id="shiftId" 
        :shift-type="shiftType"
        :show-header="false"
        ref="supportServicesListRef"
      />
    </div>
        
    <!-- Duplicate Controls Section -->
    <div v-if="shift && shift.is_active" class="duplicate-controls-section">
      <div class="duplicate-header">
        <div class="duplicate-title">
          <CopyIcon size="18" class="duplicate-icon" />
          <h3 class="duplicate-controls-header">Duplicate Shift</h3>
        </div>
        <div v-if="showSuccessMessage" class="success-message">
          <CheckIcon size="16" class="success-icon" />
          <span>Shift successfully duplicated to {{ successDate }}</span>
        </div>
      </div>
      
      <div class="duplicate-form">
        <div class="form-group">
          <label for="duplicateDate" class="form-label">Select Target Date:</label>
          <input 
            id="duplicateDate"
            type="date" 
            v-model="duplicateDate" 
            class="date-picker"
            :min="getTomorrowDate()"
            :disabled="duplicating"
          >
        </div>
        
        <button 
          @click="duplicateShift" 
          class="btn btn-duplicate"
          :disabled="!duplicateDate || duplicating"
          :class="{ 'duplicating': duplicating }"
        >
          <span v-if="!duplicating">Duplicate Shift</span>
          <span v-else class="duplicate-loading">
            <span class="loading-dot"></span>
            <span class="loading-dot"></span>
            <span class="loading-dot"></span>
          </span>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useShiftsStore } from '../../../stores/shiftsStore';
import ShiftPorterPool from '../../ShiftPorterPool.vue';

const emit = defineEmits(['porter-click']);
import ShiftAreaCoverList from '../../area-cover/ShiftAreaCoverList.vue';
import SupportServicesShiftList from '../../support-services/SupportServicesShiftList.vue';
import CopyIcon from '../../icons/CopyIcon.vue';
import CheckIcon from '../../icons/CheckIcon.vue';

const porterPoolRef = ref(null);
const areaCoverListRef = ref(null);
const supportServicesListRef = ref(null);
const duplicateDate = ref('');
const duplicating = ref(false);
const showSuccessMessage = ref(false);
const successDate = ref('');

const shiftsStore = useShiftsStore();

const props = defineProps({
  shiftId: {
    type: String,
    required: true
  },
  shiftType: {
    type: String,
    required: true
  }
});

const shift = computed(() => shiftsStore.currentShift);

// Get tomorrow's date in YYYY-MM-DD format for date picker min attribute
function getTomorrowDate() {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  return tomorrow.toISOString().split('T')[0];
}

// Format date as "29th May 2025"
function formatShortDate(dateString) {
  if (!dateString) return '';
  
  const date = new Date(dateString);
  
  // Get day with ordinal suffix (1st, 2nd, 3rd, etc.)
  const day = date.getDate();
  const suffix = getDayOrdinalSuffix(day);
  
  // Format date in the requested format
  const formatter = new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  });
  
  const parts = formatter.formatToParts(date);
  const month = parts.find(part => part.type === 'month').value;
  const year = parts.find(part => part.type === 'year').value;
  
  return `${day}${suffix} ${month} ${year}`;
}

// Helper to get the correct ordinal suffix for a day
function getDayOrdinalSuffix(day) {
  if (day > 3 && day < 21) return 'th';
  switch (day % 10) {
    case 1: return 'st';
    case 2: return 'nd';
    case 3: return 'rd';
    default: return 'th';
  }
}

// Handle porter click for allocation
function handlePorterClick(porter) {
  // Emit the porter data to the parent component
  emit('porter-click', porter);
}

// Duplicate the current shift to a new date
async function duplicateShift() {
  if (!duplicateDate.value || duplicating.value) return;
  
  duplicating.value = true;
  showSuccessMessage.value = false;
  
  try {
    const result = await shiftsStore.duplicateShift(props.shiftId, duplicateDate.value);
    
    if (result) {
      // Show success message in the UI
      successDate.value = formatShortDate(result.start_time);
      showSuccessMessage.value = true;
      
      // Reset date picker
      duplicateDate.value = '';
      
      // Hide success message after 5 seconds
      setTimeout(() => {
        showSuccessMessage.value = false;
      }, 5000);
    } else {
      // Show error in the UI instead of an alert
      alert('Failed to duplicate shift: ' + (shiftsStore.error || 'Unknown error'));
    }
  } catch (error) {
    alert('Error duplicating shift: ' + error.message);
  } finally {
    duplicating.value = false;
  }
}
</script>

<!-- Styles are now handled by the global CSS layers -->