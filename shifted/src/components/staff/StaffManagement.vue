<template>
  <div class="staff-management">
    <div class="management-tabs">
      <BaseTabs
        :tabs="staffTabs"
        default-tab="porters"
        query-param="staff-tab"
        @tab-change="handleTabChange"
      >
        <template #default="{ activeTab }">
          <div class="tab-content">
            <PortersList v-if="activeTab === 'porters'" />
            <SupervisorsList v-if="activeTab === 'supervisors'" />
          </div>
        </template>
      </BaseTabs>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useStaffStore } from '../../stores/staffStore'
import BaseTabs from '../ui/BaseTabs.vue'
import SupervisorsList from './SupervisorsList.vue'
import PortersList from './PortersList.vue'
import StarIcon from '../icons/StarIcon.vue'
import TaskIcon from '../icons/TaskIcon.vue'

const staffStore = useStaffStore()

const staffTabs = computed(() => [
  { id: 'porters', label: 'Porters', icon: TaskIcon },
  { id: 'supervisors', label: 'Supervisors', icon: StarIcon }
])

const handleTabChange = (tabId: string) => {
  // Handle any tab-specific logic here if needed
}

onMounted(async () => {
  // Initialize the store data
  await staffStore.initialize()
})
</script>

<style scoped>
.staff-management {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
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
