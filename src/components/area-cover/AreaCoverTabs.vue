<template>
  <div class="area-cover-tabs">
    <div class="area-cover-tabs__header">
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'week_day' }"
        @click="activeTab = 'week_day'"
      >
        Week Days
      </button>
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'week_night' }"
        @click="activeTab = 'week_night'"
      >
        Week Nights
      </button>
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'weekend_day' }"
        @click="activeTab = 'weekend_day'"
      >
        Weekend Days
      </button>
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'weekend_night' }"
        @click="activeTab = 'weekend_night'"
      >
        Weekend Nights
      </button>
    </div>
    
    <div class="area-cover-tabs__content">
      <div v-if="activeTab === 'week_day'" class="area-cover-tabs__panel">
        <div class="time-info">{{ formatTimeRange(settingsStore.shiftDefaults.day) }}</div>
        <AreaCoverShiftList shift-type="week_day" />
      </div>
      
      <div v-if="activeTab === 'week_night'" class="area-cover-tabs__panel">
        <div class="time-info">{{ formatTimeRange(settingsStore.shiftDefaults.night) }}</div>
        <AreaCoverShiftList shift-type="week_night" />
      </div>
      
      <div v-if="activeTab === 'weekend_day'" class="area-cover-tabs__panel">
        <div class="time-info">{{ formatTimeRange(settingsStore.shiftDefaults.day) }}</div>
        <AreaCoverShiftList shift-type="weekend_day" />
      </div>
      
      <div v-if="activeTab === 'weekend_night'" class="area-cover-tabs__panel">
        <div class="time-info">{{ formatTimeRange(settingsStore.shiftDefaults.night) }}</div>
        <AreaCoverShiftList shift-type="weekend_night" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useSettingsStore } from '../../stores/settingsStore';
import AreaCoverShiftList from './AreaCoverShiftList.vue';

const settingsStore = useSettingsStore();
const activeTab = ref('week_day');

onMounted(async () => {
  // Load shift defaults if not already loaded
  if (!settingsStore.shiftDefaults.day.startTime) {
    await settingsStore.loadSettings();
  }
});

// Format time range for display (e.g., "08:00 - 16:00")
function formatTimeRange(shiftSettings) {
  if (!shiftSettings) return '';
  return `${shiftSettings.startTime} - ${shiftSettings.endTime}`;
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
      box-shadow: inset 0 -2px 0 mix.color('primary');
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
