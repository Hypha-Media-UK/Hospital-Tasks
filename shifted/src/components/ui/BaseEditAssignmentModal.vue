<template>
  <div class="modal-overlay" @click.stop="closeModal">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">{{ modalTitle }}</h3>
        <button class="modal-close" @click.stop="closeModal">&times;</button>
      </div>

      <div class="modal-body">
        <!-- Entity-specific information slot -->
        <div v-if="$slots['entity-info']" class="entity-info-section">
          <slot name="entity-info" />
        </div>

        <!-- Time Range Editor -->
        <div class="time-settings">
          <div class="time-group">
            <label for="startTime">Start Time</label>
            <input
              type="time"
              id="startTime"
              v-model="localStartTime"
            />
          </div>

          <div class="time-group">
            <label for="endTime">End Time</label>
            <input
              type="time"
              id="endTime"
              v-model="localEndTime"
            />
          </div>
        </div>

        <!-- Minimum Porter Count by Day -->
        <div class="min-porters-setting">
          <label class="section-label">Minimum Porter Count by Day</label>

          <div class="day-toggle">
            <label class="toggle-label">
              <input type="checkbox" v-model="useSameForAllDays" @change="handleSameForAllDaysChange">
              <span class="toggle-text">Same for all days</span>
            </label>
          </div>

          <div v-if="useSameForAllDays" class="single-input-wrapper">
            <div class="min-porters-input">
              <input
                type="number"
                v-model="sameForAllDaysValue"
                min="0"
                class="number-input"
                @change="applySameValueToAllDays"
              />
              <div class="min-porters-description">
                Minimum number of porters required for all days
              </div>
            </div>
          </div>

          <div v-else class="days-grid">
            <div v-for="(day, index) in days" :key="day.code" class="day-input">
              <label :for="'min-porters-' + day.code">{{ day.code }}</label>
              <input
                type="number"
                :id="'min-porters-' + day.code"
                v-model="dayMinPorters[index]"
                min="0"
                class="number-input day-input"
              />
            </div>
          </div>
        </div>

        <!-- Porter assignments -->
        <div class="porter-assignments">
          <div class="section-title">
            Porters
            <span v-if="hasLocalCoverageGap" class="coverage-gap-indicator">
              Coverage Gap Detected
            </span>
          </div>

          <div v-if="localPorterAssignments.length === 0" class="empty-state">
            No porters assigned. Add a porter to provide coverage.
          </div>

          <div v-else class="porter-list">
            <div
              v-for="(porterAssignment, index) in localPorterAssignments"
              :key="porterAssignment.id || `new-${index}`"
              class="porter-assignment-item"
            >
              <div class="porter-pill">
                <span
                  class="porter-name"
                  :class="{
                    'porter-absent': getPorterAbsence(porterAssignment.porter_id),
                    'porter-illness': getPorterAbsence(porterAssignment.porter_id)?.absence_type === 'illness',
                    'porter-annual-leave': getPorterAbsence(porterAssignment.porter_id)?.absence_type === 'annual_leave'
                  }"
                  @click="handlePorterClick(porterAssignment.porter_id)"
                >
                  {{ porterAssignment.porter?.first_name }} {{ porterAssignment.porter?.last_name }}
                  <span v-if="getPorterAbsence(porterAssignment.porter_id)?.absence_type === 'illness'" class="absence-badge illness">ILL</span>
                  <span v-if="getPorterAbsence(porterAssignment.porter_id)?.absence_type === 'annual_leave'" class="absence-badge annual-leave">AL</span>
                </span>
              </div>

              <div class="porter-times">
                <div class="time-group">
                  <input
                    type="time"
                    v-model="porterAssignment.start_time_display"
                  />
                </div>
                <span class="time-separator">to</span>
                <div class="time-group">
                  <input
                    type="time"
                    v-model="porterAssignment.end_time_display"
                  />
                </div>
              </div>

              <button
                class="btn btn--icon"
                title="Remove porter assignment"
                @click.stop="removeLocalPorterAssignment(index)"
              >
                &times;
              </button>
            </div>
          </div>

          <div class="add-porter">
            <div v-if="!showAddPorter" class="add-porter-button">
              <button
                class="btn btn--primary"
                @click.stop="showAddPorter = true"
                :disabled="availablePorters.length === 0"
              >
                Add Porter
              </button>
              <p v-if="availablePorters.length === 0" class="no-porters-message">
                No available porters to assign
              </p>
            </div>

            <div v-else class="add-porter-form">
              <div class="form-row">
                <select v-model="newPorterAssignment.porter_id">
                  <option value="">-- Select Porter --</option>
                  <option
                    v-for="porter in availablePorters"
                    :key="porter.id"
                    :value="porter.id"
                  >
                    {{ porter.first_name }} {{ porter.last_name }}
                  </option>
                </select>

                <div class="time-group">
                  <input
                    type="time"
                    v-model="newPorterAssignment.start_time"
                    placeholder="Start Time"
                  />
                </div>

                <div class="time-group">
                  <input
                    type="time"
                    v-model="newPorterAssignment.end_time"
                    placeholder="End Time"
                  />
                </div>

                <div class="action-buttons">
                  <button
                    class="btn btn--small btn--primary"
                    @click.stop="addLocalPorterAssignment"
                    :disabled="!newPorterAssignment.porter_id || !newPorterAssignment.start_time || !newPorterAssignment.end_time"
                  >
                    Add
                  </button>
                  <button
                    class="btn btn--small btn--secondary"
                    @click.stop="cancelAddPorter"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Additional content slot -->
        <div v-if="$slots['additional-content']" class="additional-content-section">
          <slot name="additional-content" />
        </div>
      </div>

      <div class="modal-footer">
        <div class="footer-left">
          <button
            v-if="showDeleteButton"
            class="btn btn--danger"
            @click.stop="handleDelete"
          >
            {{ deleteButtonText }}
          </button>
        </div>

        <div class="footer-right">
          <button
            class="btn btn--secondary"
            @click.stop="closeModal"
          >
            Cancel
          </button>
          <button
            class="btn btn--primary"
            @click.stop="handleSave"
          >
            {{ saveButtonText }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useStaffStore } from '../../stores/staffStore'

