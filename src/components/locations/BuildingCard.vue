<template>
  <div class="building-card" @click="viewDepartments">
    <div class="building-card__drag-handle" @click.stop>
      <span class="drag-icon">⠿</span>
    </div>
    <div class="building-details">
      <h3 class="building-name">{{ building.name }}</h3>
    </div>
    
    <div class="building-card-footer">
      <div class="department-count">
        {{ departmentCount }} {{ departmentCount === 1 ? 'Department' : 'Departments' }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';

const props = defineProps({
  building: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['view-departments']);

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
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.building-card {
  background-color: #f9f9f9;
  border-radius: mix.radius('md');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  padding: 16px;
  display: flex;
  flex-direction: column;
  position: relative;
  min-height: 100px;
  user-select: none; /* Prevent text selection during drag */
  cursor: pointer; /* Add pointer cursor to indicate clickable */
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  
  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 3px 6px rgba(0, 0, 0, 0.15);
  }
  
  &__drag-handle {
    position: absolute;
    top: 8px;
    right: 8px;
    color: rgba(0, 0, 0, 0.3);
    font-size: 18px;
    cursor: grab;
    
    &:hover {
      color: rgba(0, 0, 0, 0.5);
    }
    
    &:active {
      cursor: grabbing;
    }
    
    .drag-icon {
      display: block;
      transform: rotate(90deg);
    }
  }
  
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
  
  
  .building-card-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-top: 8px;
    
    .department-count {
      background-color: rgba(66, 133, 244, 0.1);
      color: mix.color('primary');
      border-radius: mix.radius('sm');
      padding: 4px 8px;
      font-size: mix.font-size('xs');
      font-weight: 500;
      margin-left: auto;
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
