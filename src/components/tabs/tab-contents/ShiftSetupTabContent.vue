<template>
  <div class="shift-setup-tab">
    <!-- Porter Pool Section -->
    <div class="card mb-4">
      <ShiftPorterPool :shift-id="shiftId" />
    </div>
    
    <!-- Area Coverage Section -->
    <div class="card">
      <h3 class="section-title">Area Coverage</h3>
      <ShiftAreaCoverList 
        :shift-id="shiftId" 
        :shift-type="shiftType"
        :show-header="false"
      />
    </div>
  </div>
</template>

<script setup>
import ShiftPorterPool from '../../ShiftPorterPool.vue';
import ShiftAreaCoverList from '../../area-cover/ShiftAreaCoverList.vue';

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
</style>
