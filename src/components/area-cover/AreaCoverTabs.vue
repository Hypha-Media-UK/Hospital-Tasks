<template>
  <div class="area-cover-tabs">
    <div class="area-cover-tabs__header">
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'week_day' }"
        @click="setActiveTab('week_day')"
      >
        Week Days
      </button>
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'week_night' }"
        @click="setActiveTab('week_night')"
      >
        Week Nights
      </button>
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'weekend_day' }"
        @click="setActiveTab('weekend_day')"
      >
        Weekend Days
      </button>
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'weekend_night' }"
        @click="setActiveTab('weekend_night')"
      >
        Weekend Nights
      </button>
    </div>
    
    <div class="area-cover-tabs__content">
      <div v-if="activeTab === 'week_day'" class="area-cover-tabs__panel">
        <AreaCoverShiftList shift-type="week_day" />
      </div>
      
      <div v-if="activeTab === 'week_night'" class="area-cover-tabs__panel">
        <AreaCoverShiftList shift-type="week_night" />
      </div>
      
      <div v-if="activeTab === 'weekend_day'" class="area-cover-tabs__panel">
        <AreaCoverShiftList shift-type="weekend_day" />
      </div>
      
      <div v-if="activeTab === 'weekend_night'" class="area-cover-tabs__panel">
        <AreaCoverShiftList shift-type="weekend_night" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useSettingsStore } from '../../stores/settingsStore';
import AreaCoverShiftList from './AreaCoverShiftList.vue';

const settingsStore = useSettingsStore();
const route = useRoute();
const router = useRouter();
const activeTab = ref('week_day');

onMounted(async () => {
  // Load shift defaults if not already loaded
  if (!settingsStore.shiftDefaults.week_day?.start_time) {
    await settingsStore.loadSettings();
  }
  
  // Check for area-tab query parameter
  const tabParam = route.query['area-tab'];
  if (tabParam && ['week_day', 'week_night', 'weekend_day', 'weekend_night'].includes(tabParam)) {
    activeTab.value = tabParam;
  }
});

// Function to set active tab and update URL query parameter
function setActiveTab(tabId) {
  activeTab.value = tabId;
  
  // Update URL with the new tab
  router.replace({ 
    query: { 
      ...route.query, 
      'area-tab': tabId 
    }
  }).catch(err => {
    // Handle navigation errors silently
    if (err.name !== 'NavigationDuplicated') {
      console.error(err);
    }
  });
}

// Format time range for display (e.g., "08:00 - 16:00")
function formatTimeRange(shiftSettings) {
  if (!shiftSettings) return '';
  const startTime = shiftSettings.start_time?.slice(0, 5) || '00:00';
  const endTime = shiftSettings.end_time?.slice(0, 5) || '00:00';
  return `${startTime} - ${endTime}`;
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
    flex-wrap: wrap;
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
      background-color: rgba(66, 133, 244, 0.1);
      box-shadow: inset 0 -3px 0 mix.color('primary');
      font-weight: 600;
    }
  }
  
  &__content {
    padding: 16px;
  }
  
  &__panel {
    // Panel styles
    
    .time-info {
      margin-bottom: 12px;
      padding: 6px 10px;
      background-color: rgba(0, 0, 0, 0.03);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.7);
    }
  }
}
</style>
