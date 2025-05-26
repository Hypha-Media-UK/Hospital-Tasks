<template>
  <div class="default-area-cover-section">
    <h2>Area Cover Defaults</h2>
    <p class="section-description">
      Configure default department coverage for each shift type. These settings will be used as templates when creating new shifts.
    </p>
    
    <!-- Shift type tabs -->
    <div class="shift-type-tabs">
      <div 
        v-for="type in shiftTypes" 
        :key="type.value"
        :class="['shift-tab', { active: activeShiftType === type.value }]" 
        @click="activeShiftType = type.value"
      >
        {{ type.label }}
      </div>
    </div>
    
    <!-- Department list -->
    <div class="departments-container">
      <div class="header-actions">
        <h3>{{ currentShiftTypeLabel }} Departments</h3>
        <button class="add-button" @click="showAddDepartmentModal = true">
          Add Department
        </button>
      </div>
      
      <div v-if="loading" class="loading">
        Loading departments...
      </div>
      
      <div v-else-if="departments.length === 0" class="empty-state">
        <p>No departments configured for {{ currentShiftTypeLabel }}.</p>
        <button class="add-button" @click="showAddDepartmentModal = true">
          Add Department
        </button>
      </div>
      
      <div v-else class="departments-list">
        <div 
          v-for="dept in departments" 
          :key="dept.id" 
          class="department-card"
          :style="{ borderColor: dept.color }"
        >
          <div class="department-header">
            <h4>{{ dept.department.name }}</h4>
            <span class="building-name">{{ dept.department.building?.name || 'N/A' }}</span>
          </div>
          
          <div class="department-details">
            <div class="time-range">
              <span>{{ formatTime(dept.start_time) }} - {{ formatTime(dept.end_time) }}</span>
            </div>
            
            <div class="porter-count">
              <span>{{ getPorterCount(dept.id) }} porters assigned</span>
              <span v-if="hasCoverageGap(dept.id)" class="coverage-gap">Coverage gap!</span>
            </div>
          </div>
          
          <div class="department-actions">
            <button class="action-button edit" @click="editDepartment(dept)">
              Edit
            </button>
            <button class="action-button delete" @click="confirmRemoveDepartment(dept)">
              Remove
            </button>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Add Department Modal -->
    <DefaultAddDepartmentModal
      v-if="showAddDepartmentModal"
      :shift-type="activeShiftType"
      @close="showAddDepartmentModal = false"
      @department-added="handleDepartmentAdded"
    />
    
    <!-- Edit Department Modal -->
    <DefaultEditDepartmentModal
      v-if="showEditDepartmentModal && currentDepartment"
      :department-id="currentDepartment.id"
      @close="showEditDepartmentModal = false"
      @department-updated="handleDepartmentUpdated"
      @department-removed="handleDepartmentRemoved"
    />
  </div>
</template>

<script>
import { mapState, mapGetters, mapActions } from 'pinia';
import { useDefaultAreaCoverStore } from '../../stores/defaultAreaCoverStore';
import { useLocationsStore } from '../../stores/locationsStore';
import DefaultAddDepartmentModal from './DefaultAddDepartmentModal.vue';
import DefaultEditDepartmentModal from './DefaultEditDepartmentModal.vue';

