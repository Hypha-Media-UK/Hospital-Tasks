<template>
  <div class="staff-tab">
    <div class="staff-tabs">
      <div class="staff-tabs__header">
        <button 
          class="staff-tabs__tab" 
          :class="{ 'staff-tabs__tab--active': activeTab === 'porters' }"
          @click="activeTab = 'porters'"
        >
          Porters
        </button>
        <button 
          class="staff-tabs__tab" 
          :class="{ 'staff-tabs__tab--active': activeTab === 'supervisors' }"
          @click="activeTab = 'supervisors'"
        >
          Supervisors
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
          
          <div class="sort-controls supervisor-sort-controls">
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
              </div>
              
              <div class="staff-item__actions">
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
          
          <div class="filter-controls">
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
            
            <div class="porter-type-filters">
              <span>Type:</span>
              <button 
                class="filter-btn" 
                :class="{ 'filter-btn--active': staffStore.porterTypeFilter === 'all' }"
                @click="staffStore.setPorterTypeFilter('all')"
              >
                All Porters
              </button>
              <button 
                class="filter-btn" 
                :class="{ 'filter-btn--active': staffStore.porterTypeFilter === 'shift' }"
                @click="staffStore.setPorterTypeFilter('shift')"
              >
                Shift Porters
              </button>
              <button 
                class="filter-btn" 
                :class="{ 'filter-btn--active': staffStore.porterTypeFilter === 'relief' }"
                @click="staffStore.setPorterTypeFilter('relief')"
              >
                Relief Porters
              </button>
            </div>
            
            <div class="search-container">
              <div class="search-field">
                <span class="search-icon">🔍</span>
                <input 
                  type="text" 
                  placeholder="Search porters..."
                  v-model="searchQuery"
                  class="search-input"
                  @input="onSearchInput"
                />
                <button 
                  v-if="searchQuery" 
                  class="clear-search-btn"
                  @click="clearSearch"
                >
                  ×
                </button>
              </div>
            </div>
            
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
                  <div 
                    class="staff-item__name" 
                    :class="{
                      'porter-absent': staffStore.getPorterAbsenceDetails(porter.id, new Date()),
                      'porter-illness': staffStore.getPorterAbsenceDetails(porter.id, new Date())?.absence_type === 'illness',
                      'porter-annual-leave': staffStore.getPorterAbsenceDetails(porter.id, new Date())?.absence_type === 'annual_leave'
                    }"
                  >
                    <span 
                      class="porter-type-dot"
                      :class="{ 'porter-type-dot--shift': porter.porter_type === 'shift', 'porter-type-dot--relief': porter.porter_type === 'relief' }"
                    ></span>
                    {{ porter.first_name }} {{ porter.last_name }}
                    <span v-if="staffStore.getPorterAbsenceDetails(porter.id, new Date())?.absence_type === 'illness'" 
                          class="absence-badge illness">ILL</span>
                    <span v-if="staffStore.getPorterAbsenceDetails(porter.id, new Date())?.absence_type === 'annual_leave'" 
                          class="absence-badge annual-leave">AL</span>
                  </div>
                  <div class="staff-item__department">
                    {{ staffStore.formatAvailability(porter) }}
                    
                    <!-- Department and service assignments -->
                    <div v-if="getPorterAssignments(porter.id).length > 0" class="porter-assignments">
                      <div v-for="(assignment, index) in getPorterAssignments(porter.id)" 
                           :key="index" 
                           class="porter-assignment">
                        <span class="department-name" :style="{ color: assignment.color }">
                          {{ assignment.name }}
                        </span>
                        <span class="assignment-details">
                          | {{ assignment.pattern }} ({{ assignment.startTime }}-{{ assignment.endTime }})
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              
              <div class="staff-item__actions">
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
            <div class="form-row">
              <div class="form-group form-group--half">
                <label for="firstName">First Name</label>
                <input 
                  id="firstName"
                  v-model="staffForm.firstName"
                  type="text"
                  required
                  class="form-control"
                />
              </div>
              
              <div class="form-group form-group--half">
                <label for="lastName">Last Name</label>
                <input 
                  id="lastName"
                  v-model="staffForm.lastName"
                  type="text"
                  required
                  class="form-control"
                />
              </div>
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
        
        <div class="modal-tabs" v-if="showEditPorterForm">
          <button 
            class="modal-tab" 
            :class="{ 'modal-tab--active': activeModalTab === 'details' }"
            @click="activeModalTab = 'details'"
          >
            Details
          </button>
          <button 
            class="modal-tab" 
            :class="{ 'modal-tab--active': activeModalTab === 'absence' }"
            @click="activeModalTab = 'absence'"
          >
            Absence
          </button>
        </div>
        
        <div class="modal-body">
          <form @submit.prevent="saveStaff('porter')" v-if="!showEditPorterForm || activeModalTab === 'details'">
            <div class="form-row">
              <div class="form-group form-group--half">
                <label for="firstName">First Name</label>
                <input 
                  id="firstName"
                  v-model="staffForm.firstName"
                  type="text"
                  required
                  class="form-control"
                />
              </div>
              
              <div class="form-group form-group--half">
                <label for="lastName">Last Name</label>
                <input 
                  id="lastName"
                  v-model="staffForm.lastName"
                  type="text"
                  required
                  class="form-control"
                />
              </div>
            </div>
            
            <div class="form-group">
              <div class="checkbox-container">
                <input 
                  type="checkbox" 
                  id="reliefPorterCheckbox" 
                  v-model="staffForm.isRelief"
                  @change="updatePorterType"
                />
                <label for="reliefPorterCheckbox">Relief Porter</label>
              </div>
            </div>

            <div class="form-group">
              <label for="availabilityPattern">Work Pattern</label>
              <select 
                id="availabilityPattern" 
                v-model="staffForm.availabilityPattern"
                class="form-control"
                @change="checkHideContractedHours"
              >
                <option value="">Select a work pattern</option>
                <option 
                  v-for="pattern in staffStore.availabilityPatterns" 
                  :key="pattern" 
                  :value="pattern"
                >
                  {{ pattern }}
                </option>
              </select>
            </div>
            
            <div v-if="hideContractedHours" class="form-group">
              <div class="availability-info">
                Assumes this porter can be moved between shifts
              </div>
            </div>
            
            <div v-else class="form-group">
              <label for="contractedHoursStart">Contracted Hours</label>
              <div class="form-row time-row">
                <div class="form-group form-group--half">
                  <input 
                    type="time" 
                    id="contractedHoursStart" 
                    v-model="staffForm.contractedHoursStart"
                    class="form-control"
                  />
                </div>
                <span class="time-separator">to</span>
                <div class="form-group form-group--half">
                  <input 
                    type="time" 
                    id="contractedHoursEnd" 
                    v-model="staffForm.contractedHoursEnd"
                    class="form-control"
                  />
                </div>
              </div>
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
          
          <!-- Absence Management Form -->
          <div v-if="showEditPorterForm && activeModalTab === 'absence'" class="absence-form">
            <div v-if="staffStore.loading.porters" class="loading-state">
              Loading porter details...
            </div>
            
            <form v-else @submit.prevent="saveAbsence">
              <div class="form-group">
                <label for="absence-type">Absence Type</label>
                <select id="absence-type" v-model="absenceForm.absence_type" class="form-control">
                  <option value="">No Absence</option>
                  <option value="illness">Illness</option>
                  <option value="annual_leave">Annual Leave</option>
                </select>
              </div>
              
              <div class="form-row">
                <div class="form-group form-group--half">
                  <label for="start-date">Start Date</label>
                  <input
                    type="date"
                    id="start-date"
                    v-model="absenceForm.start_date"
                    class="form-control"
                    required
                    :min="today"
                  />
                </div>
                
                <div class="form-group form-group--half">
                  <label for="end-date">End Date</label>
                  <input
                    type="date"
                    id="end-date"
                    v-model="absenceForm.end_date"
                    class="form-control"
                    required
                    :min="absenceForm.start_date || today"
                  />
                </div>
              </div>
              
              <div class="form-group">
                <label for="notes">Notes (Optional)</label>
                <textarea
                  id="notes"
                  v-model="absenceForm.notes"
                  class="form-control textarea"
                  placeholder="Additional details about this absence"
                  rows="3"
                ></textarea>
              </div>
              
              <div v-if="hasExistingAbsence" class="existing-absence-warning">
                <p>This porter already has an absence record for the selected period. Saving will update the existing record.</p>
              </div>
              
              <div v-if="currentAbsence && currentAbsence.id" class="form-actions">
                <button 
                  type="button"
                  @click="confirmDeleteAbsence" 
                  class="btn btn--danger"
                >
                  Delete Absence
                </button>
              </div>
              
              <div class="form-actions">
                <button type="button" class="btn btn--secondary" @click="closeStaffForm">
                  Cancel
                </button>
                <button 
                  type="submit" 
                  class="btn btn--primary"
                  :disabled="absenceForm.absence_type && (!absenceForm.start_date || !absenceForm.end_date)"
                >
                  {{ staffStore.loading.staff ? 'Saving...' : 'Save' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Department management note -->
    <div class="info-message">
      <p>Note: Porter department assignments are now managed in the Area Support tab, where you can also specify time ranges and coverage.</p>
    </div>
    
    <!-- Porter absence is now handled in the porter edit modal -->
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useStaffStore } from '../../../stores/staffStore';
import { useAreaCoverStore } from '../../../stores/areaCoverStore';
import { useSupportServicesStore } from '../../../stores/supportServicesStore';
import IconButton from '../../IconButton.vue';
import EditIcon from '../../icons/EditIcon.vue';
import TrashIcon from '../../icons/TrashIcon.vue';
// PorterAbsenceModal is no longer needed as we've integrated the functionality

const staffStore = useStaffStore();
const areaCoverStore = useAreaCoverStore();
const supportServicesStore = useSupportServicesStore();

// Tab state
const activeTab = ref('porters');
const searchQuery = ref('');

// Form state
const showAddSupervisorForm = ref(false);
const showEditSupervisorForm = ref(false);
const showAddPorterForm = ref(false);
const showEditPorterForm = ref(false);
const hideContractedHours = ref(false);
// These are now handled within the edit porter modal
// const showAbsenceModal = ref(false);
// const selectedPorterId = ref(null);
// const currentPorterAbsence = ref(null);
const staffForm = ref({
  id: null,
  firstName: '',
  lastName: '',
  porterType: 'shift', // Default to shift porter
  isRelief: false, // Checkbox for relief porter
  availabilityPattern: '',
  contractedHoursStart: '09:00',
  contractedHoursEnd: '17:00'
});

// Modal tabs for porter edit form
const activeModalTab = ref('details');

// Absence form state
const absenceForm = ref({
  porter_id: null,
  absence_type: '',
  start_date: '',
  end_date: '',
  notes: ''
});
const currentAbsence = ref(null);

// Get today's date in YYYY-MM-DD format for date input min attribute
const today = computed(() => {
  const today = new Date();
  return today.toISOString().split('T')[0];
});

// Check if there's an existing absence that overlaps with the selected dates
const hasExistingAbsence = computed(() => {
  if (!absenceForm.value.start_date || !absenceForm.value.end_date || !absenceForm.value.porter_id) {
    return false;
  }
  
  const startDate = new Date(absenceForm.value.start_date);
  const endDate = new Date(absenceForm.value.end_date);
  
  // Check if any existing absence overlaps with these dates
  return staffStore.porterAbsences.some(absence => {
    // Skip the current absence being edited
    if (currentAbsence.value && absence.id === currentAbsence.value.id) {
      return false;
    }
    
    const absStart = new Date(absence.start_date);
    const absEnd = new Date(absence.end_date);
    
    // Check for overlap
    return absence.porter_id === absenceForm.value.porter_id && (
      (startDate <= absEnd && endDate >= absStart) // Dates overlap
    );
  });
});

// Initialize data
onMounted(async () => {
  await staffStore.initialize();
  await areaCoverStore.initialize();
  await supportServicesStore.initialize();
});

// Get area assignments for a porter
const getPorterAreaAssignments = (porterId) => {
  const assignments = [];
  
  // Check all area assignments for this porter
  for (const assignment of areaCoverStore.areaAssignments) {
    const porterAssignments = areaCoverStore.getPorterAssignmentsByAreaId(assignment.id)
      .filter(pa => pa.porter_id === porterId);
    
    if (porterAssignments.length > 0) {
      for (const pa of porterAssignments) {
        assignments.push({
          type: 'area',
          name: assignment.department.name,
          color: assignment.color,
          pattern: assignment.shift_type === 'week_day' ? 'Weekdays - Days' :
                  assignment.shift_type === 'week_night' ? 'Weekdays - Nights' :
                  assignment.shift_type === 'weekend_day' ? 'Weekends - Days' :
                  assignment.shift_type === 'weekend_night' ? 'Weekends - Nights' : '',
          startTime: pa.start_time ? pa.start_time.substring(0, 5) : '',
          endTime: pa.end_time ? pa.end_time.substring(0, 5) : ''
        });
      }
    }
  }
  
  return assignments;
};

// Get service assignments for a porter
const getPorterServiceAssignments = (porterId) => {
  const assignments = [];
  
  // Check all service assignments for this porter
  for (const assignment of supportServicesStore.serviceAssignments) {
    const porterAssignments = supportServicesStore.getPorterAssignmentsByServiceId(assignment.id)
      .filter(pa => pa.porter_id === porterId);
    
    if (porterAssignments.length > 0) {
      for (const pa of porterAssignments) {
        assignments.push({
          type: 'service',
          name: assignment.service.name,
          color: assignment.color,
          pattern: assignment.shift_type === 'week_day' ? 'Weekdays - Days' :
                  assignment.shift_type === 'week_night' ? 'Weekdays - Nights' :
                  assignment.shift_type === 'weekend_day' ? 'Weekends - Days' :
                  assignment.shift_type === 'weekend_night' ? 'Weekends - Nights' : '',
          startTime: pa.start_time ? pa.start_time.substring(0, 5) : '',
          endTime: pa.end_time ? pa.end_time.substring(0, 5) : ''
        });
      }
    }
  }
  
  return assignments;
};

// Get all assignments (area and service) for a porter
const getPorterAssignments = (porterId) => {
  const areaAssignments = getPorterAreaAssignments(porterId);
  const serviceAssignments = getPorterServiceAssignments(porterId);
  
  return [...areaAssignments, ...serviceAssignments];
};

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
    lastName: porter.last_name,
    porterType: porter.porter_type || 'shift', // Use existing porter type or default to 'shift'
    isRelief: porter.porter_type === 'relief',
    availabilityPattern: porter.availability_pattern || '',
    contractedHoursStart: porter.contracted_hours_start ? porter.contracted_hours_start.substring(0, 5) : '09:00',
    contractedHoursEnd: porter.contracted_hours_end ? porter.contracted_hours_end.substring(0, 5) : '17:00'
  };
  showEditPorterForm.value = true;
  activeModalTab.value = 'details';
  checkHideContractedHours();
  
  // Initialize absence form if porter exists
  if (porter.id) {
    absenceForm.value = {
      porter_id: porter.id,
      absence_type: '',
      start_date: '',
      end_date: '',
      notes: ''
    };
    
    // Check if porter has an active absence
    const today = new Date();
    currentAbsence.value = staffStore.getPorterAbsenceDetails(porter.id, today);
    
    if (currentAbsence.value) {
      // Format dates for form
      absenceForm.value.absence_type = currentAbsence.value.absence_type;
      absenceForm.value.start_date = currentAbsence.value.start_date ? new Date(currentAbsence.value.start_date).toISOString().split('T')[0] : '';
      absenceForm.value.end_date = currentAbsence.value.end_date ? new Date(currentAbsence.value.end_date).toISOString().split('T')[0] : '';
      absenceForm.value.notes = currentAbsence.value.notes || '';
    }
  }
};

