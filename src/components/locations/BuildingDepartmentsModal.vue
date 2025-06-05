<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <div class="modal-title-container">
          <div v-if="isEditingBuildingName" class="building-name-edit">
            <input 
              v-model="editBuildingName" 
              ref="buildingNameInput"
              class="form-control"
              @keyup.enter="saveBuildingName"
              @keyup.esc="cancelEditBuildingName"
              placeholder="Building name"
            />
            <div class="edit-actions">
              <button 
                class="btn btn-small btn-primary" 
                @click="saveBuildingName"
                :disabled="!editBuildingName.trim()"
              >
                Save
              </button>
              <button 
                class="btn btn-small btn-secondary" 
                @click="cancelEditBuildingName"
              >
                Cancel
              </button>
            </div>
          </div>
          <div v-else class="modal-title">
            <h3>{{ building.name }} Departments</h3>
            <button 
              @click="startEditBuildingName" 
              class="btn-action edit-building-btn"
              title="Edit building name"
            >
              <EditIcon size="16" />
            </button>
          </div>
        </div>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <!-- Frequent Departments Section -->
        <div v-if="frequentDepartments.length > 0" class="frequent-departments-section">
          <div class="section-header frequent-section-header">
            <h4 class="section-title">
              Frequent Departments
              <span class="count-badge">{{ frequentDepartments.length }}</span>
            </h4>
            <p class="drag-hint" v-if="frequentDepartments.length > 1">
              <span class="drag-icon">⇅</span> Drag to reorder
            </p>
          </div>
          
          <draggable 
            v-model="sortableFrequentDepartments" 
            class="departments-list frequent-list"
            item-key="id"
            :animation="200"
            :disabled="locationsStore.loading.sorting"
            @end="onFrequentDragEnd"
            handle=".department-drag-handle"
          >
            <template #item="{element}">
              <div class="department-item frequent-item">
              <div v-if="editingDepartment === element.id" class="department-edit">
                <div class="edit-form-group">
                  <input 
                    v-model="editDepartmentName" 
                    class="form-control"
                    @keyup.enter="saveDepartment(element)"
                    @keyup.esc="cancelEditDepartment"
                    placeholder="Department name"
                  />
                  <div class="color-picker-wrapper">
                    <label class="color-picker-label">Color:</label>
                    <input 
                      type="color" 
                      v-model="editDepartmentColor" 
                      class="color-picker"
                    />
                  </div>
                </div>
                <div class="edit-actions">
                    <button 
                      class="btn btn-small btn-primary" 
                      @click="saveDepartment(element)"
                      :disabled="!editDepartmentName.trim()"
                    >
                      Save
                    </button>
                    <button 
                      class="btn btn-small btn-secondary" 
                      @click="cancelEditDepartment"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
                <div v-else class="department-content">
                  <div class="department-drag-handle">
                    <span class="drag-icon">⠿</span>
                  </div>
                  <div class="department-details">
                    <div class="department-name">{{ element.name }}</div>
                  </div>
                  
                  <div class="department-actions">
                    <button 
                      @click="toggleFrequent(element)"
                      class="btn-action btn-remove-frequent" 
                      title="Remove from frequent"
                    >
                      &times;
                    </button>
                  </div>
                </div>
              </div>
            </template>
          </draggable>
        </div>
        
        <!-- Add Department Form -->
        <div class="department-form">
          <div class="form-header">
            <h4>Add Department</h4>
          </div>
          
          <div class="form-content">
            <div class="form-group">
              <input 
                v-model="newDepartmentName" 
                placeholder="Department name"
                class="form-control"
                @keyup.enter="addDepartment"
              />
              <button 
                class="btn btn-primary"
                @click="addDepartment"
                :disabled="!newDepartmentName.trim()"
              >
                Add
              </button>
            </div>
          </div>
        </div>
        
        <!-- All Departments List -->
        <div class="departments-section">
          <h4 class="section-title">All Departments</h4>
          
          <div v-if="sortedBuildingDepartments.length === 0" class="empty-state">
            No departments added yet. Add your first department using the form above.
          </div>
          
          <div v-else class="departments-list">
            <div v-for="department in sortedBuildingDepartments" :key="department.id" class="department-item">
              <div v-if="editingDepartment === department.id" class="department-edit">
                <div class="edit-form-group">
                  <input 
                    v-model="editDepartmentName" 
                    class="form-control"
                    @keyup.enter="saveDepartment(department)"
                    @keyup.esc="cancelEditDepartment"
                    placeholder="Department name"
                  />
                  <div class="color-picker-wrapper">
                    <label class="color-picker-label">Color:</label>
                    <input 
                      type="color" 
                      v-model="editDepartmentColor" 
                      class="color-picker"
                    />
                  </div>
                </div>
                <div class="edit-actions">
                  <button 
                    class="btn btn-small btn-primary" 
                    @click="saveDepartment(department)"
                    :disabled="!editDepartmentName.trim()"
                  >
                    Save
                  </button>
                  <button 
                    class="btn btn-small btn-secondary" 
                    @click="cancelEditDepartment"
                  >
                    Cancel
                  </button>
                </div>
              </div>
              <div v-else class="department-content">
                <div class="department-details">
                  <div class="department-name">{{ department.name }}</div>
                </div>
                
                <div class="department-actions">
                  <button 
                    @click="toggleFrequent(department)"
                    class="btn-action" 
                    :class="{ 'btn-active': department.is_frequent }"
                    title="Mark as frequent"
                  >
                    <StarIcon size="16" />
                  </button>
                  <button 
                    @click="editDepartment(department)"
                    class="btn-action"
                    title="Edit department"
                  >
                    <EditIcon size="16" />
                  </button>
                  <button 
                    @click="deleteDepartment(department)"
                    class="btn-action"
                    title="Delete department"
                  >
                    <TrashIcon size="16" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="modal-footer">
        <div class="modal-footer-left">
          <button @click="confirmDelete" class="btn btn-danger">
            Delete Entire Building
          </button>
        </div>
        <div class="modal-footer-right">
          <button @click="$emit('close')" class="btn btn-secondary">
            Close
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, watch } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import EditIcon from '../icons/EditIcon.vue';
import TrashIcon from '../icons/TrashIcon.vue';
import StarIcon from '../icons/StarIcon.vue';
import draggable from 'vuedraggable';

