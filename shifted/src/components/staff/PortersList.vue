<template>
  <div class="porters-list">
    <div class="list-header">
      <div class="header-info">
        <h4>Porters</h4>
      </div>
      <BaseButton variant="primary" size="sm" @click="showAddPorterForm = true">
        <PlusIcon class="w-4 h-4" />
        Add Porter
      </BaseButton>
    </div>

    <div class="filter-controls">
      <div class="sort-controls">
        <span>Sort by:</span>
        <button
          class="sort-btn"
          :class="{ 'sort-btn--active': staffStore.filters.sortBy === 'firstName' }"
          @click="staffStore.setSortBy('firstName')"
        >
          First Name
        </button>
        <button
          class="sort-btn"
          :class="{ 'sort-btn--active': staffStore.filters.sortBy === 'lastName' }"
          @click="staffStore.setSortBy('lastName')"
        >
          Last Name
        </button>
      </div>

      <div class="porter-type-filters">
        <span>Type:</span>
        <button
          class="filter-btn"
          :class="{ 'filter-btn--active': staffStore.filters.porterTypeFilter === 'all' }"
          @click="staffStore.setPorterTypeFilter('all')"
        >
          All Porters
        </button>
        <button
          class="filter-btn"
          :class="{ 'filter-btn--active': staffStore.filters.porterTypeFilter === 'shift' }"
          @click="staffStore.setPorterTypeFilter('shift')"
        >
          Shift Porters
        </button>
        <button
          class="filter-btn"
          :class="{ 'filter-btn--active': staffStore.filters.porterTypeFilter === 'relief' }"
          @click="staffStore.setPorterTypeFilter('relief')"
        >
          Relief Porters
        </button>
      </div>

      <div class="shift-time-filters">
        <span>Shift:</span>
        <button
          class="filter-btn"
          :class="{ 'filter-btn--active': staffStore.filters.shiftTimeFilter === 'all' }"
          @click="staffStore.setShiftTimeFilter('all')"
        >
          All Shifts
        </button>
        <button
          class="filter-btn"
          :class="{ 'filter-btn--active': staffStore.filters.shiftTimeFilter === 'day' }"
          @click="staffStore.setShiftTimeFilter('day')"
        >
          <DayShiftIcon class="w-3.5 h-3.5" />
          Day Shift
        </button>
        <button
          class="filter-btn"
          :class="{ 'filter-btn--active': staffStore.filters.shiftTimeFilter === 'night' }"
          @click="staffStore.setShiftTimeFilter('night')"
        >
          <NightShiftIcon class="w-3.5 h-3.5" />
          Night Shift
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
              :class="{
                'porter-type-dot--shift': porter.porter_type === 'shift',
                'porter-type-dot--relief': porter.porter_type === 'relief'
              }"
            ></span>
            {{ porter.first_name }} {{ porter.last_name }}
            <span v-if="staffStore.getPorterAbsenceDetails(porter.id, new Date())?.absence_type === 'illness'"
                  class="absence-badge illness">ILL</span>
            <span v-if="staffStore.getPorterAbsenceDetails(porter.id, new Date())?.absence_type === 'annual_leave'"
                  class="absence-badge annual-leave">AL</span>
          </div>
          <div class="staff-item__department">
            {{ staffStore.formatAvailability(porter) }}
          </div>
        </div>

        <div class="staff-item__actions">
          <BaseButton
            variant="ghost"
            size="sm"
            @click="editPorter(porter)"
          >
            <EditIcon class="w-4 h-4" />
          </BaseButton>

          <BaseButton
            variant="ghost"
            size="sm"
            @click="deletePorter(porter)"
          >
            <TrashIcon class="w-4 h-4" />
          </BaseButton>
        </div>
      </div>
    </div>

    <!-- Add/Edit Porter Modal -->
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
          <form @submit.prevent="saveStaff" v-if="!showEditPorterForm || activeModalTab === 'details'">
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
              <BaseButton variant="secondary" @click="closeStaffForm">
                Cancel
              </BaseButton>
              <BaseButton variant="primary" type="submit" :disabled="staffStore.loading.staff">
                {{ staffStore.loading.staff ? 'Saving...' : 'Save' }}
              </BaseButton>
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
                <BaseButton
                  variant="danger"
                  @click="confirmDeleteAbsence"
                >
                  Delete Absence
                </BaseButton>
              </div>

              <div class="form-actions">
                <BaseButton variant="secondary" @click="closeStaffForm">
                  Cancel
                </BaseButton>
                <BaseButton
                  variant="primary"
                  type="submit"
                  :disabled="!!absenceForm.absence_type && (!absenceForm.start_date || !absenceForm.end_date)"
                >
                  {{ staffStore.loading.staff ? 'Saving...' : 'Save' }}
                </BaseButton>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useStaffStore } from '../../stores/staffStore'
