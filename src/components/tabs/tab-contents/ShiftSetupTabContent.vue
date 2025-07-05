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
      console.error('Failed to duplicate shift:', shiftsStore.error);
      alert('Failed to duplicate shift: ' + (shiftsStore.error || 'Unknown error'));
    }
  } catch (error) {
    console.error('Error duplicating shift:', error);
    alert('Error duplicating shift: ' + error.message);
  } finally {
    duplicating.value = false;
  }
}
</script>

<style lang="scss" scoped>
@use "sass:color";
.mb-4 {
  margin-bottom: 1rem;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.section-title {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 0; /* Remove bottom margin since it's now handled by section-header */
  color: #333;
}

.card {
  background-color: white;
  border-radius: 6px;
  padding: 1rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}

.shift-porter-section {
  background-color: rgba(66, 133, 244, 0.05); /* Light shade of primary color */
  border-radius: 8px;
  padding: 16px;
  border: 1px solid rgba(66, 133, 244, 0.15);
}

.area-coverage-section, .support-services-section {
  margin-top: 24px;
  padding-top: 24px;
  padding-left: 16px;
  padding-right: 16px;
  padding-bottom: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  background-color: rgba(0, 0, 0, 0.03); /* Pale gray background */
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.08);
}

/* Apply the styling to the main container */
.shift-setup-tab {
  display: flex;
  flex-direction: column;
  gap: 24px;
  background-color: white;
}

/* Duplicate Controls Section */
.duplicate-controls-section {
  margin-top: 32px;
  margin-left: auto;
  margin-right: auto;
  padding: 20px;
  background-color: #f0f7ff;
  border: 1px solid #c2d8f5;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  transition: all 0.3s ease;
  max-width: 600px;
  
  &:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }
}

.duplicate-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  flex-wrap: wrap;
  gap: 12px;
}

.duplicate-title {
  display: flex;
  align-items: center;
  gap: 10px;
}

.duplicate-icon {
  color: #4285F4;
}

.duplicate-controls-header {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 0;
  color: #333;
}


.duplicate-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
  
  @media screen and (min-width: 600px) {
    flex-direction: row;
    align-items: flex-end;
  }
}

.form-group {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-label {
  font-weight: 500;
  color: #555;
  font-size: 0.9rem;
}

.date-picker {
  padding: 10px 12px;
  border: 1px solid #c2d8f5;
  border-radius: 6px;
  font-family: inherit;
  font-size: 0.95rem;
  background-color: white;
  transition: border-color 0.2s ease;
  
  &:focus {
    outline: none;
    border-color: #4285F4;
    box-shadow: 0 0 0 3px rgba(66, 133, 244, 0.2);
  }
  
  &:disabled {
    background-color: #f8f8f8;
    cursor: not-allowed;
  }
}

.btn-duplicate {
  padding: 10px 16px;
  background-color: #4285F4;
  color: white;
  font-weight: 500;
  border-radius: 6px;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 42px;
  min-width: 150px;
  
  &:hover:not(:disabled) {
    background-color: #3367d6;
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
  
  &.duplicating {
    background-color: #3367d6;
  }
}

.duplicate-loading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
}

.loading-dot {
  width: 6px;
  height: 6px;
  background-color: white;
  border-radius: 50%;
  display: inline-block;
  animation: pulse 1.4s infinite ease-in-out both;
  
  &:nth-child(1) {
    animation-delay: -0.32s;
  }
  
  &:nth-child(2) {
    animation-delay: -0.16s;
  }
}

@keyframes pulse {
  0%, 80%, 100% { 
    transform: scale(0);
    opacity: 0.6;
  }
  40% { 
    transform: scale(1);
    opacity: 1;
  }
}

.success-message {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background-color: rgba(52, 168, 83, 0.1);
  border-radius: 6px;
  font-size: 0.9rem;
  color: #34A853;
  animation: fadeIn 0.3s ease-in-out;
}

.success-icon {
  color: #34A853;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

/* Button styling */
.btn {
  padding: 6px 12px;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &-primary {
    background-color: #4285F4;
    color: white;
    
    &:hover {
      background-color: color.adjust(#4285F4, $lightness: -10%);
    }
  }
  
  &-secondary {
    background-color: #9e9e9e;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#9e9e9e, $lightness: -10%);
    }
  }
}
</style>