const props = defineProps({
  building: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close']);

const locationsStore = useLocationsStore();

// Building edit state
const isEditingBuildingName = ref(false);
const editBuildingName = ref('');
const buildingNameInput = ref(null);

// Departments state
const newDepartmentName = ref('');
const editingDepartment = ref(null);
const editDepartmentName = ref('');
const editDepartmentColor = ref('#CCCCCC'); // Default grey color
const localFrequentDepartments = ref([]);

// Building name editing
const startEditBuildingName = async () => {
  editBuildingName.value = props.building.name;
  isEditingBuildingName.value = true;
  // Wait for the DOM to update before focusing the input
  await nextTick();
  buildingNameInput.value?.focus();
};

const saveBuildingName = async () => {
  if (!editBuildingName.value.trim()) {
    cancelEditBuildingName();
    return;
  }
  
  if (editBuildingName.value !== props.building.name) {
    await locationsStore.updateBuilding(props.building.id, {
      name: editBuildingName.value.trim()
    });
  }
  
  isEditingBuildingName.value = false;
};

const cancelEditBuildingName = () => {
  isEditingBuildingName.value = false;
  editBuildingName.value = '';
};

// Computed property to get all departments for this building
const departments = computed(() => {
  return locationsStore.departments
    .filter(dept => dept.building_id === props.building.id)
    .sort((a, b) => {
      // Sort by frequent status first, then by name
      if (a.is_frequent === b.is_frequent) {
        return a.name.localeCompare(b.name);
      }
      return a.is_frequent ? -1 : 1;
    });
});

// Get only frequent departments for this building, sorted by sort_order
const frequentDepartments = computed(() => {
  return locationsStore.departments
    .filter(dept => dept.building_id === props.building.id && dept.is_frequent)
    .sort((a, b) => a.sort_order - b.sort_order);
});

// Initialize local frequent departments when frequentDepartments changes
watch(() => frequentDepartments.value, (newDepts) => {
  localFrequentDepartments.value = [...newDepts];
}, { immediate: true });

// Sortable frequent departments for drag and drop
const sortableFrequentDepartments = computed({
  get: () => {
    return localFrequentDepartments.value;
  },
  set: (newValue) => {
    // Update local state immediately to prevent reversion
    localFrequentDepartments.value = newValue;
    
    // Update sort_order properties on the local departments
    localFrequentDepartments.value.forEach((department, index) => {
      department.sort_order = index * 10; // Multiply by 10 to leave room for insertions later
    });
  }
});

// Get all departments for this building, excluding frequent departments
// This is used for the "All Departments" section, to avoid duplication
const sortedBuildingDepartments = computed(() => {
  return locationsStore.departments
    .filter(dept => dept.building_id === props.building.id)
    .sort((a, b) => a.name.localeCompare(b.name));
});

// Handle drag end event for frequent departments
const onFrequentDragEnd = async (event) => {
  if (event.oldIndex === event.newIndex) return; // No change in order
  
  // Update the sort orders of all frequent departments
  const updates = sortableFrequentDepartments.value.map((department, index) => ({
    id: department.id,
    sort_order: index * 10 // Multiply by 10 to leave room for insertions later
  }));
  
  // Save the changes to the database
  await locationsStore.updateDepartmentsSortOrder(updates);
};

// Add a new department
const addDepartment = async () => {
  if (!newDepartmentName.value.trim()) return;
  
  await locationsStore.addDepartment({
    building_id: props.building.id,
    name: newDepartmentName.value.trim(),
    is_frequent: false,
    color: '#CCCCCC' // Default grey color
  });
  
  newDepartmentName.value = '';
};

// Edit department
const editDepartment = (department) => {
  editingDepartment.value = department.id;
  editDepartmentName.value = department.name;
  editDepartmentColor.value = department.color || '#CCCCCC'; // Initialize with existing color or default
};

// Save department changes
const saveDepartment = async (department) => {
  if (!editDepartmentName.value.trim()) {
    cancelEditDepartment();
    return;
  }
  
  // Check if name or color has changed
  if (editDepartmentName.value !== department.name || editDepartmentColor.value !== department.color) {
    await locationsStore.updateDepartment(department.id, {
      name: editDepartmentName.value.trim(),
      color: editDepartmentColor.value
    });
  }
  
  cancelEditDepartment();
};

// Cancel editing department
const cancelEditDepartment = () => {
  editingDepartment.value = null;
  editDepartmentName.value = '';
  editDepartmentColor.value = '#CCCCCC'; // Reset to default
};

// Toggle frequent status
const toggleFrequent = async (department) => {
  await locationsStore.updateDepartment(department.id, {
    is_frequent: !department.is_frequent
  });
};

// Delete department
const deleteDepartment = async (department) => {
  if (confirm(`Are you sure you want to delete "${department.name}"?`)) {
    await locationsStore.deleteDepartment(department.id);
  }
};

// Delete building with confirmation
const confirmDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.building.name}" and all its departments?`)) {
    await locationsStore.deleteBuilding(props.building.id);
    emit('close');
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

// Modal styles
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-container {
  background-color: white;
  border-radius: mix.radius('lg');
  width: 90%;
  max-width: 600px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.modal-header {
  padding: 16px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title-container {
  display: flex;
  flex: 1;
  margin-right: 16px;
}

.modal-title {
  display: flex;
  align-items: center;
  gap: 8px;
  
  h3 {
    margin: 0;
    font-size: mix.font-size('lg');
    font-weight: 600;
  }
  
  .edit-building-btn {
    opacity: 0.7;
    
    &:hover {
      opacity: 1;
    }
  }
}

.building-name-edit {
  width: 100%;
  
  .form-control {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid mix.color('primary');
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    margin-bottom: 8px;
    
    &:focus {
      outline: none;
      box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.1);
    }
  }
  
  .edit-actions {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }
}

.modal-close {
  background: transparent;
  border: none;
  font-size: 24px;
  cursor: pointer;
  padding: 0;
  line-height: 1;
}

.modal-body {
  padding: 16px;
  overflow-y: auto;
  flex: 1;
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: space-between;
  
  .modal-footer-left {
    display: flex;
    gap: 12px;
  }
  
  .modal-footer-right {
    display: flex;
    gap: 12px;
  }
}

// Frequent Departments Section
.frequent-departments-section {
  margin-bottom: 24px;
  
  .frequent-section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
    
    .section-title {
      display: flex;
      align-items: center;
      gap: 8px;
      margin: 0;
      font-size: mix.font-size('md');
      font-weight: 600;
      
      .count-badge {
        background-color: rgba(245, 158, 11, 0.2);
        color: #B45309;
        font-size: mix.font-size('xs');
        font-weight: 500;
        padding: 2px 8px;
        border-radius: mix.radius('full');
      }
    }
    
    .drag-hint {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.5);
      margin: 0;
      
      .drag-icon {
        font-size: 14px;
      }
    }
  }
  
  .frequent-list {
    display: grid !important;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 12px;
  }
  
  .frequent-item {
    background-color: #FFEDD5 !important; /* Light orange */
    border-radius: mix.radius('lg');
    box-shadow: 0 2px 4px rgba(245, 158, 11, 0.1);
    transition: all 0.2s ease;
    overflow: hidden;
    
    &:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 8px rgba(245, 158, 11, 0.2);
    }
    
    .department-content {
      display: flex;
      align-items: center;
      padding: 12px;
      position: relative;
    }
    
    .department-drag-handle {
      position: absolute;
      top: 8px;
      left: 8px;
      color: rgba(180, 83, 9, 0.4);
      font-size: 18px;
      cursor: grab;
      width: 20px;
      height: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      background-color: rgba(245, 158, 11, 0.1);
      border-radius: 4px;
      transition: all 0.2s ease;
      
      &:hover {
        color: rgba(180, 83, 9, 0.8);
        background-color: rgba(245, 158, 11, 0.2);
      }
      
      &:active {
        cursor: grabbing;
      }
    }
    
    .department-details {
      flex: 1;
      padding-left: 24px; /* Make room for the drag handle */
      padding-right: 24px; /* Make room for the remove button */
    }
    
    .department-name {
      font-weight: 600;
      font-size: mix.font-size('md');
      color: #92400E; /* Amber 800 */
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      text-align: center;
    }
    
    .department-actions {
      position: absolute;
      top: 8px;
      right: 8px;
      
      .btn-remove-frequent {
        width: 20px;
        height: 20px;
        border-radius: 4px;
        padding: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        background-color: rgba(220, 38, 38, 0.1);
        color: #B91C1C;
        font-size: 14px;
        font-weight: bold;
        transition: all 0.2s ease;
        
        &:hover {
          background-color: rgba(220, 38, 38, 0.2);
        }
      }
    }
    
    .department-edit {
      padding: 12px;
      
      .form-control {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid #F59E0B;
        border-radius: mix.radius('md');
        font-size: mix.font-size('md');
        margin-bottom: 8px;
        
        &:focus {
          outline: none;
          box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2);
        }
      }
      
      .edit-actions {
        display: flex;
        gap: 8px;
        justify-content: flex-end;
      }
    }
  }
}

