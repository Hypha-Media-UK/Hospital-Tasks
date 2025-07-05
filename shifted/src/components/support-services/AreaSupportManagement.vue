<template>
  <div class="area-support-management">
    <div class="section-header">
      <h3>🌟 Area Support Services</h3>
      <p>Manage support services and area coverage assignments</p>
    </div>

    <div class="management-tabs">
      <BaseTabs
        :tabs="shiftTypeTabs"
        default-tab="week_day"
        query-param="support-tab"
        @tab-change="handleTabChange"
      >
        <template #default="{ activeTab }">
          <div class="tab-content">
            <SupportServicesList :shift-type="activeTab as ShiftType" />
          </div>
        </template>
      </BaseTabs>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useSupportServicesStore } from '../../stores/supportServicesStore'
import BaseTabs from '../ui/BaseTabs.vue'
import SupportServicesList from './SupportServicesList.vue'
import DayShiftIcon from '../icons/DayShiftIcon.vue'
import NightShiftIcon from '../icons/NightShiftIcon.vue'
import type { ShiftType } from '../../types/supportServices'

const supportServicesStore = useSupportServicesStore()

const shiftTypeTabs = computed(() => [
  { id: 'week_day', label: 'Week Days', icon: DayShiftIcon },
  { id: 'week_night', label: 'Week Nights', icon: NightShiftIcon },
  { id: 'weekend_day', label: 'Weekend Days', icon: DayShiftIcon },
  { id: 'weekend_night', label: 'Weekend Nights', icon: NightShiftIcon }
])

const handleTabChange = (tabId: string) => {
  // Handle any tab-specific logic here if needed
}

onMounted(async () => {
  // Initialize the store data
  await supportServicesStore.initialize()
})
</script>

<style scoped>
.area-support-management {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.section-header h3 {
  font-size: 1.5rem;
  font-weight: 600;
  margin-bottom: var(--spacing-sm);
  color: var(--color-text);
}

.section-header p {
  color: var(--color-text-light);
  margin-bottom: 0;
}

.management-tabs {
  background: var(--color-background);
  border-radius: var(--radius-lg);
  border: 1px solid var(--color-border);
  overflow: hidden;
}

.tab-content {
  padding: var(--spacing-lg);
  min-height: 400px;
}
</style>
