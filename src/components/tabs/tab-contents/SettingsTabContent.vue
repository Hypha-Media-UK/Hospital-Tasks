<template>
  <div class="settings-tab">
    <AnimatedTabs
      v-model="activeTab"
      :tabs="settingsTabs"
      @tab-change="handleTabChange"
    >
      <!-- Shift Defaults Section -->
      <template #shiftDefaults>
        <div class="settings-section">
          <ShiftDefaultsSettings />
        </div>
      </template>
      
      <!-- App Settings Section -->
      <template #appSettings>
        <div class="settings-section app-settings-section">
          <AppSettings />
        </div>
      </template>
    </AnimatedTabs>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import ShiftDefaultsSettings from '../../settings/ShiftDefaultsSettings.vue';
import AppSettings from '../../settings/AppSettings.vue';
import AnimatedTabs from '../../shared/AnimatedTabs.vue';
import { useSettingsStore } from '../../../stores/settingsStore';
import { useRoute, useRouter } from 'vue-router';

const settingsStore = useSettingsStore();
const route = useRoute();
const router = useRouter();

// Active tab state
const activeTab = ref('shiftDefaults');

// Define tabs for settings
const settingsTabs = [
  { id: 'shiftDefaults', label: 'Shift Defaults' },
  { id: 'appSettings', label: 'App Settings' }
];

// Handle tab change
function handleTabChange(tabId) {
  // Update query parameter
  updateQueryParam(tabId);
}

// Helper function to update the URL query parameter
function updateQueryParam(tabId) {
  router.replace({ 
    query: { 
      ...route.query, 
      'settings-tab': tabId 
    }
  }).catch(err => {
    // Handle navigation errors silently
    if (err.name !== 'NavigationDuplicated') {
      console.error(err);
    }
  });
}

onMounted(() => {
  // Load settings
  settingsStore.loadSettings();
  
  // Check for settings-tab query parameter
  const tabParam = route.query['settings-tab'];
  if (tabParam && ['shiftDefaults', 'appSettings'].includes(tabParam)) {
    activeTab.value = tabParam;
  }
});
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../../assets/scss/mixins' as mix;

.settings-tab {
  /* Make sure the content is visible in both desktop and mobile views */
  display: block !important;
  
  /* Ensure nested AnimatedTabs are properly displayed */
  :deep(.animated-tabs) {
    @media (max-width: 800px) {
      display: flex !important;
      
      .animated-tabs__content {
        display: block !important;
      }
      
      .animated-tabs__content-wrapper {
        display: block !important;
      }
    }
  }
  
  h3 {
    margin-top: 0;
    margin-bottom: 16px;
  }
  
  .settings-section {
    margin-bottom: 32px;
    
    /* Ensure settings sections are visible in mobile */
    @media (max-width: 800px) {
      display: block !important;
    }
    
    h4 {
      font-size: mix.font-size('lg');
      margin-bottom: 8px;
    }
    
    .section-description {
      color: rgba(0, 0, 0, 0.6);
      margin-bottom: 16px;
    }
  }
}
</style>
