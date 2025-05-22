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

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.departments-list {
  margin-top: 8px;
  margin-left: 16px;
  
  &__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  
  &__title {
    font-size: mix.font-size('sm');
    font-weight: 500;
    color: rgba(0, 0, 0, 0.6);
    margin: 0;
  }
  
  &__form {
    margin-bottom: 12px;
  }
  
  &__input {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid #ddd;
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    margin-bottom: 8px;
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
  
  &__form-actions {
    display: flex;
    gap: 8px;
  }
  
  &__empty {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.5);
    font-style: italic;
    padding: 8px 0;
  }
  
  &__items {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
}

// Button styles
.btn {
  padding: 6px 12px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.adjust(mix.color('primary'), $lightness: -5%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: #e5e5e5;
    }
  }
  
  &--small {
    font-size: mix.font-size('sm');
    padding: 4px 10px;
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

// List transition animations
.list-enter-active,
.list-leave-active {
  transition: all 0.3s ease;
}

.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(-20px);
}
</style>