interface PorterAssignment {
  id?: string
  porter_id: string
  start_time?: string
  end_time?: string
  start_time_display?: string
  end_time_display?: string
  porter?: any
  isNew?: boolean
}

interface AssignmentData {
  id?: string
  start_time?: string
  end_time?: string
  minimum_porters?: number
  minimum_porters_mon?: number
  minimum_porters_tue?: number
  minimum_porters_wed?: number
  minimum_porters_thu?: number
  minimum_porters_fri?: number
  minimum_porters_sat?: number
  minimum_porters_sun?: number
}

interface Props {
  modalTitle: string
  assignment: AssignmentData
  saveButtonText?: string
  deleteButtonText?: string
  showDeleteButton?: boolean
  getPorterAssignments: (assignmentId: string) => PorterAssignment[]
}

interface Emits {
  (e: 'close'): void
  (e: 'save', data: {
    timeRange: { start: string; end: string }
    dayRequirements: number[]
    porterAssignments: PorterAssignment[]
    removedPorterIds: string[]
  }): void
  (e: 'delete'): void
  (e: 'porter-clicked', porterId: string): void
}

const props = withDefaults(defineProps<Props>(), {
  saveButtonText: 'Update',
  deleteButtonText: 'Delete',
  showDeleteButton: false
})

const emit = defineEmits<Emits>()

const staffStore = useStaffStore()

// Local state
const localStartTime = ref('')
const localEndTime = ref('')
const localPorterAssignments = ref<PorterAssignment[]>([])
const showAddPorter = ref(false)
const removedPorterIds = ref<string[]>([])

// Day-specific minimum porter counts
const days = [
  { code: 'Mo', name: 'Monday', field: 'minimum_porters_mon' },
  { code: 'Tu', name: 'Tuesday', field: 'minimum_porters_tue' },
  { code: 'We', name: 'Wednesday', field: 'minimum_porters_wed' },
  { code: 'Th', name: 'Thursday', field: 'minimum_porters_thu' },
  { code: 'Fr', name: 'Friday', field: 'minimum_porters_fri' },
  { code: 'Sa', name: 'Saturday', field: 'minimum_porters_sat' },
  { code: 'Su', name: 'Sunday', field: 'minimum_porters_sun' }
]
const useSameForAllDays = ref(true)
const sameForAllDaysValue = ref(1)
const dayMinPorters = ref([1, 1, 1, 1, 1, 1, 1])

const newPorterAssignment = ref({
  porter_id: '',
  start_time: '',
  end_time: ''
})

// Handle "Same for all days" toggle change
const handleSameForAllDaysChange = () => {
  if (useSameForAllDays.value) {
    sameForAllDaysValue.value = dayMinPorters.value[0] || 1
    applySameValueToAllDays()
  }
}

// Apply the same value to all days
const applySameValueToAllDays = () => {
  if (useSameForAllDays.value) {
    dayMinPorters.value = Array(7).fill(parseInt(String(sameForAllDaysValue.value)) || 0)
  }
}

