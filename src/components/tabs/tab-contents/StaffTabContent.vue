<template>
  <div class="staff-tab">
    <AnimatedTabs
      v-model="activeTab"
      :tabs="staffTabs"
      @tab-change="handleTabChange"
    >
      <template #supervisors>
        <div class="staff-tabs__panel">
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
      </template>

      <template #porters>
        <div class="staff-tabs__panel">
          <div class="staff-list-header">
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
            
            <div class="shift-time-filters">
              <span>Shift:</span>
              <button 
                class="filter-btn" 
                :class="{ 'filter-btn--active': staffStore.shiftTimeFilter === 'all' }"
                @click="staffStore.setShiftTimeFilter('all')"
              >
                All Shifts
              </button>
              <button 
                class="filter-btn" 
                :class="{ 'filter-btn--active': staffStore.shiftTimeFilter === 'day' }"
                @click="staffStore.setShiftTimeFilter('day')"
              >
                <DayShiftIcon />
                Day Shift
              </button>
              <button 
                class="filter-btn" 
                :class="{ 'filter-btn--active': staffStore.shiftTimeFilter === 'night' }"
                @click="staffStore.setShiftTimeFilter('night')"
              >
                <NightShiftIcon />
                Night Shift
              </button>
            </div>
            
          </div>
          
          <div v-if="staffStore.loading.porters" class="loading">
            Loading porters...
          </div>
          
          <div v-else-if="filteredPorters.length === 0" class="empty-state">
            No porters found. Add your first porter using the button above.
          </div>
          
          <div v-else class="staff-list">
            <div 
              v-for="porter in filteredPorters" 
              :key="porter.id"
              class="staff-item"
              :class="{
                'staff-item--day-shift': getPorterShiftType(porter) === 'day',
                'staff-item--night-shift': getPorterShiftType(porter) === 'night'
              }"
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
      </template>
    </AnimatedTabs>

    <!-- Supervisor Form Modal -->
    <BaseModal
      v-if="showAddSupervisorForm || showEditSupervisorForm"
      :title="showEditSupervisorForm ? 'Edit Supervisor' : 'Add Supervisor'"
      size="medium"
      @close="closeStaffForm"
    >
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
      </form>

      <template #footer>
        <button type="button" class="btn btn--secondary" @click="closeStaffForm">
          Cancel
        </button>
        <button
          type="submit"
          class="btn btn--primary ml-auto"
          @click="saveStaff('supervisor')"
          :disabled="staffStore.loading.staff"
        >
          {{ staffStore.loading.staff ? 'Saving...' : 'Save' }}
        </button>
      </template>
    </BaseModal>

    <!-- Porter Form Modal -->
    <BaseModal
      v-if="showAddPorterForm || showEditPorterForm"
      :title="showEditPorterForm ? 'Edit Porter' : 'Add Porter'"
      size="large"
      @close="closeStaffForm"
    >
      <AnimatedTabs
        v-model="activeModalTab"
        :tabs="modalTabs"
        @tab-change="handleModalTabChange"
      >
        <template #details>
          <div class="porter-form-content">
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
              <label class="checkbox-label">
                <input
                  type="checkbox"
                  v-model="staffForm.isRelief"
                  @change="updatePorterType"
                />
                Relief Porter
              </label>
            </div>

            <div class="form-group">
              <label for="availabilityPattern">Availability Pattern</label>
              <select
                id="availabilityPattern"
                v-model="staffForm.availabilityPattern"
                class="form-control"
                @change="checkHideContractedHours"
                required
              >
                <option value="">Select availability pattern</option>
                <option value="Days Only">Days Only</option>
                <option value="Nights Only">Nights Only</option>
                <option value="Days and Nights">Days and Nights</option>
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
          </div>
        </template>

        <template #absence>
          <div class="absence-content">
            <div v-if="showEditPorterForm && staffForm.id" class="absence-manager">
              <div class="absence-header">
                <h4>Manage Absences</h4>
                <button
                  class="btn btn--primary btn--small"
                  @click="openAbsenceModal(null)"
                >
                  Add Absence
                </button>
              </div>

              <div v-if="porterAbsences.length === 0" class="empty-state">
                <p>No absences recorded for this porter.</p>
              </div>

              <div v-else class="absence-list">
                <div
                  v-for="absence in porterAbsences"
                  :key="absence.id"
                  class="absence-item"
                >
                  <div class="absence-details">
                    <div class="absence-type">{{ absence.absence_type }}</div>
                    <div class="absence-dates">
                      {{ formatDate(absence.start_date) }} - {{ formatDate(absence.end_date) }}
                    </div>
                    <div v-if="absence.notes" class="absence-notes">{{ absence.notes }}</div>
                  </div>
                  <div class="absence-actions">
                    <button
                      class="btn btn--small btn--secondary"
                      @click="openAbsenceModal(absence)"
                    >
                      Edit
                    </button>
                  </div>
                </div>
              </div>
            </div>
            <div v-else class="absence-placeholder">
              <p>Save the porter first to manage absences.</p>
            </div>
          </div>
        </template>
      </AnimatedTabs>

      <template #footer>
        <button type="button" class="btn btn--secondary" @click="closeStaffForm">
          Cancel
        </button>
        <button
          type="submit"
          class="btn btn--primary ml-auto"
          @click="saveStaff('porter')"
          :disabled="staffStore.loading.staff"
        >
          {{ staffStore.loading.staff ? 'Saving...' : 'Save' }}
        </button>
      </template>
    </BaseModal>

    <!-- Porter Absence Modal -->
    <Teleport to="body" v-if="showAbsenceModal && staffForm.id">
      <PorterAbsenceModal
        :porter-id="staffForm.id"
        :absence="currentPorterAbsence"
        @close="closeAbsenceModal"
        @save="handleAbsenceSave"
      />
    </Teleport>

    <!-- Department management note -->
    <div class="info-message">
      <p>Note: Porter department assignments are now managed in the Area Support tab, where you can also specify time ranges and coverage.</p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useStaffStore } from '../../../stores/staffStore';