// Department form styles
.department-form {
  background-color: rgba(0, 0, 0, 0.02);
  border-radius: mix.radius('md');
  margin-bottom: 24px;
  overflow: hidden;
  
  .form-header {
    padding: 12px 16px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
    
    h4 {
      margin: 0;
      font-size: mix.font-size('md');
      font-weight: 600;
    }
  }
  
  .form-content {
    padding: 16px;
  }
  
  .form-group {
    display: flex;
    gap: 8px;
    
    .form-control {
      flex: 1;
      padding: 8px 12px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('md');
      font-size: mix.font-size('md');
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.1);
      }
    }
  }
}

// Departments section styles
.departments-section {
  .section-title {
    font-size: mix.font-size('md');
    font-weight: 600;
    margin-top: 0;
    margin-bottom: 16px;
    padding-bottom: 8px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  }
  
  
  .empty-state {
    padding: 24px;
    text-align: center;
    color: rgba(0, 0, 0, 0.6);
    background-color: rgba(0, 0, 0, 0.02);
    border-radius: mix.radius('md');
  }
  
  .departments-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  
  .department-item {
    border-radius: mix.radius('md');
    background-color: rgba(0, 0, 0, 0.02);
    overflow: hidden;
  }

  
  .department-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 16px;
    user-select: none; /* Prevent text selection during drag */
  }
  
  .department-details {
    display: flex;
    align-items: center;
    justify-content: flex-start;
    text-align: left;
    gap: 12px;
    flex: 1;
  }
  
  .department-name {
    font-weight: 500;
  }
  
  .department-actions {
    display: flex;
    gap: 4px;
    margin-left: auto; /* Push to the right */
    justify-content: flex-end;
  }
  
  .department-edit {
    padding: 10px 16px;
    
    .edit-form-group {
      margin-bottom: 12px;
    }
    
    .form-control {
      width: 100%;
      padding: 8px 12px;
      border: 1px solid mix.color('primary');
      border-radius: mix.radius('md');
      font-size: mix.font-size('md');
      margin-bottom: 8px;
      
      &:focus {
        outline: none;
        box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.1);
      }
    }
    
    .color-picker-wrapper {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-top: 8px;
      
      .color-picker-label {
        font-size: mix.font-size('sm');
        font-weight: 500;
        color: rgba(0, 0, 0, 0.7);
      }
      
      .color-picker {
        width: 32px;
        height: 32px;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('sm');
        padding: 0;
        cursor: pointer;
        
        &:focus {
          outline: none;
          border-color: mix.color('primary');
          box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
        }
      }
    }
    
    .edit-actions {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
    }
  }
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &.btn-primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.adjust(mix.color('primary'), $lightness: -10%);
    }
  }
  
  &.btn-secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: color.adjust(#f1f1f1, $lightness: -5%);
    }
  }
  
  &.btn-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.adjust(#dc3545, $lightness: -10%);
    }
  }
  
  &.btn-small {
    padding: 4px 10px;
    font-size: mix.font-size('sm');
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.btn-action {
  background: none;
  border: none;
  cursor: pointer;
  padding: 6px;
  border-radius: mix.radius('sm');
  line-height: 1;
  
  .icon {
    font-size: 16px;
  }
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.05);
  }
  
  &.btn-active {
    color: #F59E0B;
  }
}
</style>