// Computed property for determining what porters are available
const availablePorters = computed(() => {
  // Get all porters from staff store
  const allPorters = staffStore.porters || []

  // Filter out porters that are already in our local assignments
  const assignedPorterIds = localPorterAssignments.value.map(pa => pa.porter_id)

  // Filter out absent porters
  const today = new Date()
  return allPorters.filter(porter => {
    if (assignedPorterIds.includes(porter.id)) return false
    if (staffStore.isPorterAbsent(porter.id, today)) return false
    return true
  })
})

// Get porter absence details
const getPorterAbsence = (porterId: string) => {
  try {
    const today = new Date()
    return staffStore.getPorterAbsenceDetails(porterId, today)
  } catch (error) {
    console.error('Error getting porter absence:', error)
    return null
  }
}

// Check for coverage gaps with local data
const hasLocalCoverageGap = computed(() => {
  if (localPorterAssignments.value.length === 0) return true

  // Convert assignment times to minutes for easier comparison
  const assignmentStart = timeToMinutes(localStartTime.value + ':00')
  const assignmentEnd = timeToMinutes(localEndTime.value + ':00')

  // First check if any single porter covers the entire time period
  const fullCoverageExists = localPorterAssignments.value.some(assignment => {
    const porterStart = timeToMinutes(assignment.start_time_display + ':00')
    const porterEnd = timeToMinutes(assignment.end_time_display + ':00')
    return porterStart <= assignmentStart && porterEnd >= assignmentEnd
  })

  // If at least one porter provides full coverage, there's no gap
  if (fullCoverageExists) {
    return false
  }

  // Sort porter assignments by start time
  const sortedAssignments = [...localPorterAssignments.value].sort((a, b) => {
    return timeToMinutes(a.start_time_display + ':00') - timeToMinutes(b.start_time_display + ':00')
  })

  // Check for gap at the beginning
  if (timeToMinutes(sortedAssignments[0].start_time_display + ':00') > assignmentStart) {
    return true
  }

  // Check for gaps between porter assignments
  for (let i = 0; i < sortedAssignments.length - 1; i++) {
    const currentEnd = timeToMinutes(sortedAssignments[i].end_time_display + ':00')
    const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time_display + ':00')

    if (nextStart > currentEnd) {
      return true
    }
  }

  // Check for gap at the end
  const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time_display + ':00')
  if (lastEnd < assignmentEnd) {
    return true
  }

  return false
})

// Methods
const closeModal = () => {
  emit('close')
}

const handlePorterClick = (porterId: string) => {
  emit('porter-clicked', porterId)
}

const addLocalPorterAssignment = () => {
  if (!newPorterAssignment.value.porter_id ||
      !newPorterAssignment.value.start_time ||
      !newPorterAssignment.value.end_time) {
    return
  }

  // Find the porter in the list
  const porter = staffStore.porters.find(p => p.id === newPorterAssignment.value.porter_id)

  if (porter) {
    // Add to local state with a temporary ID
    localPorterAssignments.value.push({
      id: `temp-${Date.now()}`,
      porter_id: newPorterAssignment.value.porter_id,
      start_time: newPorterAssignment.value.start_time + ':00',
      end_time: newPorterAssignment.value.end_time + ':00',
      start_time_display: newPorterAssignment.value.start_time,
      end_time_display: newPorterAssignment.value.end_time,
      porter: porter,
      isNew: true
    })
  }

  // Reset form
  newPorterAssignment.value = {
    porter_id: '',
    start_time: '',
    end_time: ''
  }

  showAddPorter.value = false
}

const removeLocalPorterAssignment = (index: number) => {
  const assignment = localPorterAssignments.value[index]

  // If it's an existing assignment (has a real DB ID), track it for deletion
  if (assignment.id && !assignment.isNew) {
    removedPorterIds.value.push(assignment.id)
  }

  // Remove from local array
  localPorterAssignments.value.splice(index, 1)
}

const cancelAddPorter = () => {
  newPorterAssignment.value = {
    porter_id: '',
    start_time: '',
    end_time: ''
  }
  showAddPorter.value = false
}

const handleSave = () => {
  emit('save', {
    timeRange: {
      start: localStartTime.value + ':00',
      end: localEndTime.value + ':00'
    },
    dayRequirements: dayMinPorters.value,
    porterAssignments: localPorterAssignments.value,
    removedPorterIds: removedPorterIds.value
  })
}

const handleDelete = () => {
  emit('delete')
}

