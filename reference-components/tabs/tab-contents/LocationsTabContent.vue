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

<style lang="scss" scoped>
@use '../../../assets/scss/mixins' as mix;
@use 'sass:color';

.locations-tab {
  h3 {
    margin-top: 0;
    margin-bottom: 16px;
  }
}

.locations-tabs {
  background-color: white;
  border-radius: mix.radius('lg');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  
  &__header {
    display: flex;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  }
  
  &__tab {
    padding: 12px 16px;
    background: none;
    border: none;
    font-size: mix.font-size('md');
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
    
    &:hover {
      background-color: rgba(0, 0, 0, 0.03);
    }
    
    &--active {
      color: mix.color('primary');
      box-shadow: inset 0 -2px 0 mix.color('primary');
    }
  }
  
  &__content {
    padding: 16px;
  }
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

.button-container {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 16px;
}

.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
  }
}
</style>
