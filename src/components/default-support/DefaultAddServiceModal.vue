<template>
  <div class="modal-backdrop" @click.self="close">
    <div class="modal-content">
      <div class="modal-header">
        <h3>Add Service to {{ shiftTypeLabel }}</h3>
        <button class="close-button" @click="close">
          <IconComponent name="close" />
        </button>
      </div>
      
      <div class="modal-body">
        <div v-if="loading" class="loading-indicator">
          Loading services...
        </div>
        
        <form v-else @submit.prevent="saveService">
          <!-- Service Selection -->
          <div class="form-group">
            <label for="service">Service</label>
            <select 
              id="service" 
              v-model="selectedServiceId"
              class="form-control"
              required
            >
              <option value="" disabled>Select a service</option>
              <option 
                v-for="service in availableServices" 
                :key="service.id" 
                :value="service.id"
              >
                {{ service.name }}
              </option>
            </select>
            <div v-if="serviceError" class="error-message">
              {{ serviceError }}
            </div>
          </div>
          
          <!-- Time Range -->
          <div class="form-group time-range">
            <div class="time-input">
              <label for="startTime">Start Time</label>
              <input 
                type="time" 
                id="startTime" 
                v-model="startTime"
                class="form-control"
                required
              />
            </div>
            
            <div class="time-input">
              <label for="endTime">End Time</label>
              <input 
                type="time" 
                id="endTime" 
                v-model="endTime"
                class="form-control"
                required
              />
            </div>
          </div>
          
          <!-- Color Selection -->
          <div class="form-group">
            <label for="color">Color</label>
            <div class="color-picker-wrapper">
              <input 
                type="color" 
                id="color" 
                v-model="color"
                class="color-picker"
              />
              <span class="color-value">{{ color }}</span>
            </div>
          </div>
          
          <!-- Porter Assignments Section -->
          <div class="porter-assignments">
            <h4>Porter Assignments</h4>
            <p class="helper-text">
              You can add porters after saving the service.
            </p>
          </div>
          
          <!-- Form Actions -->
          <div class="form-actions">
            <button 
              type="button" 
              class="cancel-button" 
              @click="close"
            >
              Cancel
            </button>
            <button 
              type="submit" 
              class="save-button"
              :disabled="saving || !selectedServiceId"
            >
              {{ saving ? 'Saving...' : 'Save Service' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import { useDefaultServiceCoverStore } from '../../stores/defaultServiceCoverStore';
import { useSupportServicesStore } from '../../stores/supportServicesStore';
import IconComponent from '../IconComponent.vue';

export default {
  name: 'DefaultAddServiceModal',
  components: {
    IconComponent
  },
  props: {
    shiftType: {
      type: String,
      required: true,
      validator: (value) => ['week_day', 'week_night', 'weekend_day', 'weekend_night'].includes(value)
    }
  },
  emits: ['close', 'service-added'],
  setup(props, { emit }) {
    const defaultServiceCoverStore = useDefaultServiceCoverStore();
    const supportServicesStore = useSupportServicesStore();
    
    // Form state
    const selectedServiceId = ref('');
    const startTime = ref('08:00');
    const endTime = ref('16:00');
    const color = ref('#4285F4');
    const serviceError = ref('');
    
    // UI state
    const loading = ref(false);
    const saving = ref(false);
    
    // Computed properties
    const availableServices = computed(() => {
      // Get IDs of services that are already assigned to this shift type
      const existingServiceIds = defaultServiceCoverStore
        .getSortedAssignmentsByType(props.shiftType)
        .map(a => a.service_id);
      
      // Filter out services that are already assigned
      return supportServicesStore.supportServices.filter(
        service => !existingServiceIds.includes(service.id)
      );
    });
    
    const shiftTypeLabel = computed(() => {
      const labels = {
        'week_day': 'Week Day Shifts',
        'week_night': 'Week Night Shifts',
        'weekend_day': 'Weekend Day Shifts',
        'weekend_night': 'Weekend Night Shifts'
      };
      
      return labels[props.shiftType] || props.shiftType;
    });
    
    // Methods
    function close() {
      emit('close');
    }
    
    async function saveService() {
      if (!selectedServiceId.value) {
        serviceError.value = 'Please select a service';
        return;
      }
      
      saving.value = true;
      serviceError.value = '';
      
      try {
        const result = await defaultServiceCoverStore.addService(
          selectedServiceId.value,
          props.shiftType,
          startTime.value,
          endTime.value,
          color.value
        );
        
        if (result) {
          emit('service-added', result);
          close();
        } else {
          serviceError.value = 'Failed to add service. Please try again.';
        }
      } catch (error) {
        console.error('Error adding service:', error);
        serviceError.value = error.message || 'An unexpected error occurred';
      } finally {
        saving.value = false;
      }
    }
    
    // Lifecycle hooks
    onMounted(async () => {
      loading.value = true;
      
      try {
        // Ensure we have the latest support services loaded
        if (supportServicesStore.supportServices.length === 0) {
          await supportServicesStore.initialize();
        }
        
        // Ensure default assignments are loaded
        await defaultServiceCoverStore.fetchAssignments(props.shiftType);
      } catch (error) {
        console.error('Error loading data:', error);
      } finally {
        loading.value = false;
      }
    });
    
    return {
      selectedServiceId,
      startTime,
      endTime,
      color,
      serviceError,
      loading,
      saving,
      availableServices,
      shiftTypeLabel,
      close,
      saveService
    };
  }
};
</script>

<style scoped>
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 100;
}

.modal-content {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
  width: 90%;
  max-width: 500px;
  max-height: 90vh;
  overflow-y: auto;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid #eee;
}

.modal-header h3 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
}

.close-button {
  background: none;
  border: none;
  cursor: pointer;
  color: #666;
  padding: 4px;
  border-radius: 4px;
}

.close-button:hover {
  background-color: #f1f1f1;
  color: #333;
}

.modal-body {
  padding: 20px;
}

.loading-indicator {
  text-align: center;
  padding: 20px;
  color: #666;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 6px;
  font-weight: 500;
  font-size: 14px;
}

.form-control {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
}

.form-control:focus {
  outline: none;
  border-color: #4285F4;
  box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
}

.time-range {
  display: flex;
  gap: 16px;
}

.time-input {
  flex: 1;
}

.color-picker-wrapper {
  display: flex;
  align-items: center;
  gap: 10px;
}

.color-picker {
  width: 40px;
  height: 40px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.color-value {
  font-family: monospace;
  font-size: 14px;
  color: #666;
}

.porter-assignments {
  margin-top: 24px;
  margin-bottom: 20px;
}

.porter-assignments h4 {
  margin-top: 0;
  margin-bottom: 8px;
  font-size: 16px;
  font-weight: 600;
}

.helper-text {
  margin: 0;
  font-size: 14px;
  color: #666;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 24px;
}

.cancel-button {
  background-color: transparent;
  border: 1px solid #ddd;
  color: #333;
  padding: 8px 16px;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
}

.save-button {
  background-color: #4285F4;
  border: none;
  color: white;
  padding: 8px 16px;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
}

.save-button:hover:not(:disabled) {
  background-color: #3367d6;
}

.save-button:disabled {
  background-color: #a1c2fa;
  cursor: not-allowed;
}

.error-message {
  color: #d93025;
  font-size: 12px;
  margin-top: 4px;
}
</style>
