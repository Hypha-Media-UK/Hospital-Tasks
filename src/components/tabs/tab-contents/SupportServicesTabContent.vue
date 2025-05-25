<template>
  <div class="support-services-tab">
    <h3>Area Support</h3>
    
    <!-- Area Cover Section -->
    <div class="settings-section area-cover-section">
      <h4>Area Cover</h4>
      <p class="section-description">
        Configure departments that need to be covered by porters during shifts. 
        These settings will be used as defaults when creating new shifts.
      </p>
      
      <AreaCoverTabs />
    </div>
    
    <!-- Support Services Section -->
    <div class="settings-section">
      <h4>Support Services</h4>
      <p class="section-description">
        Manage support services that can be assigned to porters. These services are not tied to specific departments but require porter support.
      </p>
    
      <div class="error-message" v-if="supportServicesStore.error">
        {{ supportServicesStore.error }}
      </div>
      
      <!-- Add Service Form -->
      <AddServiceForm @add="addService" />
      
      <!-- Services List -->
      <div class="support-services-list">
        <div v-if="loading" class="loading-state">
          Loading support services...
        </div>
        
        <div v-else-if="supportServices.length === 0" class="empty-state">
          No support services found. Add your first service using the button above.
        </div>
        
        <div v-else class="services-grid">
          <ServiceItem 
            v-for="service in supportServices" 
            :key="service.id"
            :service="service"
            @update="updateService"
            @delete="removeService"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { useSupportServicesStore } from '../../../stores/supportServicesStore';
import { useAreaCoverStore } from '../../../stores/areaCoverStore';
import { onMounted, computed } from 'vue';
import ServiceItem from '../../support-services/ServiceItem.vue';
import AddServiceForm from '../../support-services/AddServiceForm.vue';
import AreaCoverTabs from '../../area-cover/AreaCoverTabs.vue';

const supportServicesStore = useSupportServicesStore();
const areaCoverStore = useAreaCoverStore();

const supportServices = computed(() => supportServicesStore.supportServices);
const loading = computed(() => supportServicesStore.loading);

// Load services and area cover data when component mounts
onMounted(async () => {
  // Initialize area cover
  areaCoverStore.initialize();
  
  // Load support services
  await supportServicesStore.loadSupportServices();
});

// Handler functions for CRUD operations
async function addService(service) {
  return await supportServicesStore.addSupportService(service);
}

async function updateService(service) {
  return await supportServicesStore.updateSupportService(service);
}

async function removeService(serviceId) {
  return await supportServicesStore.removeSupportService(serviceId);
}
</script>

<style lang="scss" scoped>
@use '../../../assets/scss/mixins' as mix;

.support-services-tab {
  h3 {
    margin-top: 0;
    margin-bottom: 8px;
  }
  
  .section-description {
    color: rgba(0, 0, 0, 0.6);
    margin-bottom: 24px;
  }
  
  .error-message {
    padding: 12px;
    background-color: rgba(234, 67, 53, 0.1);
    color: #c62828;
    border-radius: 4px;
    margin-bottom: 16px;
  }
  
  .loading-state, .empty-state {
    padding: 24px;
    text-align: center;
    color: rgba(0, 0, 0, 0.6);
    background-color: #f9f9f9;
    border-radius: 8px;
  }
  
  .services-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }
  
  .settings-section {
    margin-bottom: 32px;
    
    h4 {
      font-size: mix.font-size('lg');
      margin-bottom: 8px;
    }
  }
  
  .area-cover-section {
    margin-bottom: 32px;
  }
}
</style>
