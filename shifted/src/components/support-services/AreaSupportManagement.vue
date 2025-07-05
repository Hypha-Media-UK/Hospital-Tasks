<template>
  <div class="area-support-management">
    <div class="section-header">
      <h3>🌟 Area Support Services</h3>
      <p>Manage support services and area coverage assignments</p>
    </div>

    <!-- Area Coverage Section -->
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
      <h4>Service Coverage</h4>
      <p class="section-description">
        Configure support services that require porter coverage during shifts.
        These settings will be used as defaults when creating new shifts.
      </p>

      <SupportServicesTabs />
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useSupportServicesStore } from '../../stores/supportServicesStore'
import { useAreaCoverStore } from '../../stores/areaCoverStore'
import AreaCoverTabs from '../area-cover/AreaCoverTabs.vue'
import SupportServicesTabs from './SupportServicesTabs.vue'

const supportServicesStore = useSupportServicesStore()
const areaCoverStore = useAreaCoverStore()

onMounted(async () => {
  // Initialize both stores
  await Promise.all([
    supportServicesStore.initialize(),
    areaCoverStore.initialize()
  ])
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
  color: var(--color-text-primary);
}

.section-header p {
  color: var(--color-text-secondary);
  margin-bottom: 0;
}

.settings-section {
  margin-bottom: var(--spacing-xl);
}

.settings-section h4 {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: var(--spacing-sm);
  color: var(--color-text-primary);
}

.section-description {
  color: var(--color-text-secondary);
  margin-bottom: var(--spacing-lg);
  line-height: 1.5;
}

.area-cover-section {
  margin-bottom: var(--spacing-xl);
}

.support-services-section {
  margin-bottom: var(--spacing-xl);
}
</style>
