<template>
  <div class="support-services-tabs">
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
</template>

<script setup lang="ts">
import { computed } from 'vue'
import BaseTabs from '../ui/BaseTabs.vue'
import SupportServicesList from './SupportServicesList.vue'
import DayShiftIcon from '../icons/DayShiftIcon.vue'
import NightShiftIcon from '../icons/NightShiftIcon.vue'
import type { ShiftType } from '../../types/supportServices'

const shiftTypeTabs = computed(() => [
  { id: 'week_day', label: 'Week Days', icon: DayShiftIcon },
  { id: 'week_night', label: 'Week Nights', icon: NightShiftIcon },
  { id: 'weekend_day', label: 'Weekend Days', icon: DayShiftIcon },
  { id: 'weekend_night', label: 'Weekend Nights', icon: NightShiftIcon }
])

const handleTabChange = (tabId: string) => {
  // Handle any tab-specific logic here if needed
}
</script>

<style scoped>
.support-services-tabs {
  background: var(--color-background);
  border-radius: var(--border-radius-lg);
  border: 1px solid var(--color-border);
  overflow: hidden;
}

.tab-content {
  padding: var(--spacing-lg);
  min-height: 400px;
}
</style>
