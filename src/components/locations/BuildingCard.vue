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

<!-- Styles are now handled by the global CSS layers -->