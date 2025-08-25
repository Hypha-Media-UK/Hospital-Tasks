<template>
  <div class="departments-list">
    <div class="departments-list__header">
      <h4 class="departments-list__title">Departments</h4>
      <div class="departments-list__add">
        <IconButton 
          title="Add Department"
          @click="showAddForm = true"
        >
          <PlusIcon />
        </IconButton>
      </div>
    </div>
    
    <div v-if="showAddForm" class="departments-list__form">
      <input 
        v-model="newDepartmentName" 
        placeholder="Department name"
        class="departments-list__input"
        ref="newDepartmentInput"
        @keyup.enter="addDepartment"
        @keyup.esc="cancelAdd"
      />
      <div class="departments-list__form-actions">
        <button 
          class="btn btn--primary btn--small" 
          @click="addDepartment"
          :disabled="!newDepartmentName.trim()"
        >
          Add
        </button>
        <button 
          class="btn btn--secondary btn--small" 
          @click="cancelAdd"
        >
          Cancel
        </button>
      </div>
    </div>
    
    <div v-if="departments.length === 0 && !showAddForm" class="departments-list__empty">
      No departments added yet
    </div>
    
    <transition-group name="list" tag="div" class="departments-list__items">
      <DepartmentItem 
        v-for="department in departments" 
        :key="department.id"
        :department="department"
      />
    </transition-group>
  </div>
</template>

<script setup>
import { ref, nextTick, computed } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import DepartmentItem from './DepartmentItem.vue';
import IconButton from '../IconButton.vue';
import PlusIcon from '../icons/PlusIcon.vue';

const props = defineProps({
  buildingId: {
    type: String,
    required: true
  }
});

const locationsStore = useLocationsStore();
const showAddForm = ref(false);
const newDepartmentName = ref('');
const newDepartmentInput = ref(null);

// Get departments for this building
const departments = computed(() => {
  return locationsStore.departments.filter(
    dept => dept.building_id === props.buildingId
  ).sort((a, b) => a.name.localeCompare(b.name));
});

// Show add form and focus input
const showAddDepartmentForm = async () => {
  showAddForm.value = true;
  await nextTick();
  newDepartmentInput.value?.focus();
};

// Add a new department
const addDepartment = async () => {
  if (!newDepartmentName.value.trim()) return;
  
  await locationsStore.addDepartment({
    building_id: props.buildingId,
    name: newDepartmentName.value.trim(),
    is_frequent: false
  });
  
  newDepartmentName.value = '';
  showAddForm.value = false;
};

// Cancel adding a department
const cancelAdd = () => {
  newDepartmentName.value = '';
  showAddForm.value = false;
};
</script>

<!-- Styles are now handled by the global CSS layers -->