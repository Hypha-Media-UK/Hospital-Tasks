<template>
  <div class="shift-setup-tab">
    <!-- Shift Porters Section -->
    <div class="shift-porter-section">
      <div class="section-header">
        <h3 class="section-title">Shift Porters</h3>
        <button class="btn btn-primary" @click="porterPoolRef?.openPorterSelector()">
          Add Porter
        </button>
      </div>
      <ShiftPorterPool :shift-id="shiftId" ref="porterPoolRef" />
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
      <h3 class="duplicate-controls-header">Duplicate Shift</h3>
      <div class="duplicate-controls">
        <span class="duplicate-label">Duplicate this shift to:</span>
        <input 
          type="date" 
          v-model="duplicateDate" 
          class="date-picker"
          :min="getTomorrowDate()"
        >
        <button 
          @click="duplicateShift" 
          class="btn btn-secondary"
          :disabled="!duplicateDate || duplicating"
          title="Duplicate this shift setup to selected date"
        >
          {{ duplicating ? 'Duplicating...' : 'Duplicate' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useShiftsStore } from '../../../stores/shiftsStore';
import ShiftPorterPool from '../../ShiftPorterPool.vue';
import ShiftAreaCoverList from '../../area-cover/ShiftAreaCoverList.vue';
import SupportServicesShiftList from '../../support-services/SupportServicesShiftList.vue';

const porterPoolRef = ref(null);
const areaCoverListRef = ref(null);
const supportServicesListRef = ref(null);
const duplicateDate = ref('');
const duplicating = ref(false);

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

// Duplicate the current shift to a new date
async function duplicateShift() {
  if (!duplicateDate.value || duplicating.value) return;
  
  duplicating.value = true;
  
  try {
    const result = await shiftsStore.duplicateShift(props.shiftId, duplicateDate.value);
    
    if (result) {
      // Show success notification
      alert(`Shift successfully duplicated to ${formatShortDate(result.start_time)}`);
      
      // Reset date picker
      duplicateDate.value = '';
    } else {
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
  margin-top: 24px;
  padding: 16px;
  background-color: #f8f9fa;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
}

.duplicate-controls-header {
  font-size: 1.1rem;
  font-weight: 600;
  margin-bottom: 1rem;
  color: #333;
}

.duplicate-controls {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  
  @media screen and (min-width: 500px) {
    flex-direction: row;
    align-items: center;
  }
}

.duplicate-label {
  font-weight: 500;
  margin-right: 0.75rem;
}

.date-picker {
  padding: 0.5rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-family: inherit;
  font-size: 0.9rem;
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