import { useSettingsStore } from '../../stores/settingsStore'
import BaseButton from '../ui/BaseButton.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import EditIcon from '../icons/EditIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'
import DayShiftIcon from '../icons/DayShiftIcon.vue'
import NightShiftIcon from '../icons/NightShiftIcon.vue'
import type { Staff, PorterAbsence } from '../../types/staff'

const staffStore = useStaffStore()
const settingsStore = useSettingsStore()

// Local state
const searchQuery = ref('')
const showAddPorterForm = ref(false)
const showEditPorterForm = ref(false)
const hideContractedHours = ref(false)
const activeModalTab = ref('details')

// Form state
const staffForm = ref({
  id: null as string | null,
  firstName: '',
  lastName: '',
  porterType: 'shift' as 'shift' | 'relief',
  isRelief: false,
  availabilityPattern: '',
  contractedHoursStart: '09:00',
  contractedHoursEnd: '17:00'
})

// Absence form state
const absenceForm = ref({
  porter_id: '' as string,
  absence_type: '' as 'illness' | 'annual_leave' | '',
  start_date: '',
  end_date: '',
  notes: ''
})
const currentAbsence = ref<PorterAbsence | null>(null)

// Computed properties
const today = computed(() => {
  const today = new Date()
  return today.toISOString().split('T')[0]
})

const hasExistingAbsence = computed(() => {
  if (!absenceForm.value.start_date || !absenceForm.value.end_date || !absenceForm.value.porter_id) {
    return false
  }

  const startDate = new Date(absenceForm.value.start_date)
  const endDate = new Date(absenceForm.value.end_date)

  return staffStore.porterAbsences.some(absence => {
    if (currentAbsence.value && absence.id === currentAbsence.value.id) {
      return false
    }

    const absStart = new Date(absence.start_date)
    const absEnd = new Date(absence.end_date)

    return absence.porter_id === absenceForm.value.porter_id && (
      (startDate <= absEnd && endDate >= absStart)
    )
  })
})

const filteredPorters = computed(() => {
  let porters = staffStore.sortedPorters

  if (staffStore.filters.shiftTimeFilter !== 'all' && settingsStore.shiftDefaults) {
    porters = porters.filter(porter => {
      const shiftType = staffStore.getPorterShiftType(porter, settingsStore.shiftDefaults)
      return shiftType === staffStore.filters.shiftTimeFilter
    })
  }

  return porters
})

// Methods
const getPorterShiftType = (porter: Staff) => {
  if (settingsStore.shiftDefaults) {
    return staffStore.getPorterShiftType(porter, settingsStore.shiftDefaults)
  }
  return 'unknown'
}

const editPorter = (porter: Staff) => {
  staffForm.value = {
    id: porter.id,
    firstName: porter.first_name,
    lastName: porter.last_name,
    porterType: porter.porter_type || 'shift',
    isRelief: porter.porter_type === 'relief',
    availabilityPattern: porter.availability_pattern || '',
    contractedHoursStart: porter.contracted_hours_start ? porter.contracted_hours_start.substring(0, 5) : '09:00',
    contractedHoursEnd: porter.contracted_hours_end ? porter.contracted_hours_end.substring(0, 5) : '17:00'
  }
  showEditPorterForm.value = true
  activeModalTab.value = 'details'
  checkHideContractedHours()

  if (porter.id) {
    absenceForm.value = {
      porter_id: porter.id,
      absence_type: '',
      start_date: '',
      end_date: '',
      notes: ''
    }

    const today = new Date()
    currentAbsence.value = staffStore.getPorterAbsenceDetails(porter.id, today)

    if (currentAbsence.value) {
      absenceForm.value.absence_type = currentAbsence.value.absence_type
      absenceForm.value.start_date = currentAbsence.value.start_date ? new Date(currentAbsence.value.start_date).toISOString().split('T')[0] : ''
      absenceForm.value.end_date = currentAbsence.value.end_date ? new Date(currentAbsence.value.end_date).toISOString().split('T')[0] : ''
      absenceForm.value.notes = currentAbsence.value.notes || ''
    }
  }
}

const deletePorter = async (porter: Staff) => {
  if (confirm(`Are you sure you want to delete ${porter.first_name} ${porter.last_name}?`)) {
    await staffStore.deleteStaffMember(porter.id)
  }
}

const closeStaffForm = () => {
  showAddPorterForm.value = false
  showEditPorterForm.value = false
  hideContractedHours.value = false
  staffForm.value = {
    id: null,
    firstName: '',
    lastName: '',
    porterType: 'shift',
    isRelief: false,
    availabilityPattern: '',
    contractedHoursStart: '09:00',
    contractedHoursEnd: '17:00'
  }
}

