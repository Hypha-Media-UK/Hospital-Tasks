<template>
  <div class="shift-setup-tab">
    <!-- Shift Info Section -->
    <div class="card">
      <div class="shift-info-section">
        <!-- Shift Porters Section -->
        <div class="shift-porter-section">
          <h3 class="section-title">Shift Porters</h3>
          <ShiftPorterPool :shift-id="shiftId" />
        </div>
        
        <!-- Area Coverage Section -->
        <div class="area-coverage-section">
          <h3 class="section-title">Area Coverage</h3>
          <ShiftAreaCoverList 
            :shift-id="shiftId" 
            :shift-type="shiftType"
            :show-header="false"
          />
        </div>
        
        <!-- Support Services Section -->
        <div class="support-services-section">
          <h3 class="section-title">Service Coverage</h3>
          <SupportServicesShiftList 
            :shift-id="shiftId" 
            :shift-type="shiftType"
            :show-header="false"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import ShiftPorterPool from '../../ShiftPorterPool.vue';
import ShiftAreaCoverList from '../../area-cover/ShiftAreaCoverList.vue';
import SupportServicesShiftList from '../../support-services/SupportServicesShiftList.vue';

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
</script>

<style lang="scss" scoped>
.mb-4 {
  margin-bottom: 1rem;
}

.section-title {
  font-size: 1.1rem;
  font-weight: 600;
  margin-bottom: 1rem;
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

/* Add some styling for the shift-info-section */
.shift-info-section {
  display: flex;
  flex-direction: column;
  gap: 24px;
}
</style>
