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

<!-- Styles are now handled by the global CSS layers -->