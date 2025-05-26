<template>
  <div class="default-service-cover-section">
    <h2>Service Cover Defaults</h2>
    <p class="section-description">
      Configure default service coverage for each shift type. These settings will be used as templates when creating new shifts.
    </p>
    
    <!-- Shift type tabs -->
    <div class="shift-type-tabs">
      <div 
        v-for="type in shiftTypes" 
        :key="type.value"
        :class="['shift-tab', { active: activeShiftType === type.value }]" 
        @click="activeShiftType = type.value"
      >
        {{ type.label }}
      </div>
    </div>
    
    <!-- Services list -->
    <div class="services-container">
      <div class="header-actions">
        <h3>{{ currentShiftTypeLabel }} Services</h3>
        <button class="add-button" @click="showAddServiceModal = true">
          Add Service
        </button>
      </div>
      
      <div v-if="loading" class="loading">
        Loading services...
      </div>
      
      <div v-else-if="services.length === 0" class="empty-state">
        <p>No services configured for {{ currentShiftTypeLabel }}.</p>
        <button class="add-button" @click="showAddServiceModal = true">
          Add Service
        </button>
      </div>
      
      <div v-else class="services-list">
        <div 
          v-for="service in services" 
          :key="service.id" 
          class="service-card"
          :style="{ borderColor: service.color }"
        >
          <div class="service-header">
            <h4>{{ service.service.name }}</h4>
            <span class="service-description" v-if="service.service.description">
              {{ service.service.description }}
            </span>
          </div>
          
          <div class="service-details">
            <div class="time-range">
              <span>{{ formatTime(service.start_time) }} - {{ formatTime(service.end_time) }}</span>
            </div>
            
            <div class="porter-count">
              <span>{{ getPorterCount(service.id) }} porters assigned</span>
              <span v-if="hasCoverageGap(service.id)" class="coverage-gap">Coverage gap!</span>
            </div>
          </div>
          
          <div class="service-actions">
            <button class="action-button edit" @click="editService(service)">
              Edit
            </button>
            <button class="action-button delete" @click="confirmRemoveService(service)">
              Remove
            </button>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Add Service Modal -->
    <DefaultAddServiceModal
      v-if="showAddServiceModal"
      :shift-type="activeShiftType"
      @close="showAddServiceModal = false"
      @service-added="handleServiceAdded"
    />
    
    <!-- Edit Service Modal -->
    <DefaultEditServiceModal
      v-if="showEditServiceModal && currentService"
      :service-id="currentService.id"
      @close="showEditServiceModal = false"
      @service-updated="handleServiceUpdated"
      @service-removed="handleServiceRemoved"
    />
  </div>
</template>

<script>
import { mapState, mapGetters, mapActions } from 'pinia';
import { useDefaultServiceCoverStore } from '../../stores/defaultServiceCoverStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';
import DefaultAddServiceModal from './DefaultAddServiceModal.vue';
import DefaultEditServiceModal from './DefaultEditServiceModal.vue';

