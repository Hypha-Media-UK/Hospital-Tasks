<template>
  <div class="create-shift-tab">
    <div class="tab-header">
      <h2 class="text-lg font-semibold">Create New Shift</h2>
    </div>

    <div class="create-shift-form">
      <div class="form-steps">
        <div class="step" :class="{ active: currentStep === 1, completed: currentStep > 1 }">
          <div class="step-number">1</div>
          <span class="step-label">Date & Type</span>
        </div>
        <div class="step" :class="{ active: currentStep === 2, completed: currentStep > 2 }">
          <div class="step-number">2</div>
          <span class="step-label">Supervisor</span>
        </div>
        <div class="step" :class="{ active: currentStep === 3 }">
          <div class="step-number">3</div>
          <span class="step-label">Review</span>
        </div>
      </div>

      <!-- Step 1: Date and Shift Type Selection -->
      <div v-if="currentStep === 1" class="form-step">
        <div class="step-content">
          <h3 class="step-title">Select Date and Shift Type</h3>

          <div class="form-group">
            <label class="form-label">Date</label>
            <input
              v-model="selectedDate"
              type="date"
              class="form-input"
              :min="today"
            />
          </div>

          <div class="form-group" v-if="selectedDate">
            <label class="form-label">Shift Type</label>
            <div class="shift-type-grid">
              <button
                v-for="shiftType in availableShiftTypes"
                :key="shiftType.id"
                :class="['shift-type-btn', { selected: selectedShiftType === shiftType.id }]"
                @click="selectedShiftType = shiftType.id"
              >
                <div class="shift-type-icon">
                  <component :is="shiftType.icon" :size="24" />
                </div>
                <div class="shift-type-info">
                  <div class="shift-type-name">{{ shiftType.name }}</div>
                  <div class="shift-type-time">{{ shiftType.time }}</div>
                </div>
              </button>
            </div>
          </div>
        </div>

        <div class="form-actions">
          <button
            class="btn btn-primary"
            :disabled="!selectedDate || !selectedShiftType"
            @click="nextStep"
          >
            Next
          </button>
        </div>
      </div>

      <!-- Step 2: Supervisor Selection -->
      <div v-if="currentStep === 2" class="form-step">
        <div class="step-content">
          <h3 class="step-title">Select Supervisor</h3>

          <div class="form-group">
            <label class="form-label">Search Supervisors</label>
            <input
              v-model="supervisorSearch"
              type="text"
              class="form-input"
              placeholder="Type to search supervisors..."
            />
          </div>

          <div class="supervisors-list">
            <div
              v-for="supervisor in filteredSupervisors"
              :key="supervisor.id"
              :class="['supervisor-item', { selected: selectedSupervisor === supervisor.id }]"
              @click="selectedSupervisor = supervisor.id"
            >
              <div class="supervisor-avatar">
                {{ getInitials(supervisor.first_name, supervisor.last_name) }}
              </div>
              <div class="supervisor-info">
                <div class="supervisor-name">
                  {{ supervisor.first_name }} {{ supervisor.last_name }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="form-actions">
          <button class="btn btn-secondary" @click="previousStep">
            Back
          </button>
          <button
            class="btn btn-primary"
            :disabled="!selectedSupervisor"
            @click="nextStep"
          >
            Next
          </button>
        </div>
      </div>

      <!-- Step 3: Review and Create -->
      <div v-if="currentStep === 3" class="form-step">
        <div class="step-content">
          <h3 class="step-title">Review Shift Details</h3>

          <div class="review-card">
            <div class="review-item">
              <span class="review-label">Date:</span>
              <span class="review-value">{{ formatDate(selectedDate) }}</span>
            </div>
            <div class="review-item">
              <span class="review-label">Shift Type:</span>
              <span class="review-value">{{ getShiftTypeName(selectedShiftType) }}</span>
            </div>
            <div class="review-item">
              <span class="review-label">Supervisor:</span>
              <span class="review-value">{{ getSupervisorName(selectedSupervisor) }}</span>
            </div>
          </div>

          <div v-if="error" class="error-message">
            {{ error }}
          </div>
        </div>

        <div class="form-actions">
          <button class="btn btn-secondary" @click="previousStep">
            Back
          </button>
          <button
            class="btn btn-primary"
            :disabled="creating"
            @click="createShift"
          >
            <span v-if="creating" class="loading-spinner"></span>
            {{ creating ? 'Creating...' : 'Create Shift' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useShiftsStore } from '../../stores/shiftsStore.ts'
import { useStaffStore } from '../../stores/staffStore.ts'
import DayShiftIcon from '../icons/DayShiftIcon.vue'
import NightShiftIcon from '../icons/NightShiftIcon.vue'

const router = useRouter()
const shiftsStore = useShiftsStore()
const staffStore = useStaffStore()

const currentStep = ref(1)
const selectedDate = ref('')
const selectedShiftType = ref('')
const selectedSupervisor = ref('')
const supervisorSearch = ref('')
const creating = ref(false)
const error = ref('')

const today = computed(() => new Date().toISOString().split('T')[0])

const isWeekend = computed(() => {
  if (!selectedDate.value) return false
  const date = new Date(selectedDate.value)
  const day = date.getDay()
  return day === 0 || day === 6
})

const availableShiftTypes = computed(() => {
  const prefix = isWeekend.value ? 'weekend_' : 'week_'
  return [
    {
      id: `${prefix}day`,
      name: isWeekend.value ? 'Weekend Day Shift' : 'Weekday Day Shift',
      time: '08:00 - 20:00',
      icon: DayShiftIcon
    },
    {
      id: `${prefix}night`,
      name: isWeekend.value ? 'Weekend Night Shift' : 'Weekday Night Shift',
      time: '20:00 - 08:00',
      icon: NightShiftIcon
    }
  ]
})

const supervisors = computed(() => staffStore.supervisors || [])

const filteredSupervisors = computed(() => {
  if (!supervisorSearch.value) return supervisors.value

  const search = supervisorSearch.value.toLowerCase()
  return supervisors.value.filter(supervisor => {
    const fullName = `${supervisor.first_name} ${supervisor.last_name}`.toLowerCase()
    return fullName.includes(search)
  })
})

const getInitials = (firstName, lastName) => {
  return (firstName?.charAt(0) || '') + (lastName?.charAt(0) || '')
}

const formatDate = (dateString) => {
  if (!dateString) return ''
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

const getShiftTypeName = (shiftTypeId) => {
  const shiftType = availableShiftTypes.value.find(st => st.id === shiftTypeId)
  return shiftType?.name || ''
}

const getSupervisorName = (supervisorId) => {
  const supervisor = supervisors.value.find(s => s.id === supervisorId)
  return supervisor ? `${supervisor.first_name} ${supervisor.last_name}` : ''
}

const nextStep = () => {
  if (currentStep.value < 3) {
    currentStep.value++
  }
}

const previousStep = () => {
  if (currentStep.value > 1) {
    currentStep.value--
  }
}

const createShift = async () => {
  creating.value = true
  error.value = ''

  try {
    const shiftData = {
      supervisor_id: selectedSupervisor.value,
      shift_type: selectedShiftType.value,
      start_time: new Date(selectedDate.value).toISOString()
    }

    const newShift = await shiftsStore.createShift(shiftData)

    if (newShift) {
      router.push(`/shift-management/${newShift.id}`)
    } else {
      error.value = 'Failed to create shift'
    }
  } catch (err) {
    console.error('Error creating shift:', err)
    error.value = 'An unexpected error occurred'
  } finally {
    creating.value = false
  }
}

onMounted(async () => {
  // Set default date to today
  selectedDate.value = today.value

  // Load supervisors
  try {
    await staffStore.fetchSupervisors()
  } catch (error) {
    console.error('Error loading supervisors:', error)
  }
})
</script>

<style scoped>
.create-shift-tab {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.tab-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.create-shift-form {
  max-width: 600px;
  margin: 0 auto;
  width: 100%;
}

.form-steps {
  display: flex;
  justify-content: center;
  align-items: center;
  margin-bottom: var(--spacing-2xl);
  position: relative;
}

.form-steps::before {
  content: '';
  position: absolute;
  top: 18px;
  left: 25%;
  right: 25%;
  height: 2px;
  background: var(--color-border);
  z-index: 1;
}

.step {
  display: flex;
  flex-direction: column;
  align-items: center;
  position: relative;
  z-index: 2;
  flex: 1;
}

.step-number {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: var(--color-background-alt);
  border: 2px solid var(--color-border);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  margin-bottom: var(--spacing-sm);
  transition: all 0.2s ease-in-out;
}

.step-label {
  font-size: 0.875rem;
  color: var(--color-text-light);
  font-weight: 500;
}

.step.active .step-number {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

.step.active .step-label {
  color: var(--color-primary);
  font-weight: 600;
}

.step.completed .step-number {
  background: var(--color-success);
  border-color: var(--color-success);
  color: white;
}

.step.completed .step-label {
  color: var(--color-success);
}

.form-step {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-xl);
}

.step-content {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.step-title {
  text-align: center;
  color: var(--color-text);
  margin-bottom: var(--spacing);
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}

.shift-type-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--spacing);
}

@container (min-width: 480px) {
  .shift-type-grid {
    grid-template-columns: 1fr 1fr;
  }
}

.shift-type-btn {
  display: flex;
  align-items: center;
  gap: var(--spacing);
  padding: var(--spacing-lg);
  border: 2px solid var(--color-border);
  border-radius: var(--radius);
  background: var(--color-background);
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}

.shift-type-btn:hover {
  border-color: var(--color-primary);
  background: var(--color-background-alt);
}

.shift-type-btn.selected {
  border-color: var(--color-primary);
  background: rgba(59, 130, 246, 0.1);
}

.shift-type-icon {
  color: var(--color-primary);
}

.shift-type-info {
  text-align: left;
}

.shift-type-name {
  font-weight: 600;
  margin-bottom: var(--spacing-xs);
}

.shift-type-time {
  font-size: 0.875rem;
  color: var(--color-text-light);
}

.supervisors-list {
  max-height: 300px;
  overflow-y: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
}

.supervisor-item {
  display: flex;
  align-items: center;
  gap: var(--spacing);
  padding: var(--spacing);
  border-bottom: 1px solid var(--color-border-light);
  cursor: pointer;
  transition: background-color 0.2s ease-in-out;
}

.supervisor-item:last-child {
  border-bottom: none;
}

.supervisor-item:hover {
  background: var(--color-background-alt);
}

.supervisor-item.selected {
  background: rgba(59, 130, 246, 0.1);
  border-color: var(--color-primary);
}

.supervisor-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--color-primary);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 0.875rem;
}

.supervisor-name {
  font-weight: 500;
}

.review-card {
  background: var(--color-background-alt);
  border-radius: var(--radius);
  padding: var(--spacing-lg);
  display: flex;
  flex-direction: column;
  gap: var(--spacing);
}

.review-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.review-label {
  font-weight: 500;
  color: var(--color-text-light);
}

.review-value {
  font-weight: 600;
  color: var(--color-text);
}

.form-actions {
  display: flex;
  justify-content: space-between;
  gap: var(--spacing);
}

.error-message {
  padding: var(--spacing);
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.3);
  border-radius: var(--radius);
  color: var(--color-danger);
  font-size: 0.875rem;
}

.loading-spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  border-top-color: white;
  animation: spin 1s ease-in-out infinite;
  margin-right: var(--spacing-xs);
}
</style>
