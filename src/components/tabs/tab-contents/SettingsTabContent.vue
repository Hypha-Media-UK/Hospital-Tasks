<template>
  <div class="settings-tab">
    <h3>App Settings</h3>
    
    <!-- App Settings Section -->
    <div class="settings-section app-settings-section">
      <AppSettings />
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
import { useSettingsStore } from '../../../stores/settingsStore';
import { onMounted } from 'vue';

const settingsStore = useSettingsStore();

onMounted(() => {
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