export default {
  name: 'DefaultAreaCoverSection',
  components: {
    DefaultAddDepartmentModal,
    DefaultEditDepartmentModal
  },
  data() {
    return {
      activeShiftType: 'week_day',
      shiftTypes: [
        { value: 'week_day', label: 'Week Days' },
        { value: 'week_night', label: 'Week Nights' },
        { value: 'weekend_day', label: 'Weekend Days' },
        { value: 'weekend_night', label: 'Weekend Nights' }
      ],
      showAddDepartmentModal: false,
      showEditDepartmentModal: false,
      currentDepartment: null,
    };
  },
  computed: {
    ...mapState(useDefaultAreaCoverStore, ['porterAssignments']),
    ...mapGetters(useDefaultAreaCoverStore, [
      'hasCoverageGap', 
      'getPorterAssignmentsByAreaId'
    ]),
    ...mapState(useLocationsStore, ['departments']),
    
    loading() {
      return this.defaultAreaCoverStore.loading[this.activeShiftType];
    },
    
    departments() {
      return this.defaultAreaCoverStore.getSortedAssignmentsByType(this.activeShiftType);
    },
    
    currentShiftTypeLabel() {
      const type = this.shiftTypes.find(t => t.value === this.activeShiftType);
      return type ? type.label : 'Unknown Shift Type';
    },
    
    defaultAreaCoverStore() {
      return useDefaultAreaCoverStore();
    }
  },
  watch: {
    activeShiftType: {
      immediate: true,
      handler(newType) {
        this.loadDepartments(newType);
      }
    }
  },
  methods: {
    ...mapActions(useDefaultAreaCoverStore, [
      'fetchAssignments', 
      'addDepartment', 
      'updateDepartment', 
      'removeDepartment'
    ]),
    
    async loadDepartments(shiftType) {
      await this.fetchAssignments(shiftType);
    },
    
    formatTime(timeStr) {
      if (!timeStr) return 'N/A';
      
      // Convert 24h time format to 12h format
      const [hours, minutes] = timeStr.split(':');
      const h = parseInt(hours, 10);
      const period = h >= 12 ? 'PM' : 'AM';
      const hour = h % 12 || 12;
      
      return `${hour}:${minutes} ${period}`;
    },
    
    getPorterCount(deptId) {
      const porterAssignments = this.getPorterAssignmentsByAreaId(deptId);
      return porterAssignments ? porterAssignments.length : 0;
    },
    
    editDepartment(dept) {
      this.currentDepartment = dept;
      this.showEditDepartmentModal = true;
    },
    
    async confirmRemoveDepartment(dept) {
      if (confirm(`Are you sure you want to remove ${dept.department.name} from ${this.currentShiftTypeLabel} defaults?`)) {
        await this.removeDepartment(dept.id);
      }
    },
    
    // Handler for when a department is added via the modal
    handleDepartmentAdded(department) {
      console.log('Department added:', department);
      this.showAddDepartmentModal = false;
      // Department is already added to store in the modal component
    },
    
    // Handler for when a department is updated via the modal
    handleDepartmentUpdated(department) {
      console.log('Department updated:', department);
      this.showEditDepartmentModal = false;
      this.currentDepartment = null;
      // Department is already updated in store in the modal component
    },
    
    // Handler for when a department is removed via the modal
    handleDepartmentRemoved(departmentId) {
      console.log('Department removed:', departmentId);
      this.showEditDepartmentModal = false;
      this.currentDepartment = null;
      // Department is already removed from store in the modal component
    }
  },
  created() {
    // Initialize stores
    this.defaultAreaCoverStore.initialize();
    useLocationsStore().initialize();
  }
};
</script>

<style scoped>
.default-area-cover-section {
  margin-bottom: 40px;
}

h2 {
  margin-bottom: 10px;
  color: #333;
}

.section-description {
  margin-bottom: 20px;
  color: #666;
}

.shift-type-tabs {
  display: flex;
  margin-bottom: 20px;
  border-bottom: 1px solid #ddd;
}

.shift-tab {
  padding: 8px 16px;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-right: 10px;
  font-size: 14px;
}

.shift-tab:hover {
  border-bottom-color: #ccc;
}

.shift-tab.active {
  border-bottom-color: #4285F4;
  color: #4285F4;
  font-weight: 500;
}

.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.add-button {
  background-color: #4285F4;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
}

.add-button:hover {
  background-color: #3367d6;
}

.loading, .empty-state {
  padding: 20px;
  text-align: center;
  color: #666;
  background-color: #f9f9f9;
  border-radius: 4px;
}

.empty-state button {
  margin-top: 10px;
}

.departments-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 15px;
}

.department-card {
  border: 1px solid #ddd;
  border-left-width: 4px;
  border-radius: 4px;
  padding: 15px;
  background-color: white;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.department-header {
  margin-bottom: 10px;
}

.department-header h4 {
  margin: 0 0 5px 0;
  font-size: 16px;
}

.building-name {
  font-size: 12px;
  color: #666;
}

.department-details {
  margin-bottom: 15px;
}

.time-range, .porter-count {
  font-size: 14px;
  margin-bottom: 5px;
}

.coverage-gap {
  color: #d93025;
  font-weight: 500;
  margin-left: 5px;
}

.department-actions {
  display: flex;
  justify-content: flex-end;
}

.action-button {
  background: none;
  border: none;
  font-size: 13px;
  color: #4285F4;
  cursor: pointer;
  padding: 5px 10px;
}

.action-button:hover {
  text-decoration: underline;
}

.action-button.delete {
  color: #d93025;
}
</style>
