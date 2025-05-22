<template>
  <div class="area-cover-tabs">
    <div class="area-cover-tabs__header">
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'day' }"
        @click="activeTab = 'day'"
      >
        Day Shifts
      </button>
      <button 
        class="area-cover-tabs__tab" 
        :class="{ 'area-cover-tabs__tab--active': activeTab === 'night' }"
        @click="activeTab = 'night'"
      >
        Night Shifts
      </button>
    </div>
    
    <div class="area-cover-tabs__content">
      <div v-if="activeTab === 'day'" class="area-cover-tabs__panel">
        <AreaCoverShiftList shift-type="day" />
      </div>
      
      <div v-if="activeTab === 'night'" class="area-cover-tabs__panel">
        <AreaCoverShiftList shift-type="night" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import AreaCoverShiftList from './AreaCoverShiftList.vue';

const activeTab = ref('day');
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
