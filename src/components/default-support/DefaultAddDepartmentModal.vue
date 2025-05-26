<template>
  <div class="modal-backdrop" @click.self="close">
    <div class="modal-content">
      <div class="modal-header">
        <h3>Add Department to {{ shiftTypeLabel }}</h3>
        <button class="close-button" @click="close">
          <IconComponent name="close" />
        </button>
      </div>
      
      <div class="modal-body">
        <div v-if="loading" class="loading-indicator">
          Loading departments...
        </div>
        
        <form v-else @submit.prevent="saveDepartment">
          <!-- Department Selection -->
          <div class="form-group">
            <label for="department">Department</label>
            <select 
              id="department" 
              v-model="selectedDepartmentId"
              class="form-control"
              required
            >
              <option value="" disabled>Select a department</option>
              <option 
                v-for="dept in availableDepartments" 
                :key="dept.id" 
                :value="dept.id"
              >
                {{ dept.name }} ({{ dept.building?.name || 'No Building' }})
              </option>
            </select>
            <div v-if="departmentError" class="error-message">
              {{ departmentError }}
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
              You can add porters after saving the department.
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
              :disabled="saving || !selectedDepartmentId"
            >
              {{ saving ? 'Saving...' : 'Save Department' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import { useDefaultAreaCoverStore } from '../../stores/defaultAreaCoverStore';
import { useLocationsStore } from '../../stores/locationsStore';
import IconComponent from '../IconComponent.vue';

export default {
  name: 'DefaultAddDepartmentModal',
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
  emits: ['close', 'department-added'],
  setup(props, { emit }) {
    const defaultAreaCoverStore = useDefaultAreaCoverStore();
    const locationsStore = useLocationsStore();
    
    // Form state
    const selectedDepartmentId = ref('');
    const startTime = ref('08:00');
    const endTime = ref('16:00');
    const color = ref('#4285F4');
    const departmentError = ref('');
    
    // UI state
    const loading = ref(false);
    const saving = ref(false);
    
    // Computed properties
    const availableDepartments = computed(() => {
      const existingDeptIds = defaultAreaCoverStore
        .getSortedAssignmentsByType(props.shiftType)
        .map(a => a.department_id);
      
      return locationsStore.departments.filter(
        dept => !existingDeptIds.includes(dept.id)
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
    
    async function saveDepartment() {
      if (!selectedDepartmentId.value) {
        departmentError.value = 'Please select a department';
        return;
      }
      
      saving.value = true;
      departmentError.value = '';
      
      try {
        const result = await defaultAreaCoverStore.addDepartment(
          selectedDepartmentId.value,
          props.shiftType,
          startTime.value,
          endTime.value,
          color.value
        );
        
        if (result) {
          emit('department-added', result);
          close();
        } else {
          departmentError.value = 'Failed to add department. Please try again.';
        }
      } catch (error) {
        console.error('Error adding department:', error);
        departmentError.value = error.message || 'An unexpected error occurred';
      } finally {
        saving.value = false;
      }
    }
    
    // Lifecycle hooks
    onMounted(async () => {
      loading.value = true;
      
      try {
        // Ensure we have the latest departments loaded
        if (locationsStore.departments.length === 0) {
          await locationsStore.initialize();
        }
        
        // Ensure default assignments are loaded
        await defaultAreaCoverStore.ensureAssignmentsLoaded(props.shiftType);
      } catch (error) {
        console.error('Error loading data:', error);
      } finally {
        loading.value = false;
      }
    });
    
    return {
      selectedDepartmentId,
      startTime,
      endTime,
      color,
      departmentError,
      loading,
      saving,
      availableDepartments,
      shiftTypeLabel,
      close,
      saveDepartment
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