export default {
  name: 'DefaultServiceCoverSection',
  components: {
    DefaultAddServiceModal,
    DefaultEditServiceModal
  },
  data() {
    return {
      activeShiftType: 'week_day',
      shiftTypes: [
        { value: 'week_day', label: 'Week Days' },
        { value: 'week_night', label: 'Week Nights' },
        { value: 'weekend_day', label: 'Weekend Days' },
        { value: 'weekend_night', label: 'Weekend Nights' }
      ],
      showAddServiceModal: false,
      showEditServiceModal: false,
      currentService: null,
    };
  },
  computed: {
    ...mapState(useDefaultServiceCoverStore, ['porterAssignments']),
    ...mapGetters(useDefaultServiceCoverStore, [
      'hasCoverageGap', 
      'getPorterAssignmentsByServiceId'
    ]),
    ...mapState(useSupportServicesStore, ['supportServices']),
    
    loading() {
      return this.defaultServiceCoverStore.loading[this.activeShiftType];
    },
    
    services() {
      return this.defaultServiceCoverStore.getSortedAssignmentsByType(this.activeShiftType);
    },
    
    currentShiftTypeLabel() {
      const type = this.shiftTypes.find(t => t.value === this.activeShiftType);
      return type ? type.label : 'Unknown Shift Type';
    },
    
    defaultServiceCoverStore() {
      return useDefaultServiceCoverStore();
    }
  },
  watch: {
    activeShiftType: {
      immediate: true,
      handler(newType) {
        this.loadServices(newType);
      }
    }
  },
  methods: {
    ...mapActions(useDefaultServiceCoverStore, [
      'fetchAssignments', 
      'addService', 
      'updateService', 
      'removeService'
    ]),
    
    async loadServices(shiftType) {
      await this.fetchAssignments(shiftType);
    },
    
    formatTime(timeStr) {
      if (!timeStr) return 'N/A';
      
      // Convert 24h time format to 12h format
      const [hours, minutes] = timeStr.split(':');
      const h = parseInt(hours, 10);
      const period = h >= 12 ? 'PM' : 'AM';
      const hour = h % 12 || 12;
      
      return `${hour}:${minutes} ${period}`;
    },
    
    getPorterCount(serviceId) {
      const porterAssignments = this.getPorterAssignmentsByServiceId(serviceId);
      return porterAssignments ? porterAssignments.length : 0;
    },
    
    editService(service) {
      this.currentService = service;
      this.showEditServiceModal = true;
    },
    
    async confirmRemoveService(service) {
      if (confirm(`Are you sure you want to remove ${service.service.name} from ${this.currentShiftTypeLabel} defaults?`)) {
        await this.removeService(service.id);
      }
    },
    
    // Handler for when a service is added via the modal
    handleServiceAdded(service) {
      console.log('Service added:', service);
      this.showAddServiceModal = false;
      // Service is already added to store in the modal component
    },
    
    // Handler for when a service is updated via the modal
    handleServiceUpdated(service) {
      console.log('Service updated:', service);
      this.showEditServiceModal = false;
      this.currentService = null;
      // Service is already updated in store in the modal component
    },
    
    // Handler for when a service is removed via the modal
    handleServiceRemoved(serviceId) {
      console.log('Service removed:', serviceId);
      this.showEditServiceModal = false;
      this.currentService = null;
      // Service is already removed from store in the modal component
    }
  },
  created() {
    // Initialize stores
    this.defaultServiceCoverStore.initialize();
    useSupportServicesStore().initialize();
  }
};
</script>

<style scoped>
.default-service-cover-section {
  margin-bottom: 40px;
}

h2 {
  margin-bottom: 10px;
  color: #333;
}

.section-description {
  margin-bottom: 20px;
  color: #666;
}

.shift-type-tabs {
  display: flex;
  margin-bottom: 20px;
  border-bottom: 1px solid #ddd;
}

.shift-tab {
  padding: 8px 16px;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-right: 10px;
  font-size: 14px;
}

.shift-tab:hover {
  border-bottom-color: #ccc;
}

.shift-tab.active {
  border-bottom-color: #4285F4;
  color: #4285F4;
  font-weight: 500;
}

.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.add-button {
  background-color: #4285F4;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.add-button:hover {
  background-color: #3367d6;
}

.loading, .empty-state {
  padding: 20px;
  text-align: center;
  color: #666;
  background-color: #f9f9f9;
  border-radius: 4px;
}

.empty-state button {
  margin-top: 10px;
}

.services-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 15px;
}

.service-card {
  border: 1px solid #ddd;
  border-left-width: 4px;
  border-radius: 4px;
  padding: 15px;
  background-color: white;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.service-header {
  margin-bottom: 10px;
}

.service-header h4 {
  margin: 0 0 5px 0;
  font-size: 16px;
}

.service-description {
  font-size: 12px;
  color: #666;
  display: block;
  margin-top: 5px;
}

.service-details {
  margin-bottom: 15px;
}

.time-range, .porter-count {
  font-size: 14px;
  margin-bottom: 5px;
}

.coverage-gap {
  color: #d93025;
  font-weight: 500;
  margin-left: 5px;
}

.service-actions {
  display: flex;
  justify-content: flex-end;
}

.action-button {
  background: none;
  border: none;
  font-size: 13px;
  color: #4285F4;
  cursor: pointer;
  padding: 5px 10px;
}

.action-button:hover {
  text-decoration: underline;
}

.action-button.delete {
  color: #d93025;
}
</style>
