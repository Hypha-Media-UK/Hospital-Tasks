<template>
  <div class="support-services-tab">
    <h3>Support Services</h3>
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
</template>

<script setup>
import { useSupportServicesStore } from '../../../stores/supportServicesStore';
import { onMounted, computed } from 'vue';
import ServiceItem from '../../support-services/ServiceItem.vue';
import AddServiceForm from '../../support-services/AddServiceForm.vue';

const supportServicesStore = useSupportServicesStore();

const supportServices = computed(() => supportServicesStore.supportServices);
const loading = computed(() => supportServicesStore.loading);

// Load services when component mounts
onMounted(async () => {
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
}
</style>
