<template>
  <div class="modal-backdrop" @click.self="close">
    <div class="modal-content">
      <div class="modal-header">
        <h3>Edit Service: {{ service?.service?.name }}</h3>
        <button class="close-button" @click="close">
          <IconComponent name="close" />
        </button>
      </div>
      
      <div class="modal-body">
        <div v-if="loading" class="loading-indicator">
          Loading service data...
        </div>
        
        <form v-else @submit.prevent="saveService">
          <!-- Service Info -->
          <div class="service-info">
            <div class="info-item">
              <span class="label">Service:</span>
              <span class="value">{{ service?.service?.name }}</span>
            </div>
            <div v-if="service?.service?.description" class="info-item">
              <span class="label">Description:</span>
              <span class="value">{{ service?.service?.description }}</span>
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
            <div class="section-header">
              <h4>Porter Assignments</h4>
              <button 
                type="button" 
                class="add-porter-button"
                @click="showAddPorterForm = !showAddPorterForm"
              >
                {{ showAddPorterForm ? 'Cancel' : 'Add Porter' }}
              </button>
            </div>
            
            <!-- Add Porter Form -->
            <div v-if="showAddPorterForm" class="add-porter-form">
              <div class="form-group">
                <label for="porter">Porter</label>
                <select 
                  id="porter" 
                  v-model="newPorterAssignment.porterId"
                  class="form-control"
                  required
                >
                  <option value="" disabled>Select a porter</option>
                  <option 
                    v-for="porter in availablePorters" 
                    :key="porter.id" 
                    :value="porter.id"
                  >
                    {{ porter.first_name }} {{ porter.last_name }}
                  </option>
                </select>
              </div>
              
              <div class="form-group time-range">
                <div class="time-input">
                  <label for="porterStartTime">Start Time</label>
                  <input 
                    type="time" 
                    id="porterStartTime" 
                    v-model="newPorterAssignment.startTime"
                    class="form-control"
                    required
                  />
                </div>
                
                <div class="time-input">
                  <label for="porterEndTime">End Time</label>
                  <input 
                    type="time" 
                    id="porterEndTime" 
                    v-model="newPorterAssignment.endTime"
                    class="form-control"
                    required
                  />
                </div>
              </div>
              
              <div class="form-actions">
                <button 
                  type="button" 
                  class="cancel-button"
                  @click="showAddPorterForm = false"
                >
                  Cancel
                </button>
                <button 
                  type="button" 
                  class="save-button"
                  :disabled="!isValidPorterAssignment"
                  @click="addPorter"
                >
                  Add Porter
                </button>
              </div>
            </div>
            
            <!-- Porter List -->
            <div v-if="porterAssignments.length === 0" class="empty-porters">
              No porters assigned yet.
            </div>
            
            <div v-else class="porter-list">
              <div 
                v-for="assignment in porterAssignments" 
                :key="assignment.id"
                class="porter-item"
              >
                <div class="porter-info">
                  <div class="porter-name">
                    {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
                  </div>
                  <div class="porter-time">
                    {{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
                  </div>
                </div>
                
                <div class="porter-actions">
                  <button 
                    type="button" 
                    class="edit-button"
                    @click="editPorter(assignment)"
                  >
                    Edit
                  </button>
                  <button 
                    type="button" 
                    class="delete-button"
                    @click="removePorter(assignment)"
                  >
                    Remove
                  </button>
                </div>
              </div>
            </div>
            
            <!-- Edit Porter Form -->
            <div v-if="editingPorter" class="edit-porter-form">
              <h5>Edit Porter Assignment</h5>
              
              <div class="porter-name">
                {{ editingPorter.porter.first_name }} {{ editingPorter.porter.last_name }}
              </div>
              
              <div class="form-group time-range">
                <div class="time-input">
                  <label for="editPorterStartTime">Start Time</label>
                  <input 
                    type="time" 
                    id="editPorterStartTime" 
                    v-model="editPorterForm.startTime"
                    class="form-control"
                    required
                  />
                </div>
                
                <div class="time-input">
                  <label for="editPorterEndTime">End Time</label>
                  <input 
                    type="time" 
                    id="editPorterEndTime" 
                    v-model="editPorterForm.endTime"
                    class="form-control"
                    required
                  />
                </div>
              </div>
              
              <div class="form-actions">
                <button 
                  type="button" 
                  class="cancel-button"
                  @click="cancelEditPorter"
                >
                  Cancel
                </button>
                <button 
                  type="button" 
                  class="save-button"
                  @click="updatePorter"
                >
                  Update
                </button>
              </div>
            </div>
            
            <div v-if="porterError" class="error-message">
              {{ porterError }}
            </div>
          </div>
          
          <!-- Form Actions -->
          <div class="form-actions form-footer-actions">
            <button 
              type="button" 
              class="delete-button"
              @click="confirmDelete"
            >
              Remove Service
            </button>
            
            <div class="save-actions">
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
                :disabled="saving"
              >
                {{ saving ? 'Saving...' : 'Save Changes' }}
              </button>
            </div>
          </div>
          
          <div v-if="formError" class="error-message form-error">
            {{ formError }}
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import { useDefaultServiceCoverStore } from '../../stores/defaultServiceCoverStore';
import { useStaffStore } from '../../stores/staffStore';
import IconComponent from '../IconComponent.vue';

export default {
  name: 'DefaultEditServiceModal',
  components: {
    IconComponent
  },
  props: {
    serviceId: {
      type: String,
      required: true
    }
  },
  emits: ['close', 'service-updated', 'service-removed'],
  setup(props, { emit }) {
    const defaultServiceCoverStore = useDefaultServiceCoverStore();
    const staffStore = useStaffStore();
    
    // Service data
    const service = ref(null);
    const porterAssignments = ref([]);
    
    // Form state
    const startTime = ref('');
    const endTime = ref('');
    const color = ref('');
    const formError = ref('');
    
    // Porter form state
    const showAddPorterForm = ref(false);
    const newPorterAssignment = ref({
      porterId: '',
      startTime: '',
      endTime: ''
    });
    const porterError = ref('');
    
    // Editing porter state
    const editingPorter = ref(null);
    const editPorterForm = ref({
      startTime: '',
      endTime: ''
    });
    
    // UI state
    const loading = ref(true);
    const saving = ref(false);
    
    // Computed properties
    const availablePorters = computed(() => {
      if (!porterAssignments.value || !staffStore.porters) {
        return [];
      }
      const assignedPorterIds = porterAssignments.value.map(pa => pa.porter_id);
      return staffStore.porters.filter(porter => !assignedPorterIds.includes(porter.id));
    });
    
    const isValidPorterAssignment = computed(() => {
      return (
        newPorterAssignment.value.porterId &&
        newPorterAssignment.value.startTime &&
        newPorterAssignment.value.endTime
      );
    });
    
    // Methods
    function close() {
      emit('close');
    }
    
    function formatTime(timeStr) {
      if (!timeStr) return 'N/A';
      
      const [hours, minutes] = timeStr.split(':');
      const h = parseInt(hours, 10);
      const period = h >= 12 ? 'PM' : 'AM';
      const hour = h % 12 || 12;
      
      return `${hour}:${minutes} ${period}`;
    }
    
    async function loadService() {
      loading.value = true;
      
      try {
        // Ensure we have the latest staff data
        await staffStore.initialize();
        
        // Get the service
        const serviceData = defaultServiceCoverStore.getAssignmentById(props.serviceId);
        
        if (!serviceData) {
          formError.value = 'Service not found';
          return;
        }
        
        service.value = serviceData;
        startTime.value = serviceData.start_time;
        endTime.value = serviceData.end_time;
        color.value = serviceData.color;
        
        // Get porter assignments
        const assignments = defaultServiceCoverStore.getPorterAssignmentsByServiceId(props.serviceId);
        porterAssignments.value = assignments || [];
        
        // Initialize new porter assignment times
        newPorterAssignment.value.startTime = serviceData.start_time;
        newPorterAssignment.value.endTime = serviceData.end_time;
      } catch (error) {
        console.error('Error loading service:', error);
        formError.value = 'Failed to load service data';
      } finally {
        loading.value = false;
      }
    }
    
    async function saveService() {
      saving.value = true;
      formError.value = '';
      
      try {
        const updates = {
          start_time: startTime.value,
          end_time: endTime.value,
          color: color.value
        };
        
        const result = await defaultServiceCoverStore.updateService(props.serviceId, updates);
        
        if (result) {
          emit('service-updated', result);
          close();
        } else {
          formError.value = 'Failed to update service';
        }
      } catch (error) {
        console.error('Error updating service:', error);
        formError.value = error.message || 'An unexpected error occurred';
      } finally {
        saving.value = false;
      }
    }
    
    async function addPorter() {
      if (!isValidPorterAssignment.value) {
        porterError.value = 'Please complete all porter assignment fields';
        return;
      }
      
      porterError.value = '';
      saving.value = true;
      
      try {
        const result = await defaultServiceCoverStore.addPorterToService(
          props.serviceId,
          newPorterAssignment.value.porterId,
          newPorterAssignment.value.startTime,
          newPorterAssignment.value.endTime
        );
        
        if (result) {
          // Add to local list
          porterAssignments.value.push(result);
          
          // Reset form
          newPorterAssignment.value = {
            porterId: '',
            startTime: service.value.start_time,
            endTime: service.value.end_time
          };
          
          // Hide form
          showAddPorterForm.value = false;
        } else {
          porterError.value = 'Failed to add porter assignment';
        }
      } catch (error) {
        console.error('Error adding porter assignment:', error);
        porterError.value = error.message || 'An unexpected error occurred';
      } finally {
        saving.value = false;
      }
    }
    
    function editPorter(assignment) {
      editingPorter.value = assignment;
      editPorterForm.value = {
        startTime: assignment.start_time,
        endTime: assignment.end_time
      };
    }
    
    function cancelEditPorter() {
      editingPorter.value = null;
      editPorterForm.value = {
        startTime: '',
        endTime: ''
      };
    }
    
    async function updatePorter() {
      if (!editingPorter.value) return;
      
      saving.value = true;
      porterError.value = '';
      
      try {
        const updates = {
          start_time: editPorterForm.value.startTime,
          end_time: editPorterForm.value.endTime
        };
        
        const result = await defaultServiceCoverStore.updatePorterAssignment(
          editingPorter.value.id, 
          updates
        );
        
        if (result) {
          // Update local list
          const index = porterAssignments.value.findIndex(pa => pa.id === editingPorter.value.id);
          if (index !== -1) {
            porterAssignments.value[index] = result;
          }
          
          // Hide form
          cancelEditPorter();
        } else {
          porterError.value = 'Failed to update porter assignment';
        }
      } catch (error) {
        console.error('Error updating porter assignment:', error);
        porterError.value = error.message || 'An unexpected error occurred';
      } finally {
        saving.value = false;
      }
    }
    
    async function removePorter(assignment) {
      if (!confirm(`Are you sure you want to remove ${assignment.porter.first_name} ${assignment.porter.last_name} from this service?`)) {
        return;
      }
      
      saving.value = true;
      porterError.value = '';
      
      try {
        const success = await defaultServiceCoverStore.removePorterAssignment(assignment.id);
        
        if (success) {
          // Remove from local list
          porterAssignments.value = porterAssignments.value.filter(pa => pa.id !== assignment.id);
        } else {
          porterError.value = 'Failed to remove porter assignment';
        }
      } catch (error) {
        console.error('Error removing porter assignment:', error);
        porterError.value = error.message || 'An unexpected error occurred';
      } finally {
        saving.value = false;
      }
    }
    
    async function confirmDelete() {
      if (!confirm(`Are you sure you want to remove ${service.value?.service?.name} from the default assignments?`)) {
        return;
      }
      
      saving.value = true;
      formError.value = '';
      
      try {
        const success = await defaultServiceCoverStore.removeService(props.serviceId);
        
        if (success) {
          emit('service-removed', props.serviceId);
          close();
        } else {
          formError.value = 'Failed to remove service';
        }
      } catch (error) {
        console.error('Error removing service:', error);
        formError.value = error.message || 'An unexpected error occurred';
      } finally {
        saving.value = false;
      }
    }
    
    // Lifecycle hooks
    onMounted(async () => {
      await loadService();
    });
    
    return {
      service,
      startTime,
      endTime,
      color,
      formError,
      porterAssignments,
      showAddPorterForm,
      newPorterAssignment,
      porterError,
      editingPorter,
      editPorterForm,
      loading,
      saving,
      availablePorters,
      isValidPorterAssignment,
      close,
      formatTime,
      saveService,
      addPorter,
      editPorter,
      cancelEditPorter,
      updatePorter,
      removePorter,
      confirmDelete
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
  max-width: 550px;
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

.service-info {
  background-color: #f5f7fa;
  border-radius: 4px;
  padding: 12px 16px;
  margin-bottom: 20px;
}

.info-item {
  margin-bottom: 8px;
  display: flex;
}

.info-item:last-child {
  margin-bottom: 0;
}

.info-item .label {
  font-weight: 500;
  width: 100px;
  flex-shrink: 0;
}

.info-item .value {
  color: #333;
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
  border-top: 1px solid #eee;
  padding-top: 20px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.section-header h4 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.add-porter-button {
  background-color: #4285F4;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
}

.add-porter-button:hover {
  background-color: #3367d6;
}

.add-porter-form, .edit-porter-form {
  background-color: #f5f7fa;
  border-radius: 4px;
  padding: 16px;
  margin-bottom: 20px;
}

.edit-porter-form h5 {
  margin-top: 0;
  margin-bottom: 12px;
  font-size: 15px;
}

.porter-name {
  margin-bottom: 12px;
  font-weight: 500;
}

.empty-porters {
  padding: 16px;
  text-align: center;
  background-color: #f5f7fa;
  border-radius: 4px;
  color: #666;
  font-size: 14px;
}

.porter-list {
  margin-bottom: 20px;
}

.porter-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border: 1px solid #eee;
  border-radius: 4px;
  margin-bottom: 8px;
}

.porter-info {
  display: flex;
  flex-direction: column;
}

.porter-name {
  font-weight: 500;
  margin-bottom: 4px;
}

.porter-time {
  font-size: 13px;
  color: #666;
}

.porter-actions {
  display: flex;
  gap: 8px;
}

.edit-button, .delete-button {
  background: none;
  border: none;
  font-size: 13px;
  cursor: pointer;
  padding: 4px 8px;
}

.edit-button {
  color: #4285F4;
}

.delete-button {
  color: #d93025;
}

.edit-button:hover, .delete-button:hover {
  text-decoration: underline;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 16px;
}

.form-footer-actions {
  margin-top: 24px;
  border-top: 1px solid #eee;
  padding-top: 20px;
  justify-content: space-between;
}

.save-actions {
  display: flex;
  gap: 12px;
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

.delete-button {
  background-color: transparent;
  border: 1px solid #d93025;
  color: #d93025;
  padding: 8px 16px;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
}

.delete-button:hover {
  background-color: #fce8e6;
}

.error-message {
  color: #d93025;
  font-size: 12px;
  margin-top: 4px;
}

.form-error {
  margin-top: 16px;
  padding: 8px 12px;
  background-color: #fce8e6;
  border-radius: 4px;
  font-size: 14px;
}
</style>