// Initialize component state from props
const initializeState = () => {
  console.log('🔧 Initializing BaseEditAssignmentModal state...')
  console.log('Assignment:', props.assignment)

  // Initialize times
  if (props.assignment.start_time) {
    localStartTime.value = props.assignment.start_time.slice(0, 5)
  } else {
    localStartTime.value = '08:00'
  }

  if (props.assignment.end_time) {
    localEndTime.value = props.assignment.end_time.slice(0, 5)
  } else {
    localEndTime.value = '16:00'
  }

  // Initialize minimum porter count
  sameForAllDaysValue.value = props.assignment.minimum_porters || 1

  // Initialize day-specific minimum porter counts
  const hasAnyDaySpecificValues =
    props.assignment.minimum_porters_mon !== undefined ||
    props.assignment.minimum_porters_tue !== undefined ||
    props.assignment.minimum_porters_wed !== undefined ||
    props.assignment.minimum_porters_thu !== undefined ||
    props.assignment.minimum_porters_fri !== undefined ||
    props.assignment.minimum_porters_sat !== undefined ||
    props.assignment.minimum_porters_sun !== undefined

  if (hasAnyDaySpecificValues) {
    dayMinPorters.value = days.map(day =>
      (props.assignment as any)[day.field] !== undefined ? (props.assignment as any)[day.field] : props.assignment.minimum_porters || 1
    )

    // Check if all days have the same value
    const allSameValue = dayMinPorters.value.every(val => val === dayMinPorters.value[0])
    useSameForAllDays.value = allSameValue
    if (allSameValue) {
      sameForAllDaysValue.value = dayMinPorters.value[0]
    }
  } else {
    // Default to same value for all days if no day-specific values exist
    useSameForAllDays.value = true
    const defaultValue = props.assignment.minimum_porters || 1
    sameForAllDaysValue.value = defaultValue
    dayMinPorters.value = Array(7).fill(defaultValue)
  }

  // Initialize porter assignments
  const assignments = props.getPorterAssignments(props.assignment.id!)
  console.log('Porter assignments from prop function:', assignments)

  localPorterAssignments.value = assignments.map((pa: any) => ({
    ...pa,
    start_time_display: pa.start_time ? pa.start_time.slice(0, 5) : '',
    end_time_display: pa.end_time ? pa.end_time.slice(0, 5) : ''
  }))

  console.log('Local porter assignments:', localPorterAssignments.value)

  // Clear the removed porters list
  removedPorterIds.value = []
}

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr: string): number {
  if (!timeStr) return 0

  const [hours, minutes] = timeStr.split(':').map(Number)
  return (hours * 60) + minutes
}

// Fetch porters if not already loaded and initialize state
onMounted(async () => {
  console.log('🚀 BaseEditAssignmentModal mounted')

  if (!staffStore.porters || staffStore.porters.length === 0) {
    console.log('📥 Fetching porters...')
    await staffStore.fetchPorters()
  }

  initializeState()
})
</script>

<style scoped>
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
  background-color: white;
  border-radius: 12px;
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
  font-size: 1.25rem;
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
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.footer-left {
  display: flex;
}

.footer-right {
  display: flex;
  gap: 12px;
}

/* Entity info section */
.entity-info-section,
.additional-content-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

