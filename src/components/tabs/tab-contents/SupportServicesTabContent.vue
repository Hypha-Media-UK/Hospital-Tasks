<template>
  <div class="support-services-tab">
    <!-- Area Cover Settings Section -->
    <div class="settings-section area-cover-section">
      <h4>Area Coverage</h4>
      <p class="section-description">
        Configure departments that require porter coverage during shifts.
        These settings will be used as defaults when creating new shifts.
      </p>
      
      <AreaCoverTabs />
    </div>
    
    <!-- Support Services Section -->
    <div class="settings-section support-services-section">
      <h4>Support Services</h4>
      <p class="section-description">
        Configure support services that require porter coverage during shifts. 
        These settings will be used as defaults when creating new shifts.
      </p>
      
      <SupportServicesTabs />
    </div>
    
  </div>
</template>

<script setup>
import { useAreaCoverStore } from '../../../stores/areaCoverStore';
import { onMounted } from 'vue';
import AreaCoverTabs from '../../area-cover/AreaCoverTabs.vue';
import SupportServicesTabs from '../../support-services/SupportServicesTabs.vue';

const areaCoverStore = useAreaCoverStore();

// Load data when component mounts
onMounted(async () => {
  // Initialize area cover
  await areaCoverStore.initialize();
});
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../../assets/scss/mixins' as mix;

.support-services-tab {
  h3 {
    margin-top: 0;
    margin-bottom: 8px;
  }
  
  .section-description {
    color: rgba(0, 0, 0, 0.6);
    margin-bottom: 24px;
  }
  
  .error-message {
    padding: 12px;
    background-color: rgba(234, 67, 53, 0.1);
    color: #c62828;
    border-radius: 4px;
    margin-bottom: 16px;
  }
  
  .loading-state, .empty-state {
    padding: 24px;
    text-align: center;
    color: rgba(0, 0, 0, 0.6);
    background-color: #f9f9f9;
    border-radius: 8px;
  }
  
  .services-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }
  
  .settings-section {
    margin-bottom: 32px;
    
    h4 {
      font-size: mix.font-size('lg');
      margin-bottom: 8px;
    }
  }
  
  .area-cover-section {
    margin-bottom: 48px;
  }
  
  .support-services-section {
    margin-bottom: 48px;
  }
  
  .button-container {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 16px;
  }
  
  .btn {
    padding: 8px 16px;
    border-radius: mix.radius('md');
    font-weight: 500;
    cursor: pointer;
    border: none;
    transition: all 0.2s ease;
    
    &--primary {
      background-color: mix.color('primary');
      color: white;
      
      &:hover:not(:disabled) {
        background-color: color.scale(mix.color('primary'), $lightness: -10%);
      }
    }
  }
}
</style>
