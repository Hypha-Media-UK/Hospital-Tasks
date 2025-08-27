<template>
  <BaseModal
    :title="modalTitle"
    size="extra-large"
    @close="$emit('close')"
  >
    <template #header-actions>
      <div v-if="!isEditingBuildingName" class="building-actions">
        <button
          @click="startEditBuildingName"
          class="btn btn--icon"
          title="Edit building name"
        >
          <EditIcon size="16" />
        </button>
      </div>
    </template>

    <!-- Building Name Editing Section -->
    <div v-if="isEditingBuildingName" class="building-name-edit">
      <div class="form-group">
        <label for="buildingName">Building Name</label>
        <input
          id="buildingName"
          v-model="editBuildingName"
          ref="buildingNameInput"
          class="form-control"
          @keyup.enter="saveBuildingName"
          @keyup.esc="cancelEditBuildingName"
          placeholder="Building name"
        />
      </div>
      <div class="form-actions">
        <button
          class="btn btn--secondary"
          @click="cancelEditBuildingName"
        >
          Cancel
        </button>
        <button
          class="btn btn--primary ml-auto"
          @click="saveBuildingName"
          :disabled="!editBuildingName.trim()"
        >
          Save
        </button>
      </div>
    </div>

    <!-- Building Settings Section -->
    <div v-else class="building-settings">
      <div class="porter-serviced-section">
        <label class="porter-serviced-checkbox">
          <input
            type="checkbox"
            :checked="building.porter_serviced || false"
            @change="togglePorterServiced"
          />
          <span class="checkmark"></span>
          <span class="checkbox-label">Porter Serviced</span>
        </label>

        <!-- Building Abbreviation Input -->
        <div class="abbreviation-input-container">
          <label for="abbreviation">Building Code</label>
          <input
            id="abbreviation"
            type="text"
            v-model="buildingAbbreviation"
            :disabled="!building.porter_serviced"
            maxlength="2"
            placeholder="AB"
            class="abbreviation-input"
            @input="onAbbreviationInput"
            @blur="saveAbbreviation"
          />
        </div>
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
                      @click="showTaskAssignment(element)"
                      class="btn-action"
                      :class="{ 'btn-active': hasDepartmentTaskAssignment(element.id) }"
                      title="Assign Task Type & Item"
                    >
                      <TaskIcon size="16" :filled="hasDepartmentTaskAssignment(element.id)" />
                    </button>
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
                    @click="showTaskAssignment(department)"
                    class="btn-action"
                    :class="{ 'btn-active': hasDepartmentTaskAssignment(department.id) }"
                    title="Assign Task Type & Item"
                  >
                    <TaskIcon size="16" :filled="hasDepartmentTaskAssignment(department.id)" />
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
    </div>

    <template #footer>
      <button @click="confirmDelete" class="btn btn--danger">
        Delete Entire Building
      </button>
      <button @click="$emit('close')" class="btn btn--secondary">
        Close
      </button>
    </template>
  </BaseModal>
    
    <!-- Department Task Assignment Modal -->
    <DepartmentTaskAssignmentModal
      v-if="showTaskAssignmentModal && selectedDepartment"
      :department="selectedDepartment"
      @close="showTaskAssignmentModal = false"
      @saved="onTaskAssignmentSaved"
    />
</template>

<script setup>
import { ref, computed, nextTick, watch } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import BaseModal from '../shared/BaseModal.vue';
import EditIcon from '../icons/EditIcon.vue';
import TrashIcon from '../icons/TrashIcon.vue';
import StarIcon from '../icons/StarIcon.vue';
import TaskIcon from '../icons/TaskIcon.vue';
import DepartmentTaskAssignmentModal from './DepartmentTaskAssignmentModal.vue';
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

// Building abbreviation state
const buildingAbbreviation = ref('');

// Departments state
const newDepartmentName = ref('');
const editingDepartment = ref(null);
const editDepartmentName = ref('');
const editDepartmentColor = ref('#CCCCCC'); // Default grey color
const localFrequentDepartments = ref([]);
const showTaskAssignmentModal = ref(false);
const selectedDepartment = ref(null);

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

// Modal title
const modalTitle = computed(() => {
  return isEditingBuildingName.value ? 'Edit Building' : `${props.building.name} Departments`;
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

// Check if a department has a task type/item assignment
const hasDepartmentTaskAssignment = (departmentId) => {
  return !!locationsStore.getDepartmentTaskAssignment(departmentId);
};

// Show task assignment modal for a department
const showTaskAssignment = (department) => {
  selectedDepartment.value = department;
  showTaskAssignmentModal.value = true;
};

// Handle task assignment saved
const onTaskAssignmentSaved = () => {
  // This is just a hook in case we want to do something after saving
  // We could potentially reload data here if needed
};

// Toggle porter serviced status
const togglePorterServiced = async (event) => {
  const isChecked = event.target.checked;
  
  // If unchecking porter serviced, clear the abbreviation
  if (!isChecked) {
    buildingAbbreviation.value = '';
    await locationsStore.updateBuilding(props.building.id, {
      porter_serviced: isChecked,
      abbreviation: null
    });
  } else {
    await locationsStore.updateBuilding(props.building.id, {
      porter_serviced: isChecked
    });
  }
};

// Handle abbreviation input - auto uppercase and limit to 2 characters
const onAbbreviationInput = (event) => {
  const value = event.target.value.toUpperCase();
  buildingAbbreviation.value = value;
};

// Save abbreviation when input loses focus
const saveAbbreviation = async () => {
  if (props.building.porter_serviced) {
    await locationsStore.updateBuilding(props.building.id, {
      abbreviation: buildingAbbreviation.value || null
    });
  }
};

// Initialize abbreviation value when component mounts
watch(() => props.building, (newBuilding) => {
  if (newBuilding) {
    buildingAbbreviation.value = newBuilding.abbreviation || '';
  }
}, { immediate: true });
</script>

<!-- Styles are now handled by the global CSS layers -->