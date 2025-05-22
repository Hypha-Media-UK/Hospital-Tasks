<template>
  <div class="staff-tab">
    <h3>Staff Management</h3>
    
    <div class="staff-tabs">
      <div class="staff-tabs__header">
        <button 
          class="staff-tabs__tab" 
          :class="{ 'staff-tabs__tab--active': activeTab === 'supervisors' }"
          @click="activeTab = 'supervisors'"
        >
          Supervisors
        </button>
        <button 
          class="staff-tabs__tab" 
          :class="{ 'staff-tabs__tab--active': activeTab === 'porters' }"
          @click="activeTab = 'porters'"
        >
          Porters
        </button>
      </div>
      
      <div class="staff-tabs__content">
        <div v-if="activeTab === 'supervisors'" class="staff-tabs__panel">
          <div class="staff-list-header">
            <h4>Supervisors</h4>
            <button class="btn btn--primary" @click="showAddSupervisorForm = true">
              Add Supervisor
            </button>
          </div>
          
          <div class="sort-controls">
            <span>Sort by:</span>
            <button 
              class="sort-btn" 
              :class="{ 'sort-btn--active': staffStore.sortBy === 'firstName' }"
              @click="staffStore.setSortBy('firstName')"
            >
              First Name
            </button>
            <button 
              class="sort-btn" 
              :class="{ 'sort-btn--active': staffStore.sortBy === 'lastName' }"
              @click="staffStore.setSortBy('lastName')"
            >
              Last Name
            </button>
          </div>
          
          <div v-if="staffStore.loading.supervisors" class="loading">
            Loading supervisors...
          </div>
          
          <div v-else-if="staffStore.sortedSupervisors.length === 0" class="empty-state">
            No supervisors found. Add your first supervisor using the button above.
          </div>
          
          <div v-else class="staff-list">
            <div 
              v-for="supervisor in staffStore.sortedSupervisors" 
              :key="supervisor.id"
              class="staff-item"
            >
              <div class="staff-item__content">
                <div class="staff-item__name">
                  {{ supervisor.first_name }} {{ supervisor.last_name }}
                </div>
                <div class="staff-item__department">
                  {{ supervisor.department ? supervisor.department.name : 'No department assigned' }}
                </div>
              </div>
              
              <div class="staff-item__actions">
                <IconButton 
                  title="Assign Department"
                  :active="!!supervisor.department_id"
                  @click="openDepartmentAssignment(supervisor)"
                >
                  <MapPinIcon :active="!!supervisor.department_id" />
                </IconButton>
                
                <IconButton 
                  title="Edit Supervisor"
                  @click="editSupervisor(supervisor)"
                >
                  <EditIcon />
                </IconButton>
                
                <IconButton 
                  title="Delete Supervisor"
                  @click="deleteSupervisor(supervisor)"
                >
                  <TrashIcon />
                </IconButton>
              </div>
            </div>
          </div>
        </div>
        
        <div v-if="activeTab === 'porters'" class="staff-tabs__panel">
          <div class="staff-list-header">
            <h4>Porters</h4>
            <button class="btn btn--primary" @click="showAddPorterForm = true">
              Add Porter
            </button>
          </div>
          
          <div class="sort-controls">
            <span>Sort by:</span>
            <button 
              class="sort-btn" 
              :class="{ 'sort-btn--active': staffStore.sortBy === 'firstName' }"
              @click="staffStore.setSortBy('firstName')"
            >
              First Name
            </button>
            <button 
              class="sort-btn" 
              :class="{ 'sort-btn--active': staffStore.sortBy === 'lastName' }"
              @click="staffStore.setSortBy('lastName')"
            >
              Last Name
            </button>
          </div>
          
          <div v-if="staffStore.loading.porters" class="loading">
            Loading porters...
          </div>
          
          <div v-else-if="staffStore.sortedPorters.length === 0" class="empty-state">
            No porters found. Add your first porter using the button above.
          </div>
          
          <div v-else class="staff-list">
            <div 
              v-for="porter in staffStore.sortedPorters" 
              :key="porter.id"
              class="staff-item"
            >
              <div class="staff-item__content">
                <div class="staff-item__name">
                  {{ porter.first_name }} {{ porter.last_name }}
                </div>
                <div class="staff-item__department">
                  {{ porter.department ? porter.department.name : 'No department assigned' }}
                </div>
              </div>
              
              <div class="staff-item__actions">
                <IconButton 
                  title="Assign Department"
                  :active="!!porter.department_id"
                  @click="openDepartmentAssignment(porter)"
                >
                  <MapPinIcon :active="!!porter.department_id" />
                </IconButton>
                
                <IconButton 
                  title="Edit Porter"
                  @click="editPorter(porter)"
                >
                  <EditIcon />
                </IconButton>
                
                <IconButton 
                  title="Delete Porter"
                  @click="deletePorter(porter)"
                >
                  <TrashIcon />
                </IconButton>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Staff Form Modal -->
    <div v-if="showAddSupervisorForm || showEditSupervisorForm" class="modal-overlay">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">{{ showEditSupervisorForm ? 'Edit' : 'Add' }} Supervisor</h3>
          <button class="modal-close" @click="closeStaffForm">&times;</button>
        </div>
        
        <div class="modal-body">
          <form @submit.prevent="saveStaff('supervisor')">
            <div class="form-group">
              <label for="firstName">First Name</label>
              <input 
                id="firstName"
                v-model="staffForm.firstName"
                type="text"
                required
                class="form-control"
              />
            </div>
            
            <div class="form-group">
              <label for="lastName">Last Name</label>
              <input 
                id="lastName"
                v-model="staffForm.lastName"
                type="text"
                required
                class="form-control"
              />
            </div>
            
            <div class="form-actions">
              <button type="button" class="btn btn--secondary" @click="closeStaffForm">
                Cancel
              </button>
              <button type="submit" class="btn btn--primary">
                {{ staffStore.loading.staff ? 'Saving...' : 'Save' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    
    <div v-if="showAddPorterForm || showEditPorterForm" class="modal-overlay">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">{{ showEditPorterForm ? 'Edit' : 'Add' }} Porter</h3>
          <button class="modal-close" @click="closeStaffForm">&times;</button>
        </div>
        
        <div class="modal-body">
          <form @submit.prevent="saveStaff('porter')">
            <div class="form-group">
              <label for="firstName">First Name</label>
              <input 
                id="firstName"
                v-model="staffForm.firstName"
                type="text"
                required
                class="form-control"
              />
            </div>
            
            <div class="form-group">
              <label for="lastName">Last Name</label>
              <input 
                id="lastName"
                v-model="staffForm.lastName"
                type="text"
                required
                class="form-control"
              />
            </div>
            
            <div class="form-actions">
              <button type="button" class="btn btn--secondary" @click="closeStaffForm">
                Cancel
              </button>
              <button type="submit" class="btn btn--primary">
                {{ staffStore.loading.staff ? 'Saving...' : 'Save' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    
    <!-- Department Assignment Modal -->
    <div v-if="showDepartmentModal" class="modal-overlay">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">Assign Department to {{ selectedStaff.first_name }} {{ selectedStaff.last_name }}</h3>
          <button class="modal-close" @click="showDepartmentModal = false">&times;</button>
        </div>
        
        <div class="modal-body">
          <div v-if="locationsStore.loading.buildings" class="loading">
            Loading departments...
          </div>
          
          <div v-else-if="buildings.length === 0" class="empty-state">
            No buildings or departments found. Please add some in the Locations tab.
          </div>
          
          <div v-else class="buildings-list">
            <div class="building-item special">
              <div class="building-name">Clear Selection</div>
              <div class="department-item">
                <div class="department-name">No Department</div>
                <div class="department-radio">
                  <input 
                    type="radio" 
                    id="department-none" 
                    name="department"
                    :checked="!selectedDepartment"
                    @change="selectedDepartment = null"
                  />
                </div>
              </div>
            </div>
            
            <div v-for="building in buildings" :key="building.id" class="building-item">
              <div class="building-name">{{ building.name }}</div>
              
              <div v-for="department in building.departments" :key="department.id" class="department-item">
                <div class="department-name">{{ department.name }}</div>
                
                <div class="department-radio">
                  <input 
                    type="radio" 
                    :id="'department-' + department.id" 
                    name="department"
                    :checked="selectedDepartment === department.id"
                    @change="selectedDepartment = department.id"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            class="btn btn--secondary" 
            @click="showDepartmentModal = false"
          >
            Cancel
          </button>
          <button 
            class="btn btn--primary" 
            @click="saveDepartmentAssignment"
            :disabled="staffStore.loading.staff"
          >
            {{ staffStore.loading.staff ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStaffStore } from '../../../stores/staffStore';
import { useLocationsStore } from '../../../stores/locationsStore';
import IconButton from '../../IconButton.vue';
import MapPinIcon from '../../icons/MapPinIcon.vue';
import EditIcon from '../../icons/EditIcon.vue';
import TrashIcon from '../../icons/TrashIcon.vue';

const staffStore = useStaffStore();
const locationsStore = useLocationsStore();

// Tab state
const activeTab = ref('supervisors');

// Form state
const showAddSupervisorForm = ref(false);
const showEditSupervisorForm = ref(false);
const showAddPorterForm = ref(false);
const showEditPorterForm = ref(false);
const staffForm = ref({
  id: null,
  firstName: '',
  lastName: ''
});

// Department assignment state
const showDepartmentModal = ref(false);
const selectedStaff = ref(null);
const selectedDepartment = ref(null);

// Get buildings with their departments
const buildings = computed(() => {
  return locationsStore.buildingsWithDepartments;
});

// Initialize data
onMounted(async () => {
  await Promise.all([
    staffStore.initialize(),
    locationsStore.initialize()
  ]);
});

// Staff form methods
const editSupervisor = (supervisor) => {
  staffForm.value = {
    id: supervisor.id,
    firstName: supervisor.first_name,
    lastName: supervisor.last_name
  };
  showEditSupervisorForm.value = true;
};

const editPorter = (porter) => {
  staffForm.value = {
    id: porter.id,
    firstName: porter.first_name,
    lastName: porter.last_name
  };
  showEditPorterForm.value = true;
};

const closeStaffForm = () => {
  showAddSupervisorForm.value = false;
  showEditSupervisorForm.value = false;
  showAddPorterForm.value = false;
  showEditPorterForm.value = false;
  staffForm.value = {
    id: null,
    firstName: '',
    lastName: ''
  };
};

const saveStaff = async (role) => {
  const staffData = {
    first_name: staffForm.value.firstName.trim(),
    last_name: staffForm.value.lastName.trim(),
    role
  };
  
  let success = false;
  
  if (staffForm.value.id) {
    // Update existing staff
    success = await staffStore.updateStaff(staffForm.value.id, staffData);
  } else {
    // Add new staff
    const result = await staffStore.addStaff(staffData);
    success = !!result;
  }
  
  if (success) {
    closeStaffForm();
  }
};

// Department assignment methods
const openDepartmentAssignment = (staff) => {
  selectedStaff.value = staff;
  selectedDepartment.value = staff.department_id;
  showDepartmentModal.value = true;
};

const saveDepartmentAssignment = async () => {
  if (!selectedStaff.value) return;
  
  const success = await staffStore.assignDepartment(
    selectedStaff.value.id,
    selectedDepartment.value
  );
  
  if (success) {
    showDepartmentModal.value = false;
    selectedStaff.value = null;
    selectedDepartment.value = null;
  }
};

// Delete methods
const deleteSupervisor = async (supervisor) => {
  if (confirm(`Are you sure you want to delete ${supervisor.first_name} ${supervisor.last_name}?`)) {
    await staffStore.deleteStaff(supervisor.id, 'supervisor');
  }
};

const deletePorter = async (porter) => {
  if (confirm(`Are you sure you want to delete ${porter.first_name} ${porter.last_name}?`)) {
    await staffStore.deleteStaff(porter.id, 'porter');
  }
};
</script>

<style lang="scss" scoped>
@use '../../../assets/scss/mixins' as mix;
@use 'sass:color';

.staff-tab {
  h3 {
    margin-top: 0;
    margin-bottom: 16px;
  }
}

.staff-tabs {
  background-color: white;
  border-radius: mix.radius('lg');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  
  &__header {
    display: flex;
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  }
  
  &__tab {
    padding: 12px 16px;
    background: none;
    border: none;
    font-size: mix.font-size('md');
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
    
    &:hover {
      background-color: rgba(0, 0, 0, 0.03);
    }
    
    &--active {
      color: mix.color('primary');
      box-shadow: inset 0 -2px 0 mix.color('primary');
    }
  }
  
  &__content {
    padding: 16px;
  }
  
  &__panel {
    // Panel styles
  }
}

.staff-list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  
  h4 {
    margin: 0;
    font-size: mix.font-size('lg');
  }
}

.sort-controls {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 16px;
  
  span {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
  }
}

.sort-btn {
  background: none;
  border: none;
  padding: 4px 8px;
  border-radius: mix.radius('sm');
  font-size: mix.font-size('sm');
  cursor: pointer;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.05);
  }
  
  &--active {
    background-color: rgba(66, 133, 244, 0.1);
    color: mix.color('primary');
    font-weight: 500;
  }
}

.staff-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.staff-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  border-radius: mix.radius('md');
  background-color: rgba(0, 0, 0, 0.02);
  
  &__content {
    display: flex;
    flex-direction: column;
  }
  
  &__name {
    font-weight: 500;
  }
  
  &__department {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
  }
  
  &__actions {
    display: flex;
    gap: 4px;
  }
}

.loading, .empty-state {
  padding: 24px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
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
  max-width: 500px;
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

// Form styles
.form-group {
  margin-bottom: 16px;
  
  label {
    display: block;
    margin-bottom: 4px;
    font-weight: 500;
  }
  
  .form-control {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 24px;
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
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

// Department assignment modal styles
.buildings-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.building-item {
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: mix.radius('md');
  overflow: hidden;
  
  &.special {
    background-color: rgba(0, 0, 0, 0.02);
    margin-bottom: 8px;
  }
}

.building-name {
  background-color: rgba(0, 0, 0, 0.03);
  padding: 8px 12px;
  font-weight: 600;
}

.department-item {
  display: grid;
  grid-template-columns: 1fr 80px;
  gap: 8px;
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

.department-radio {
  display: flex;
  align-items: center;
  justify-content: center;
  
  input[type="radio"] {
    width: 18px;
    height: 18px;
    cursor: pointer;
  }
}
</style>