const updatePorterType = () => {
  staffForm.value.porterType = staffForm.value.isRelief ? 'relief' : 'shift'
}

const checkHideContractedHours = () => {
  const pattern = staffForm.value.availabilityPattern
  hideContractedHours.value = pattern.includes('Days and Nights')

  if (hideContractedHours.value) {
    staffForm.value.contractedHoursStart = '00:00'
    staffForm.value.contractedHoursEnd = '23:59'
  }
}

const saveStaff = async () => {
  const staffData = {
    first_name: staffForm.value.firstName.trim(),
    last_name: staffForm.value.lastName.trim(),
    role: 'porter' as const,
    porter_type: staffForm.value.porterType,
    availability_pattern: staffForm.value.availabilityPattern,
    contracted_hours_start: hideContractedHours.value ? '00:00' : staffForm.value.contractedHoursStart,
    contracted_hours_end: hideContractedHours.value ? '23:59' : staffForm.value.contractedHoursEnd,
    active: true
  }

  let success = false

  if (staffForm.value.id) {
    success = await staffStore.updateStaffMember(staffForm.value.id, staffData) !== null
  } else {
    success = await staffStore.createStaffMember(staffData) !== null
  }

  if (success) {
    closeStaffForm()
  }
}

const saveAbsence = async () => {
  if (!absenceForm.value.absence_type) {
    if (currentAbsence.value && currentAbsence.value.id) {
      await staffStore.deletePorterAbsence(currentAbsence.value.id)
      currentAbsence.value = null
    }
    closeStaffForm()
    return
  }

  if (!absenceForm.value.porter_id || !absenceForm.value.start_date || !absenceForm.value.end_date) {
    return
  }

  const absenceData = {
    porter_id: absenceForm.value.porter_id,
    absence_type: absenceForm.value.absence_type as 'illness' | 'annual_leave',
    start_date: absenceForm.value.start_date,
    end_date: absenceForm.value.end_date,
    notes: absenceForm.value.notes
  }

  try {
    if (currentAbsence.value && currentAbsence.value.id) {
      await staffStore.updatePorterAbsence(currentAbsence.value.id, absenceData)
    } else {
      await staffStore.addPorterAbsence(absenceData)
    }

    closeStaffForm()
  } catch (error) {
    console.error('Error saving porter absence:', error)
  }
}

const confirmDeleteAbsence = async () => {
  if (!currentAbsence.value || !currentAbsence.value.id) return

  if (confirm('Are you sure you want to delete this absence record?')) {
    try {
      await staffStore.deletePorterAbsence(currentAbsence.value.id)
      closeStaffForm()
    } catch (error) {
      console.error('Error deleting porter absence:', error)
    }
  }
}

const onSearchInput = () => {
  staffStore.setSearchQuery(searchQuery.value)
}

const clearSearch = () => {
  searchQuery.value = ''
  staffStore.setSearchQuery('')
}

// Initialize
onMounted(async () => {
  await staffStore.initialize()
  await settingsStore.loadSettings()
})
</script>

<style scoped>
.porters-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.list-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: var(--spacing);
  flex-wrap: wrap;
}

.header-info h4 {
  font-size: 1.125rem;
  font-weight: 600;
  margin-bottom: var(--spacing-xs);
  color: var(--color-text);
}

.filter-controls {
  margin-bottom: var(--spacing-lg);
}

.sort-controls, .porter-type-filters, .shift-time-filters {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing-lg);
  flex-wrap: wrap;
}

.sort-controls span, .porter-type-filters span, .shift-time-filters span {
  font-size: 0.875rem;
  color: var(--color-text-light);
  font-weight: 500;
}

.sort-btn, .filter-btn {
  background: none;
  border: none;
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius);
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
}

.sort-btn:hover, .filter-btn:hover {
  background-color: var(--color-background-alt);
}

.sort-btn--active, .filter-btn--active {
  background-color: var(--color-primary-light);
  color: var(--color-primary);
  font-weight: 600;
}

.search-container {
  margin-bottom: var(--spacing-lg);
}

.search-field {
  position: relative;
  display: flex;
  align-items: center;
}

.search-icon {
  position: absolute;
  left: var(--spacing);
  font-size: 0.875rem;
  color: var(--color-text-light);
}

.search-input {
  width: 100%;
  padding: var(--spacing-sm) var(--spacing) var(--spacing-sm) calc(var(--spacing) * 2.5);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  font-size: 0.875rem;
}

.search-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-light);
}

