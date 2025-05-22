<template>
  <div class="settings-tab">
    <h3>App Settings</h3>
    
    <!-- Area Cover Section -->
    <div class="settings-section area-cover-section">
      <h4>Area Cover</h4>
      <p class="section-description">
        Configure departments that need to be covered by porters during shifts. 
        These settings will be used as defaults when creating new shifts.
      </p>
      
      <AreaCoverTabs />
    </div>
    
    <!-- Shift Defaults Section -->
    <div class="settings-section">
      <ShiftDefaultsSettings />
    </div>
  </div>
</template>

<script setup>
import AreaCoverTabs from '../../area-cover/AreaCoverTabs.vue';
import ShiftDefaultsSettings from '../../settings/ShiftDefaultsSettings.vue';
import { useAreaCoverStore } from '../../../stores/areaCoverStore';
import { useSettingsStore } from '../../../stores/settingsStore';
import { onMounted } from 'vue';

const areaCoverStore = useAreaCoverStore();
const settingsStore = useSettingsStore();

onMounted(() => {
  areaCoverStore.initialize();
  settingsStore.loadSettings();
});
</script>

<style lang="scss" scoped>
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
}
</style>
