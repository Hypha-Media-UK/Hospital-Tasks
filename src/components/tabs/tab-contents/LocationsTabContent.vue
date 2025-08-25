<template>
  <div class="locations-tab">
    <div class="locations-tabs">
      <div class="locations-tabs__header">
        <button 
          class="locations-tabs__tab" 
          :class="{ 'locations-tabs__tab--active': activeTab === 'departments' }"
          @click="activeTab = 'departments'"
        >
          Departments
        </button>
        <button 
          class="locations-tabs__tab" 
          :class="{ 'locations-tabs__tab--active': activeTab === 'services' }"
          @click="activeTab = 'services'"
        >
          Services
        </button>
      </div>
      
      <div class="locations-tabs__content">
        <div v-if="activeTab === 'departments'" class="locations-tabs__panel">
          <BuildingsCardList />
        </div>
        
        <div v-if="activeTab === 'services'" class="locations-tabs__panel">
          <div class="settings-section">
            <div class="error-message" v-if="supportServicesStore.error">
              {{ supportServicesStore.error }}
            </div>
            
            <!-- Add Service Button -->
            <div class="button-container">
              <button class="btn btn--primary" @click="showAddServiceModal = true">
                Add Service
              </button>
            </div>
            
            <!-- Services List -->
            <div class="support-services-list">
              <div v-if="loading" class="loading-state">
                Loading support services...
              </div>
              
              <div v-else-if="supportServices.length === 0" class="empty-state">
                No support services found. Add your first service using the button above.
              </div>
              
              <div v-else class="card-grid">
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
      </div>
    </div>
    
    <!-- Add Service Modal -->
    <AddServiceModal
      v-if="showAddServiceModal"
      @add="addService"
      @close="showAddServiceModal = false"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watchEffect } from 'vue';
import BuildingsCardList from '../../locations/BuildingsCardList.vue';
import { useSupportServicesStore } from '../../../stores/supportServicesStore';
import ServiceItem from '../../support-services/ServiceItem.vue';
import AddServiceModal from '../../support-services/AddServiceModal.vue';

// Tab state
const activeTab = ref('departments');

// Service management
const supportServicesStore = useSupportServicesStore();
const showAddServiceModal = ref(false);

const supportServices = computed(() => supportServicesStore.services);
const loading = computed(() => supportServicesStore.loading.services);

// Load support services when component mounts
onMounted(async () => {
  // Load support services when the services tab is first accessed
  if (activeTab.value === 'services') {
    await supportServicesStore.fetchServices();
  }
});

// Watch for tab changes
const watchTabChange = () => {
  if (activeTab.value === 'services' && !supportServicesStore.services.length && !supportServicesStore.loading.services) {
    supportServicesStore.fetchServices();
  }
};

// Add watcher for activeTab
watchEffect(() => {
  watchTabChange();
});

// Handler functions for CRUD operations
async function addService(service) {
  return await supportServicesStore.addService(service.name, service.description);
}

async function updateService(service) {
  return await supportServicesStore.updateService(service.id, service);
}

async function removeService(serviceId) {
  return await supportServicesStore.deleteService(serviceId);
}
</script>

<!-- Styles are now handled by the global CSS layers -->