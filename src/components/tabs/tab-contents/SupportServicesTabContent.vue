<template>
  <div class="support-services-tab">
    <!-- Area Cover Settings Section -->
    <div class="settings-section">
      <h4>Area Coverage</h4>
      <p class="section-description">
        Configure departments that require porter coverage during shifts.
        These settings will be used as defaults when creating new shifts.
      </p>

      <AreaCoverTabs />
    </div>

    <!-- Support Services Section -->
    <div class="settings-section">
      <h4>Service Coverage</h4>
      <p class="section-description">
        Configure support services that require porter coverage during shifts.
        These settings will be used as defaults when creating new shifts.
      </p>
      <SupportServicesTabs />
    </div>
    
  </div>
</template>

<script setup>
import { useAreaCoverStore } from '../../../stores/areaCoverStore';
import { useSupportServicesStore } from '../../../stores/supportServicesStore';
import { onMounted } from 'vue';
import AreaCoverTabs from '../../area-cover/AreaCoverTabs.vue';
import SupportServicesTabs from '../../support-services/SupportServicesTabs.vue';

const areaCoverStore = useAreaCoverStore();
const supportServicesStore = useSupportServicesStore();

// Load data when component mounts
onMounted(async () => {
  // Initialize both area cover and support services stores
  await Promise.all([
    areaCoverStore.initialize(),
    supportServicesStore.initialize()
  ]);
});
</script>

<!-- Styles are now handled by the global CSS layers -->
