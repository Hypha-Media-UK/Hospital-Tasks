<template>
  <BaseTabs
    :tabs="tabs"
    default-tab="shiftDefaults"
    query-param="settings-tab"
    @tab-change="handleTabChange"
  >
    <template #default="{ activeTab }">
      <div v-if="activeTab === 'shiftDefaults'" class="settings-section">
        <ShiftDefaultsSettings />
      </div>

      <div v-if="activeTab === 'appSettings'" class="settings-section">
        <AppSettings />
      </div>
    </template>
  </BaseTabs>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import BaseTabs from '../ui/BaseTabs.vue'
import ShiftDefaultsSettings from './ShiftDefaultsSettings.vue'
import AppSettings from './AppSettings.vue'
import { useSettingsStore } from '../../stores/settingsStore'

const settingsStore = useSettingsStore()

const tabs = [
  { id: 'shiftDefaults', label: 'Shift Defaults' },
  { id: 'appSettings', label: 'App Settings' }
]

const handleTabChange = (tabId: string) => {
  // Handle any tab-specific logic here if needed
}

onMounted(() => {
  // Load settings when component mounts
  settingsStore.loadSettings()
})
</script>

<style scoped>
.settings-section {
  display: block;
}
</style>