import { useAreaCoverStore } from '../../../stores/areaCoverStore';
import { useSupportServicesStore } from '../../../stores/supportServicesStore';
import { useSettingsStore } from '../../../stores/settingsStore';
import AnimatedTabs from '../../shared/AnimatedTabs.vue';
import BaseModal from '../../shared/BaseModal.vue';
import IconButton from '../../IconButton.vue';
import EditIcon from '../../icons/EditIcon.vue';
import TrashIcon from '../../icons/TrashIcon.vue';
import DayShiftIcon from '../../icons/DayShiftIcon.vue';
import NightShiftIcon from '../../icons/NightShiftIcon.vue';
import PorterAbsenceModal from '../../PorterAbsenceModal.vue';

const staffStore = useStaffStore();
const areaCoverStore = useAreaCoverStore();
const supportServicesStore = useSupportServicesStore();
const settingsStore = useSettingsStore();

// Tab state
const activeTab = ref('porters');
const activeModalTab = ref('details');
const searchQuery = ref('');

// Staff tabs configuration
const staffTabs = [
  { id: 'porters', label: 'Porters' },
  { id: 'supervisors', label: 'Supervisors' }
];

// Handle tab change
const handleTabChange = (tabId) => {
  activeTab.value = tabId;
};

// Modal tabs configuration
const modalTabs = [
  { id: 'details', label: 'Details' },
  { id: 'absence', label: 'Absence' }
];

// Handle modal tab change
const handleModalTabChange = (tabId) => {
  activeModalTab.value = tabId;
};

// Form state
const showAddSupervisorForm = ref(false);
const showEditSupervisorForm = ref(false);
const showAddPorterForm = ref(false);
const showEditPorterForm = ref(false);
const hideContractedHours = ref(false);
const showAbsenceModal = ref(false);
const currentPorterAbsence = ref(null);
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