.clear-search-btn {
  position: absolute;
  right: var(--spacing);
  background: none;
  border: none;
  font-size: 1.125rem;
  color: var(--color-text-light);
  cursor: pointer;
  padding: 0;
  line-height: 1;
}

.clear-search-btn:hover {
  color: var(--color-text);
}

.loading, .empty-state {
  padding: var(--spacing-2xl);
  text-align: center;
  color: var(--color-text-light);
}

.staff-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}

.staff-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing);
  border-radius: var(--radius);
  background-color: var(--color-background-alt);
  transition: all 0.2s ease;
}

.staff-item--day-shift {
  background-color: rgba(59, 130, 246, 0.08);
  border-left: 3px solid #3b82f6;
}

.staff-item--night-shift {
  background-color: rgba(139, 92, 246, 0.08);
  border-left: 3px solid #8b5cf6;
}

.staff-item__content {
  display: flex;
  flex-direction: column;
}

.staff-item__name {
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  padding: var(--spacing-xs);
  border-radius: var(--radius-sm);
}

.staff-item__name.porter-absent {
  opacity: 0.9;
}

.staff-item__name.porter-illness {
  color: #dc2626;
  background-color: rgba(220, 38, 38, 0.1);
}

.staff-item__name.porter-annual-leave {
  color: #ea580c;
  background-color: rgba(234, 88, 12, 0.1);
}

.absence-badge {
  display: inline-block;
  font-size: 0.625rem;
  font-weight: 700;
  padding: 2px 4px;
  border-radius: 3px;
  margin-left: var(--spacing-xs);
}

.absence-badge.illness {
  background-color: #dc2626;
  color: white;
}

.absence-badge.annual-leave {
  background-color: #ea580c;
  color: white;
}

.porter-type-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}

.porter-type-dot--shift {
  background-color: #3b82f6;
}

.porter-type-dot--relief {
  background-color: #f59e0b;
}

.staff-item__department {
  font-size: 0.875rem;
  color: var(--color-text-light);
}

.staff-item__actions {
  display: flex;
  gap: var(--spacing-xs);
}

/* Modal styles */
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
  background-color: var(--color-background);
  border-radius: var(--radius-lg);
  width: 90%;
  max-width: 500px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.modal-header {
  padding: var(--spacing-lg);
  border-bottom: 1px solid var(--color-border);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 600;
}

.modal-close {
  background: transparent;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  padding: 0;
  line-height: 1;
}

.modal-tabs {
  display: flex;
  border-bottom: 1px solid var(--color-border);
}

.modal-tab {
  padding: var(--spacing) var(--spacing-lg);
  background: none;
  border: none;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.modal-tab:hover {
  background-color: var(--color-background-alt);
}

.modal-tab--active {
  color: var(--color-primary);
  box-shadow: inset 0 -2px 0 var(--color-primary);
}

.modal-body {
  padding: var(--spacing-lg);
  overflow-y: auto;
  flex: 1;
}

.form-row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing);
  margin-bottom: var(--spacing);
}

.form-row.time-row {
  align-items: center;
}

.time-separator {
  margin-top: -8px;
  color: var(--color-text-light);
  font-weight: 500;
}

.form-group {
  margin-bottom: var(--spacing);
}

.form-group--half {
  flex: 1;
  min-width: 120px;
}

.form-group label {
  display: block;
  margin-bottom: var(--spacing-xs);
  font-weight: 500;
}

.form-control {
  width: 100%;
  padding: var(--spacing-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  font-size: 0.875rem;
}

.form-control:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-light);
}

.checkbox-container {
  display: flex;
  align-items: center;
  margin-top: var(--spacing-xs);
}

.checkbox-container input[type="checkbox"] {
  margin-right: var(--spacing-sm);
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.checkbox-container label {
  display: inline;
  margin-bottom: 0;
  cursor: pointer;
}

.availability-info {
  background-color: var(--color-primary-light);
  padding: var(--spacing);
  border-radius: var(--radius);
  font-size: 0.875rem;
  color: var(--color-text);
  margin-bottom: var(--spacing-sm);
  border-left: 3px solid var(--color-primary);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--spacing);
  margin-top: var(--spacing-lg);
}

.absence-form .form-control.textarea {
  resize: vertical;
  min-height: 80px;
}

.existing-absence-warning {
  margin-top: var(--spacing);
  padding: var(--spacing);
  background-color: rgba(245, 158, 11, 0.1);
  border-left: 3px solid #f59e0b;
  border-radius: var(--radius);
  font-size: 0.875rem;
}

.existing-absence-warning p {
  margin: 0;
  color: var(--color-text);
}

.loading-state {
  padding: var(--spacing-xl);
  text-align: center;
  color: var(--color-text-light);
}
</style>
