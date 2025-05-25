<template>
  <div class="building-card">
    <div class="building-details">
      <h3 class="building-name">{{ building.name }}</h3>
      
      <div class="building-stats">
        <div class="department-count">
          {{ departmentCount }} {{ departmentCount === 1 ? 'Department' : 'Departments' }}
        </div>
      </div>
    </div>
    
    <div class="building-actions">
      <button @click="viewDepartments" class="btn-view" title="View departments">
        <EditIcon size="16" />
      </button>
      <button @click="confirmDelete" class="btn-delete" title="Delete building">
        <TrashIcon size="16" />
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import EditIcon from '../icons/EditIcon.vue';
import TrashIcon from '../icons/TrashIcon.vue';

const props = defineProps({
  building: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['view-departments', 'deleted']);

const locationsStore = useLocationsStore();

// Computed property to count departments
const departmentCount = computed(() => {
  return locationsStore.departments.filter(
    dept => dept.building_id === props.building.id
  ).length;
});

// View departments
const viewDepartments = () => {
  emit('view-departments', props.building.id);
};

// Delete building with confirmation
const confirmDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.building.name}" and all its departments?`)) {
    await locationsStore.deleteBuilding(props.building.id);
    emit('deleted', props.building.id);
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.building-card {
  background-color: white;
  border-radius: mix.radius('md');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  padding: 16px;
  display: flex;
  flex-direction: column;
  position: relative;
  
  .building-details {
    flex: 1;
  }
  
  .building-name {
    margin-top: 0;
    margin-bottom: 8px;
    font-size: mix.font-size('md');
    font-weight: 600;
  }
  
  .building-stats {
    display: flex;
    margin-bottom: 12px;
    
    .department-count {
      background-color: rgba(66, 133, 244, 0.1);
      color: mix.color('primary');
      border-radius: mix.radius('sm');
      padding: 4px 8px;
      font-size: mix.font-size('xs');
      font-weight: 500;
    }
  }
  
  .building-actions {
    display: flex;
    gap: 8px;
    
    button {
      background: none;
      border: none;
      cursor: pointer;
      padding: 6px;
      border-radius: mix.radius('sm');
      
      .icon {
        font-size: 16px;
      }
      
      &.btn-view:hover {
        background-color: rgba(66, 133, 244, 0.1);
      }
      
      &.btn-edit:hover {
        background-color: rgba(0, 0, 0, 0.05);
      }
      
      &.btn-delete:hover {
        background-color: rgba(234, 67, 53, 0.1);
      }
    }
  }
  
}

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
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
  }
  
  &.btn-secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: color.scale(#f1f1f1, $lightness: -5%);
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