const closeStaffForm = () => {
  showAddSupervisorForm.value = false;
  showEditSupervisorForm.value = false;
  showAddPorterForm.value = false;
  showEditPorterForm.value = false;
  hideContractedHours.value = false;
  staffForm.value = {
    id: null,
    firstName: '',
    lastName: '',
    porterType: 'shift', // Reset to default porter type
    isRelief: false,
    availabilityPattern: '',
    contractedHoursStart: '09:00',
    contractedHoursEnd: '17:00'
  };
};

// Helper method to update porter type based on isRelief checkbox
const updatePorterType = () => {
  staffForm.value.porterType = staffForm.value.isRelief ? 'relief' : 'shift';
};

// Helper method to check if contracted hours should be hidden
const checkHideContractedHours = () => {
  // Hide contracted hours for patterns with "Days and Nights"
  const pattern = staffForm.value.availabilityPattern;
  hideContractedHours.value = pattern.includes('Days and Nights');
  
  // For 24-hour patterns, set contracted hours to cover full day
  if (hideContractedHours.value) {
    staffForm.value.contractedHoursStart = '00:00';
    staffForm.value.contractedHoursEnd = '23:59';
  }
};

const saveStaff = async (role) => {
  const staffData = {
    first_name: staffForm.value.firstName.trim(),
    last_name: staffForm.value.lastName.trim(),
    role
  };
  
  // Add porter_type field for porters
  if (role === 'porter') {
    staffData.porter_type = staffForm.value.porterType;
    staffData.availability_pattern = staffForm.value.availabilityPattern;
    
    // For 24-hour patterns, set contracted hours to cover full day
    if (hideContractedHours.value) {
      staffData.contracted_hours_start = '00:00';
      staffData.contracted_hours_end = '23:59';
    } else {
      staffData.contracted_hours_start = staffForm.value.contractedHoursStart;
      staffData.contracted_hours_end = staffForm.value.contractedHoursEnd;
    }
  }
  
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

// Search methods
const onSearchInput = () => {
  staffStore.setSearchQuery(searchQuery.value);
};

const clearSearch = () => {
  searchQuery.value = '';
  staffStore.setSearchQuery('');
};

// Now handled within the edit porter modal
// const openAbsenceModal = (porterId) => {
//   if (!porterId) return;
//   
//   selectedPorterId.value = porterId;
//   const today = new Date();
//   currentPorterAbsence.value = staffStore.getPorterAbsenceDetails(porterId, today);
//   showAbsenceModal.value = true;
// };
// 
// // Handle absence save
// const handleAbsenceSave = () => {
//   // Refresh the absence data
//   currentPorterAbsence.value = null;
// };

// Save porter absence from the edit form
const saveAbsence = async () => {
  // If no absence type is selected, it means we want to clear any existing absence
  if (!absenceForm.value.absence_type) {
    if (currentAbsence.value && currentAbsence.value.id) {
      await staffStore.deletePorterAbsence(currentAbsence.value.id);
      currentAbsence.value = null;
    }
    closeStaffForm();
    return;
  }
  
  // Make sure we have the required data
  if (!absenceForm.value.porter_id || !absenceForm.value.start_date || !absenceForm.value.end_date) {
    return;
  }
  
  try {
    let result;
    
    if (currentAbsence.value && currentAbsence.value.id) {
      // Update existing absence
      result = await staffStore.updatePorterAbsence(currentAbsence.value.id, absenceForm.value);
    } else {
      // Create new absence
      result = await staffStore.addPorterAbsence(absenceForm.value);
    }
    
    closeStaffForm();
  } catch (error) {
    console.error('Error saving porter absence:', error);
  }
};

// Delete absence
const confirmDeleteAbsence = async () => {
  if (!currentAbsence.value || !currentAbsence.value.id) return;
  
  if (confirm('Are you sure you want to delete this absence record?')) {
    try {
      await staffStore.deletePorterAbsence(currentAbsence.value.id);
      closeStaffForm();
    } catch (error) {
      console.error('Error deleting porter absence:', error);
    }
  }
};
</script>

<style lang="scss" scoped>
@use '../../../assets/scss/mixins' as mix;
@use 'sass:color';

.info-message {
  background-color: rgba(66, 133, 244, 0.1);
  border-left: 4px solid mix.color('primary');
  border-radius: mix.radius('md');
  padding: 12px 16px;
  margin-top: 24px;
  margin-bottom: 24px;
  
  p {
    margin: 0;
    color: rgba(0, 0, 0, 0.7);
  }
}

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

.filter-controls {
  margin-bottom: 16px;
  
  .sort-controls, .porter-type-filters {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 24px;
    flex-wrap: wrap;
    
    span {
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.6);
    }
  }
}

