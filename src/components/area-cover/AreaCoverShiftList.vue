<template>
  <div class="area-cover-shift-list">
  <div class="area-cover-shift-list__header">
    <button class="btn btn--primary" @click="showDepartmentSelector = true">
      Add Department
    </button>
  </div>
    
    <div v-if="areaCoverStore.loading[shiftType]" class="loading">
      Loading {{ shiftTypeLabel.toLowerCase() }} coverage...
    </div>
    
    <div v-else-if="assignments.length === 0" class="empty-state">
      No departments assigned to {{ shiftTypeLabel.toLowerCase() }} coverage. 
      Add departments using the button above.
    </div>
    
    <div v-else class="department-grid">
      <AreaCoverDepartmentCard 
        v-for="assignment in assignments" 
        :key="assignment.id"
        :assignment="assignment"
        @update="handleUpdate"
        @remove="handleRemove"
      />
    </div>
    
    <!-- Department Selector Modal -->
    <div v-if="showDepartmentSelector" class="modal-overlay">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">Add Department to {{ shiftTypeLabel }} Coverage</h3>
          <button class="modal-close" @click="showDepartmentSelector = false">&times;</button>
        </div>
        
        <div class="modal-body">
          <div v-if="availableDepartments.length === 0" class="empty-state">
            No departments available to add. All departments have already been assigned or no departments exist.
          </div>
          
          <div v-else class="department-selector">
            <div v-for="building in buildingsWithAvailableDepartments" :key="building.id" class="building-item">
              <div class="building-name">{{ building.name }}</div>
              
              <div v-for="department in building.departments" :key="department.id" class="department-item">
                <div class="department-name">{{ department.name }}</div>
                <button 
                  class="btn btn--small btn--primary" 
                  @click="addDepartment(department.id)"
                >
                  Add
                </button>
              </div>
            </div>
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            class="btn btn--secondary" 
            @click="showDepartmentSelector = false"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAreaCoverStore } from '../../stores/areaCoverStore';
import { useLocationsStore } from '../../stores/locationsStore';
import AreaCoverDepartmentCard from './AreaCoverDepartmentCard.vue';

const props = defineProps({
  shiftType: {
    type: String,
    required: true,
    validator: (value) => ['week_day', 'week_night', 'weekend_day', 'weekend_night', 'day', 'night'].includes(value)
  }
});

const areaCoverStore = useAreaCoverStore();
const locationsStore = useLocationsStore();

const showDepartmentSelector = ref(false);

// Computed properties
const shiftTypeLabel = computed(() => {
  switch (props.shiftType) {
    case 'week_day': return 'Week Day';
    case 'week_night': return 'Week Night';
    case 'weekend_day': return 'Weekend Day';
    case 'weekend_night': return 'Weekend Night';
    case 'day': return 'Day'; // Legacy support
    case 'night': return 'Night'; // Legacy support
    default: return '';
  }
});

const assignments = computed(() => {
  return areaCoverStore.getSortedAssignmentsByType(props.shiftType);
});

// Get departments from locationsStore directly instead of relying on rootGetters
const availableDepartments = computed(() => {
  const allDepartments = [];
  const buildingsWithDepartments = locationsStore.buildingsWithDepartments || [];
  
  buildingsWithDepartments.forEach(building => {
    building.departments.forEach(dept => {
      allDepartments.push({
        ...dept,
        building_name: building.name
      });
    });
  });
  
  // Get assigned department IDs based on the current assignments for the shift type
  const assignedDeptIds = areaCoverStore.getAssignmentsByShiftType(props.shiftType).map(a => a.department_id);
  
  return allDepartments.filter(dept => !assignedDeptIds.includes(dept.id));
});

const buildingsWithAvailableDepartments = computed(() => {
  // Group available departments by building
  const buildingsMap = new Map();
  
  availableDepartments.value.forEach(dept => {
    const buildingId = dept.building_id;
    const buildingName = dept.building_name || 'Unknown Building';
    
    if (!buildingsMap.has(buildingId)) {
      buildingsMap.set(buildingId, {
        id: buildingId,
        name: buildingName,
        departments: []
      });
    }
    
    buildingsMap.get(buildingId).departments.push(dept);
  });
  
  // Convert map to array and sort by building name
  return Array.from(buildingsMap.values())
    .sort((a, b) => a.name.localeCompare(b.name));
});

// Methods
const addDepartment = async (departmentId) => {
  // Default times based on shift type
  let startTime, endTime;
  
  if (props.shiftType === 'day') {
    startTime = '08:00:00';
    endTime = '16:00:00';
  } else {
    startTime = '20:00:00';
    endTime = '04:00:00';
  }
  
  await areaCoverStore.addDepartment(
    departmentId,
    props.shiftType,
    startTime,
    endTime
  );
  
  showDepartmentSelector.value = false;
};

const handleUpdate = (assignmentId, updates) => {
  areaCoverStore.updateDepartment(assignmentId, updates);
};

const handleRemove = (assignmentId) => {
  if (confirm('Are you sure you want to remove this department from coverage?')) {
    areaCoverStore.removeDepartment(assignmentId);
  }
};

// Lifecycle hooks
onMounted(async () => {
  // Safely fetch assignments for the shift type
  // We'll always fetch since checking property existence is complicated by camelCase vs snake_case
  await areaCoverStore.fetchAssignments(props.shiftType);
  
  if (!locationsStore.buildings.length) {
    await locationsStore.initialize();
  }
});
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.area-cover-shift-list {
  &__header {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    margin-bottom: 16px;
  }
}

.loading, .empty-state {
  padding: 24px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
}

.department-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 16px;
}

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

.modal-title {
  margin: 0;
  font-size: mix.font-size('lg');
  font-weight: 600;
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
  justify-content: flex-end;
  gap: 12px;
}

// Department selector styles
.department-selector {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.building-item {
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: mix.radius('md');
  overflow: hidden;
}

.building-name {
  background-color: rgba(0, 0, 0, 0.03);
  padding: 8px 12px;
  font-weight: 600;
}

.department-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  border-top: 1px solid rgba(0, 0, 0, 0.05);
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.02);
  }
}

.department-name {
  display: flex;
  align-items: center;
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: rgba(66, 133, 244, 0.8);
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
    padding: 4px 8px;
    font-size: mix.font-size('sm');
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
