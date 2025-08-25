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
import { useSettingsStore } from '../../stores/settingsStore';
import AreaCoverDepartmentCard from './AreaCoverDepartmentCard.vue';

const props = defineProps({
  shiftType: {
    type: String,
    required: true,
    validator: (value) => ['week_day', 'week_night', 'weekend_day', 'weekend_night'].includes(value)
  }
});

const areaCoverStore = useAreaCoverStore();
const locationsStore = useLocationsStore();
const settingsStore = useSettingsStore();

const showDepartmentSelector = ref(false);

// Computed properties
const shiftTypeLabel = computed(() => {
  switch (props.shiftType) {
    case 'week_day': return 'Week Day';
    case 'week_night': return 'Week Night';
    case 'weekend_day': return 'Weekend Day';
    case 'weekend_night': return 'Weekend Night';
    default: return '';
  }
});

const assignments = computed(() => {
  return areaCoverStore.getSortedAssignmentsByType(props.shiftType);
});

const timeRange = computed(() => {
  if (props.shiftType && settingsStore.shiftDefaults[props.shiftType]) {
    const shiftSettings = settingsStore.shiftDefaults[props.shiftType];
    const startTime = shiftSettings.start_time?.slice(0, 5) || '00:00';
    const endTime = shiftSettings.end_time?.slice(0, 5) || '00:00';
    return `${startTime} - ${endTime}`;
  }
  return '';
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
  // Get default times from settings store based on shift type
  let startTime, endTime;
  
  // Get shift defaults from settings store
  if (settingsStore.shiftDefaults[props.shiftType]) {
    // Convert HH:MM to HH:MM:SS format
    const shiftSettings = settingsStore.shiftDefaults[props.shiftType];
    startTime = (shiftSettings.start_time?.slice(0, 5) || '08:00') + ':00';
    endTime = (shiftSettings.end_time?.slice(0, 5) || '16:00') + ':00';
  } else {
    // Fallback defaults if settings aren't available
    if (props.shiftType.includes('day')) {
      startTime = '08:00:00';
      endTime = '20:00:00';
    } else {
      startTime = '20:00:00';
      endTime = '08:00:00';
    }
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

<!-- Styles are now handled by the global CSS layers -->