.supervisor-sort-controls {
  margin-bottom: 24px;
}

.sort-btn, .filter-btn {
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


.search-container {
  margin-bottom: 24px;
  
  .search-field {
    position: relative;
    display: flex;
    align-items: center;
    
    .search-icon {
      position: absolute;
      left: 10px;
      font-size: 14px;
      color: rgba(0, 0, 0, 0.4);
    }
    
    .search-input {
      width: 100%;
      padding: 8px 12px 8px 32px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('md');
      font-size: mix.font-size('md');
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
      }
    }
    
    .clear-search-btn {
      position: absolute;
      right: 10px;
      background: none;
      border: none;
      font-size: 18px;
      color: rgba(0, 0, 0, 0.4);
      cursor: pointer;
      padding: 0;
      line-height: 1;
      
      &:hover {
        color: rgba(0, 0, 0, 0.7);
      }
    }
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
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 3px;
    border-radius: mix.radius('sm');
    cursor: pointer;
    
    // Absence indicators
    &.porter-absent {
      opacity: 0.9;
    }
    
    &.porter-illness {
      color: #d32f2f;
      background-color: rgba(234, 67, 53, 0.1);
    }
    
    &.porter-annual-leave {
      color: #f57c00;
      background-color: rgba(251, 192, 45, 0.1);
    }
    
    .absence-badge {
      display: inline-block;
      font-size: 9px;
      font-weight: 700;
      padding: 2px 4px;
      border-radius: 3px;
      margin-left: 5px;
      
      &.illness {
        background-color: #d32f2f;
        color: white;
      }
      
      &.annual-leave {
        background-color: #f57c00;
        color: white;
      }
    }
    
    .porter-type-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      display: inline-block;
      flex-shrink: 0;
      
      &--shift {
        background-color: #4285F4; // Blue for Shift Porter
      }
      
      &--relief {
        background-color: #FF9800; // Orange for Relief Porter
      }
    }
  }
  
  &__department {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
    
    .porter-assignments {
      margin-top: 4px;
      display: flex;
      flex-direction: column;
      gap: 2px;
      
      .porter-assignment {
        font-size: mix.font-size('xs');
        display: flex;
        align-items: center;
        gap: 2px;
        
        .department-name {
          font-weight: 500;
          white-space: nowrap;
        }
        
        .assignment-details {
          color: rgba(0, 0, 0, 0.6);
        }
      }
    }
  }
  
  &__actions {
    display: flex;
    gap: 4px;
    
    @media screen and (max-width: 500px) {
      flex-direction: column;
      gap: 8px;
    }
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

.modal-tabs {
  display: flex;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
}

.modal-tab {
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

.modal-body {
  padding: 16px;
  overflow-y: auto;
  flex: 1;
}

.absence-form {
  .form-control.textarea {
    resize: vertical;
    min-height: 80px;
  }
  
  .absence-details {
    background-color: rgba(0, 0, 0, 0.02);
    padding: 12px;
    border-radius: mix.radius('md');
    margin-top: 12px;
  }
  
  .existing-absence-warning {
    margin-top: 16px;
    padding: 12px;
    background-color: rgba(244, 180, 0, 0.1);
    border-left: 3px solid #F4B400;
    border-radius: mix.radius('sm');
    font-size: mix.font-size('sm');
    
    p {
      margin: 0;
      color: rgba(0, 0, 0, 0.7);
    }
  }
  
  .loading-state {
    padding: 20px;
    text-align: center;
    color: rgba(0, 0, 0, 0.6);
  }
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

// Form styles
.form-row {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  margin-bottom: 16px;
  
  &.time-row {
    align-items: center;
    
    .time-separator {
      margin-top: -8px;
      color: rgba(0, 0, 0, 0.5);
      font-weight: 500;
    }
  }
}

.form-group {
  margin-bottom: 16px;
  
  &--half {
    flex: 1;
    min-width: 120px;
  }
  
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
  
  // Checkbox container
  .checkbox-container {
    display: flex;
    align-items: center;
    margin-top: 4px;
    
    input[type="checkbox"] {
      margin-right: 8px;
      width: 18px;
      height: 18px;
      cursor: pointer;
      -webkit-appearance: checkbox;
      -moz-appearance: checkbox;
      appearance: checkbox;
    }
    
    label {
      display: inline;
      margin-bottom: 0;
      cursor: pointer;
    }
  }
  
  // Availability container
  .availability-container {
    background-color: rgba(0, 0, 0, 0.02);
    padding: 12px;
    border-radius: mix.radius('md');
    margin-top: 8px;
    
    .time-inputs {
      margin-bottom: 16px;
      
      label {
        margin-bottom: 8px;
      }
      
      .time-range {
        display: flex;
        align-items: center;
        gap: 8px;
        
        .time-input {
          flex: 1;
          padding: 8px 12px;
          border: 1px solid rgba(0, 0, 0, 0.2);
          border-radius: mix.radius('md');
          font-size: mix.font-size('md');
          width: auto;
          min-width: 110px;
        }
        
        .time-separator {
          color: rgba(0, 0, 0, 0.5);
          font-weight: 500;
        }
      }
    }
    
    .pattern-select {
      margin-bottom: 16px;
      
      label {
        margin-bottom: 8px;
      }
    }
    
    .availability-info {
      background-color: rgba(66, 133, 244, 0.1);
      padding: 10px;
      border-radius: mix.radius('md');
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.7);
      margin-bottom: 8px;
      border-left: 3px solid rgba(66, 133, 244, 0.6);
    }
  }
}

// Toggle Switch for Porter Type
.toggle-container {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-top: 12px;
  
  .toggle-option {
    font-size: 14px;
    font-weight: 500;
    padding: 4px 0;
    color: rgba(0, 0, 0, 0.5);
    transition: all 0.2s ease;
    min-width: 60px;
    text-align: center;
    
    &.active {
      &:first-of-type {
        color: #4285F4; // Blue for Shift Porter
        font-weight: 600;
      }
      
      &:last-of-type {
        color: #FF9800; // Orange for Relief Porter
        font-weight: 600;
      }
    }
  }
  
  .toggle-switch {
    position: relative;
    width: 48px;
    height: 24px;
    display: inline-block;
    
    .toggle-switch-checkbox {
      opacity: 0;
      width: 0;
      height: 0;
      
      &:checked + .toggle-switch-label .toggle-switch-switch {
        transform: translateX(24px);
        background-color: #FF9800; // Orange for Relief Porter
      }
      
      &:focus + .toggle-switch-label {
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
      }
      
      &:checked + .toggle-switch-label {
        background-color: rgba(255, 152, 0, 0.15); // Light orange background when Relief
      }
    }
    
    .toggle-switch-label {
      display: block;
      overflow: hidden;
      cursor: pointer;
      height: 100%;
      border: 0;
      border-radius: 24px;
      margin: 0;
      background-color: rgba(66, 133, 244, 0.15); // Light blue background when Shift
      transition: background-color 0.3s ease;
      box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
      
      .toggle-switch-switch {
        position: absolute;
        top: 2px;
        left: 2px;
        width: 20px;
        height: 20px;
        background-color: #4285F4; // Blue for Shift Porter
        border-radius: 50%;
        transition: transform 0.2s ease, background-color 0.2s ease;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
      }
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

</style>