// Computed property for filtered porters with shift time filtering
const filteredPorters = computed(() => {
  let porters = staffStore.sortedPorters;
  
  // Apply shift time filter if not set to 'all'
  if (staffStore.shiftTimeFilter !== 'all' && settingsStore.shiftDefaults) {
    porters = porters.filter(porter => {
      const shiftType = staffStore.getPorterShiftType(porter, settingsStore.shiftDefaults);
      return shiftType === staffStore.shiftTimeFilter;
    });
  }
  
  return porters;
});

// Initialize data
onMounted(async () => {
  await staffStore.initialize();
  await areaCoverStore.initialize();
  await supportServicesStore.initialize();
  await settingsStore.loadSettings();
});

// Helper function to safely format time
const formatTime = (timeValue) => {
  if (!timeValue) return '00:00';
  
  // If it's already a string in HH:MM format, return as is
  if (typeof timeValue === 'string' && timeValue.includes(':') && timeValue.length === 5) {
    return timeValue;
  }
  
  // If it's a longer string, extract first 5 characters
  if (typeof timeValue === 'string' && timeValue.includes(':')) {
    return timeValue.substring(0, 5);
  }
  
  // If it's a Date object, format it
  if (timeValue instanceof Date) {
    return timeValue.toTimeString().substring(0, 5);
  }
  
  // If it's a timestamp or other format, try to convert
  try {
    const date = new Date(timeValue);
    if (!isNaN(date.getTime())) {
      return date.toTimeString().substring(0, 5);
    }
  } catch (error) {
    console.warn('Invalid time format:', timeValue);
  }
  
  // Fallback to default time
  return '00:00';
};

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
          startTime: formatTime(pa.start_time),
          endTime: formatTime(pa.end_time)
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
          startTime: formatTime(pa.start_time),
          endTime: formatTime(pa.end_time)
        });
      }
    }
  }
  
  return assignments;
};

// Get all assignments (area and service) for a porter with deduplication
const getPorterAssignments = (porterId) => {
  const areaAssignments = getPorterAreaAssignments(porterId);
  const serviceAssignments = getPorterServiceAssignments(porterId);
  
  const allAssignments = [...areaAssignments, ...serviceAssignments];
  
  // Deduplicate assignments based on name, pattern, and times
  const uniqueAssignments = [];
  const seen = new Set();
  
  for (const assignment of allAssignments) {
    const key = `${assignment.name}-${assignment.pattern}-${assignment.startTime}-${assignment.endTime}`;
    if (!seen.has(key)) {
      seen.add(key);
      uniqueAssignments.push(assignment);
    }
  }
  
  return uniqueAssignments;
};

// Get porter shift type for styling
const getPorterShiftType = (porter) => {
  if (settingsStore.shiftDefaults) {
    return staffStore.getPorterShiftType(porter, settingsStore.shiftDefaults);
  }
  return 'unknown';
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

const editPorter = async (porter) => {
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

  // Load porter absences
  if (porter.id) {
    await staffStore.fetchPorterAbsencesById(porter.id);
  }
};

const closeStaffForm = () => {
  showAddSupervisorForm.value = false;
  showEditSupervisorForm.value = false;
  showAddPorterForm.value = false;
  showEditPorterForm.value = false;
  hideContractedHours.value = false;
  showAbsenceModal.value = false;
  currentPorterAbsence.value = null;
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

// Computed property for current porter's absences
const porterAbsences = computed(() => {
  if (!staffForm.value.id) return [];
  return staffStore.porterAbsences.filter(absence => absence.porter_id === staffForm.value.id);
});

// Format date for display
const formatDate = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString();
};

// Open absence modal
const openAbsenceModal = (absence = null) => {
  currentPorterAbsence.value = absence;
  showAbsenceModal.value = true;
};

// Close absence modal
const closeAbsenceModal = () => {
  showAbsenceModal.value = false;
  currentPorterAbsence.value = null;
};

// Handle absence save
const handleAbsenceSave = async (savedAbsence) => {
  // Refresh porter absences
  if (staffForm.value.id) {
    await staffStore.fetchPorterAbsencesById(staffForm.value.id);
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

<!-- Styles are now handled by the global CSS layers -->


