<template>
  <div class="area-cover-tabs">
    <div class="area-cover-tabs__header">
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === shift.shift_type }"
        @click="setActiveTab(shift.shift_type)"
      >
        {{ shiftTypeLabel }} Coverage
      </button>
    </div>
    
    <div class="area-cover-tabs__content">
      <div class="area-cover-tabs__panel">
        <ShiftAreaCoverList :shift-id="shift.id" :shift-type="shift.shift_type" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShiftsStore } from '../../stores/shiftsStore';
import ShiftAreaCoverList from './ShiftAreaCoverList.vue';

const props = defineProps({
  shiftId: {
    type: String,
    required: true
  }
});

const shiftsStore = useShiftsStore();
const route = useRoute();
const router = useRouter();
const activeTab = ref('');

// Set the active tab based on the shift type
const shift = computed(() => shiftsStore.currentShift);

// Get a user-friendly label for the shift type
const shiftTypeLabel = computed(() => {
  if (!shift.value) return 'Shift';
  
  switch (shift.value.shift_type) {
    case 'week_day':
      return 'Week Day';
    case 'week_night':
      return 'Week Night';
    case 'weekend_day':
      return 'Weekend Day';
    case 'weekend_night':
      return 'Weekend Night';
    default:
      return 'Shift';
  }
});

onMounted(() => {
  if (shift.value) {
    // Check for shift-area-tab query parameter first
    const tabParam = route.query['shift-area-tab'];
    if (tabParam && tabParam === shift.value.shift_type) {
      activeTab.value = tabParam;
    } else {
      activeTab.value = shift.value.shift_type;
      // Update URL to include tab param
      updateQueryParam(activeTab.value);
    }
  }
});

// Function to set active tab and update URL query parameter
function setActiveTab(tabId) {
  activeTab.value = tabId;
  updateQueryParam(tabId);
}

// Helper function to update the URL query parameter
function updateQueryParam(tabId) {
  router.replace({ 
    query: { 
      ...route.query, 
      'shift-area-tab': tabId 
    }
  }).catch(err => {
    // Handle navigation errors silently
    if (err.name !== 'NavigationDuplicated') {
      console.error(err);
    }
  });
}
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.area-cover-tabs {
  background-color: white;
  border-radius: mix.radius('lg');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  
  &__header {
    display: flex;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  }
  
  &__tab {
    padding: 12px 16px;
    background: none;
    border: none;
    font-size: mix.font-size('md');
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
    
    &:hover {
      background-color: rgba(0, 0, 0, 0.03);
    }
    
    &--active {
      color: mix.color('primary');
      box-shadow: inset 0 -2px 0 mix.color('primary');
    }
  }
  
  &__content {
    padding: 16px;
  }
  
  &__panel {
    // Panel styles
  }
}
</style>