/* Section title */
.section-title {
  font-weight: 600;
  font-size: 1rem;
  margin-bottom: 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* Time settings */
.time-settings {
  display: flex;
  gap: 16px;
}

.time-group {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.time-group label {
  font-size: 0.875rem;
  font-weight: 500;
  color: rgba(0, 0, 0, 0.7);
}

.time-group input[type="time"] {
  padding: 8px;
  border: 1px solid rgba(0, 0, 0, 0.2);
  border-radius: 6px;
  font-size: 1rem;
}

.time-group input[type="time"]:focus {
  outline: none;
  border-color: #4285f4;
  box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
}

/* Minimum porter settings */
.min-porters-setting {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.section-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: rgba(0, 0, 0, 0.7);
}

.day-toggle {
  margin-bottom: 4px;
}

.toggle-label {
  display: flex;
  align-items: center;
  cursor: pointer;
}

.toggle-text {
  margin-left: 8px;
  font-size: 0.875rem;
}

.min-porters-input {
  display: flex;
  align-items: center;
  gap: 12px;
}

.number-input {
  width: 60px;
  padding: 8px;
  border: 1px solid rgba(0, 0, 0, 0.2);
  border-radius: 6px;
  font-size: 1rem;
  text-align: center;
}

.number-input:focus {
  outline: none;
  border-color: #4285f4;
  box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
}

.min-porters-description {
  font-size: 0.875rem;
  color: rgba(0, 0, 0, 0.6);
}

.days-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 8px;
}

@media (max-width: 600px) {
  .days-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

@media (max-width: 400px) {
  .days-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

.day-input {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.day-input label {
  font-weight: 500;
  margin-bottom: 4px;
  font-size: 0.875rem;
}

.day-input input {
  width: 100%;
  padding: 6px 4px;
  text-align: center;
  border: 1px solid rgba(0, 0, 0, 0.2);
  border-radius: 6px;
  font-size: 1rem;
}

/* Porter assignments */
.porter-assignments {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.empty-state {
  padding: 12px;
  text-align: center;
  color: rgba(0, 0, 0, 0.6);
  background-color: rgba(0, 0, 0, 0.03);
  border-radius: 8px;
}

.porter-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.porter-assignment-item {
  display: flex;
  align-items: center;
  padding: 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 8px;
  background-color: white;
}

.porter-pill {
  min-width: 140px;
  margin-right: auto;
}

.porter-name {
  display: inline-block;
  background-color: rgba(66, 133, 244, 0.1);
  color: #4285f4;
  border-radius: 16px;
  padding: 4px 12px;
  font-size: 0.875rem;
  font-weight: 500;
  white-space: nowrap;
  cursor: pointer;
  position: relative;
}

.porter-name.porter-absent {
  opacity: 0.9;
}

.porter-name.porter-illness {
  background-color: rgba(234, 67, 53, 0.15);
  color: #d32f2f;
}

.porter-name.porter-annual-leave {
  background-color: rgba(251, 192, 45, 0.2);
  color: #f57c00;
}

.absence-badge {
  display: inline-block;
  font-size: 9px;
  font-weight: 700;
  padding: 2px 4px;
  border-radius: 3px;
  margin-left: 5px;
}

.absence-badge.illness {
  background-color: #d32f2f;
  color: white;
}

.absence-badge.annual-leave {
  background-color: #f57c00;
  color: white;
}

.porter-times {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-right: 8px;
}

.porter-times .time-group {
  width: 90px;
}

.porter-times .time-group input[type="time"] {
  padding: 4px 6px;
  border: 1px solid rgba(0, 0, 0, 0.2);
  border-radius: 6px;
  font-size: 0.875rem;
  width: 100%;
}

.time-separator {
  font-size: 0.875rem;
  color: rgba(0, 0, 0, 0.6);
}

.btn--icon {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: rgba(0, 0, 0, 0.05);
  color: rgba(0, 0, 0, 0.6);
  border: none;
  cursor: pointer;
}

.btn--icon:hover {
  background-color: rgba(234, 67, 53, 0.1);
  color: #ea4335;
}

.add-porter {
  margin-top: 8px;
}

.add-porter-button {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 8px;
}

.no-porters-message {
  font-size: 0.875rem;
  color: rgba(0, 0, 0, 0.6);
  margin: 0;
}

.add-porter-form {
  padding: 12px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 8px;
  background-color: rgba(0, 0, 0, 0.02);
}

.form-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  align-items: center;
}

.form-row select {
  flex: 1;
  min-width: 150px;
  padding: 8px;
  border: 1px solid rgba(0, 0, 0, 0.2);
  border-radius: 6px;
  font-size: 0.875rem;
}

.form-row .time-group {
  width: 90px;
}

.form-row .time-group input[type="time"] {
  width: 100%;
  padding: 8px;
  border: 1px solid rgba(0, 0, 0, 0.2);
  border-radius: 6px;
  font-size: 0.875rem;
}

.action-buttons {
  display: flex;
  gap: 8px;
}

@media (max-width: 600px) {
  .form-row {
    flex-direction: column;
    align-items: stretch;
  }

  .form-row select,
  .form-row .time-group {
    width: 100%;
  }

  .action-buttons {
    margin-top: 8px;
    justify-content: flex-end;
  }
}

/* Coverage gap indicator */
.coverage-gap-indicator {
  background-color: rgba(234, 67, 53, 0.1);
  color: #ea4335;
  font-size: 0.75rem;
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 16px;
}

/* Button styles */
.btn {
  padding: 8px 16px;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  font-size: 0.875rem;
}

.btn--primary {
  background-color: #4285f4;
  color: white;
}

.btn--primary:hover:not(:disabled) {
  background-color: #3367d6;
}

.btn--secondary {
  background-color: #f1f1f1;
  color: #333;
}

.btn--secondary:hover:not(:disabled) {
  background-color: #e8e8e8;
}

.btn--danger {
  background-color: rgba(234, 67, 53, 0.1);
  color: #ea4335;
}

.btn--danger:hover:not(:disabled) {
  background-color: #ea4335;
  color: white;
}

.btn--small {
  padding: 6px 12px;
  font-size: 0.75rem;
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
