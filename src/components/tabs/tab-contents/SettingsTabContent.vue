<template>
  <div class="settings-tab">
    <h3>App Settings</h3>
    
    <!-- App Settings Section -->
    <div class="settings-section app-settings-section">
      <AppSettings />
    </div>
    
    <!-- Area Cover Settings Section -->
    <div class="settings-section area-cover-section">
      <h4>Area Coverage</h4>
      <p class="section-description">
        Configure departments that require porter coverage during shifts.
        These settings will be used as defaults when creating new shifts.
      </p>
      
      <AreaCoverTabs />
    </div>
    
    <!-- Support Services Settings Section -->
    <div class="settings-section support-services-section">
      <h4>Support Services</h4>
      <p class="section-description">
        Configure support services that require porter coverage during shifts. 
        These settings will be used as defaults when creating new shifts.
      </p>
      
      <SupportServicesTabs />
    </div>
    
    <!-- Shift Defaults Section -->
    <div class="settings-section">
      <ShiftDefaultsSettings />
    </div>
  </div>
</template>

<script setup>
import ShiftDefaultsSettings from '../../settings/ShiftDefaultsSettings.vue';
import AppSettings from '../../settings/AppSettings.vue';
import AreaCoverTabs from '../../area-cover/AreaCoverTabs.vue';
import SupportServicesTabs from '../../support-services/SupportServicesTabs.vue';
import { useSupportServicesStore } from '../../../stores/supportServicesStore';
import { useSettingsStore } from '../../../stores/settingsStore';
import { useAreaCoverStore } from '../../../stores/areaCoverStore';
import { onMounted } from 'vue';

const settingsStore = useSettingsStore();
const supportServicesStore = useSupportServicesStore();
const areaCoverStore = useAreaCoverStore();

onMounted(() => {
  settingsStore.loadSettings();
  supportServicesStore.initialize();
  areaCoverStore.initialize();
});
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../../assets/scss/mixins' as mix;

.settings-tab {
  h3 {
    margin-top: 0;
    margin-bottom: 16px;
  }
  
  .settings-section {
    margin-bottom: 32px;
    
    h4 {
      font-size: mix.font-size('lg');
      margin-bottom: 8px;
    }
    
    .section-description {
      color: rgba(0, 0, 0, 0.6);
      margin-bottom: 16px;
    }
  }
  
  .area-cover-section {
    margin-bottom: 64px; // Bigger gap between Area Cover and Shift Defaults
  }
  
  .support-services-section {
    margin-bottom: 64px; // Bigger gap between Support Services and Shift Defaults
  }
}
</style>
