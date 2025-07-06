<template>
  <div class="porter-assignment-manager">
    <div class="section-header">
      <h4 class="section-title">Porter Assignments</h4>
      <div v-if="hasCoverageGap" class="coverage-gap-indicator">
        Coverage Gap Detected
      </div>
    </div>

    <div v-if="assignments.length === 0" class="empty-state">
      <p>No porters assigned. Add a porter to provide coverage.</p>
    </div>

    <div v-else class="porter-list">
      <div
        v-for="(assignment, index) in assignments"
        :key="assignment.id || `new-${index}`"
        class="porter-assignment-item"
      >
        <div class="porter-info">
          <div class="porter-pill">
            <span
              class="porter-name"
              :class="getPorterStatusClass(assignment.porter_id)"
              @click="handlePorterClick(assignment.porter_id)"
            >
              {{ getPorterDisplayName(assignment) }}
              <span
                v-if="getAbsenceBadge(assignment.porter_id)"
                class="absence-badge"
                :class="getAbsenceBadgeClass(assignment.porter_id)"
              >
                {{ getAbsenceBadge(assignment.porter_id) }}
              </span>
            </span>
          </div>
        </div>

        <div class="porter-times">
          <BaseTimeRangeEditor
            :start-time="assignment.start_time_display || ''"
            :end-time="assignment.end_time_display || ''"
            @update:start-time="(value) => updatePorterTime(index, 'start', value)"
            @update:end-time="(value) => updatePorterTime(index, 'end', value)"
          />
        </div>

        <BaseButton
          variant="ghost"
          size="sm"
          class="remove-button"
          @click="removeAssignment(index)"
          :title="`Remove ${getPorterDisplayName(assignment)}`"
        >
          <TrashIcon class="w-4 h-4" />
        </BaseButton>
      </div>
    </div>

    <div class="add-porter-section">
      <div v-if="!showAddForm" class="add-porter-button">
        <BaseButton
          variant="primary"
          @click="showAddForm = true"
          :disabled="availablePorters.length === 0"
        >
          <PlusIcon class="w-4 h-4" />
          Add Porter
        </BaseButton>

        <p v-if="availablePorters.length === 0" class="no-porters-message">
          No available porters to assign
        </p>
      </div>

      <div v-else class="add-porter-form">
        <BaseCard>
          <div class="form-content">
            <BaseFormField label="Select Porter" required>
              <select v-model="newAssignment.porter_id" class="porter-select">
                <option value="">-- Select Porter --</option>
                <option
                  v-for="porter in availablePorters"
                  :key="porter.id"
                  :value="porter.id"
                >
                  {{ porter.first_name }} {{ porter.last_name }}
                </option>
              </select>
            </BaseFormField>

            <BaseTimeRangeEditor
              :start-time="newAssignment.start_time"
              :end-time="newAssignment.end_time"
              @update:start-time="newAssignment.start_time = $event"
              @update:end-time="newAssignment.end_time = $event"
            />

            <div class="form-actions">
              <BaseButton
                variant="primary"
                @click="addAssignment"
                :disabled="!canAddAssignment"
              >
                Add Porter
              </BaseButton>
              <BaseButton
                variant="secondary"
                @click="cancelAdd"
              >
                Cancel
              </BaseButton>
            </div>
          </div>
        </BaseCard>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useStaffStore } from '../../stores/staffStore'
import BaseButton from './BaseButton.vue'
import BaseCard from './BaseCard.vue'
import BaseFormField from './BaseFormField.vue'
import BaseTimeRangeEditor from './BaseTimeRangeEditor.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'
import type { Staff } from '../../types/staff'

interface PorterAssignment {
  id?: string
  porter_id: string
  start_time?: string
  end_time?: string
  start_time_display?: string
  end_time_display?: string
  porter?: Staff
  isNew?: boolean
}

interface Props {
  modelValue: PorterAssignment[]
  availablePorters: Staff[]
  coverageTimeRange?: {
    start: string
    end: string
  }
  disabled?: boolean
}

interface Emits {
  (e: 'update:modelValue', value: PorterAssignment[]): void
  (e: 'porter-clicked', porterId: string): void
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false
})

const emit = defineEmits<Emits>()

const staffStore = useStaffStore()

const assignments = ref<PorterAssignment[]>([...props.modelValue])
const showAddForm = ref(false)
const newAssignment = ref({
  porter_id: '',
  start_time: '',
  end_time: ''
})

// Watch for external changes
watch(() => props.modelValue, (newValue) => {
  assignments.value = [...newValue]
}, { deep: true })

// Computed properties
const canAddAssignment = computed(() => {
  return newAssignment.value.porter_id &&
         newAssignment.value.start_time &&
         newAssignment.value.end_time
})

const hasCoverageGap = computed(() => {
  if (assignments.value.length === 0) return true
  if (!props.coverageTimeRange) return false

  return detectCoverageGap()
})

// Methods
const getPorterDisplayName = (assignment: PorterAssignment): string => {
  if (assignment.porter) {
    return `${assignment.porter.first_name} ${assignment.porter.last_name}`
  }

  // Fallback: find porter in available porters or staff store
  const porter = props.availablePorters.find(p => p.id === assignment.porter_id) ||
                 staffStore.porters.find(p => p.id === assignment.porter_id)

  return porter ? `${porter.first_name} ${porter.last_name}` : 'Unknown Porter'
}

const getPorterStatusClass = (porterId: string): string => {
  const absence = getPorterAbsence(porterId)
  if (!absence) return ''

  switch (absence.absence_type) {
    case 'illness': return 'porter-illness'
    case 'annual_leave': return 'porter-annual-leave'
    default: return 'porter-absent'
  }
}

const getAbsenceBadge = (porterId: string): string | null => {
  const absence = getPorterAbsence(porterId)
  if (!absence) return null

  switch (absence.absence_type) {
    case 'illness': return 'ILL'
    case 'annual_leave': return 'AL'
    default: return 'ABS'
  }
}

const getAbsenceBadgeClass = (porterId: string): string => {
  const absence = getPorterAbsence(porterId)
  if (!absence) return ''

  switch (absence.absence_type) {
    case 'illness': return 'illness'
    case 'annual_leave': return 'annual-leave'
    default: return 'other'
  }
}

const getPorterAbsence = (porterId: string) => {
  const today = new Date()
  return staffStore.getPorterAbsenceDetails(porterId, today) || null
}

const handlePorterClick = (porterId: string) => {
  emit('porter-clicked', porterId)
}

const updatePorterTime = (index: number, type: 'start' | 'end', value: string) => {
  const assignment = assignments.value[index]

  if (type === 'start') {
    assignment.start_time_display = value
    assignment.start_time = value + ':00'
  } else {
    assignment.end_time_display = value
    assignment.end_time = value + ':00'
  }

  emit('update:modelValue', [...assignments.value])
}

const addAssignment = () => {
  if (!canAddAssignment.value) return

  const porter = props.availablePorters.find(p => p.id === newAssignment.value.porter_id)
  if (!porter) return

  const assignment: PorterAssignment = {
    id: `temp-${Date.now()}`,
    porter_id: newAssignment.value.porter_id,
    start_time: newAssignment.value.start_time + ':00',
    end_time: newAssignment.value.end_time + ':00',
    start_time_display: newAssignment.value.start_time,
    end_time_display: newAssignment.value.end_time,
    porter: porter,
    isNew: true
  }

  assignments.value.push(assignment)
  emit('update:modelValue', [...assignments.value])

  // Reset form
  newAssignment.value = {
    porter_id: '',
    start_time: '',
    end_time: ''
  }
  showAddForm.value = false
}

const removeAssignment = (index: number) => {
  assignments.value.splice(index, 1)
  emit('update:modelValue', [...assignments.value])
}

const cancelAdd = () => {
  newAssignment.value = {
    porter_id: '',
    start_time: '',
    end_time: ''
  }
  showAddForm.value = false
}

const detectCoverageGap = (): boolean => {
  if (!props.coverageTimeRange || assignments.value.length === 0) return true

  const coverageStart = timeToMinutes(props.coverageTimeRange.start)
  const coverageEnd = timeToMinutes(props.coverageTimeRange.end)

  // Filter out absent porters
  const availableAssignments = assignments.value.filter(assignment => {
    return !staffStore.isPorterAbsent(assignment.porter_id, new Date())
  })

  if (availableAssignments.length === 0) return true

  // Check if any single porter covers the entire time period
  const fullCoverageExists = availableAssignments.some(assignment => {
    const porterStart = timeToMinutes(assignment.start_time_display + ':00')
    const porterEnd = timeToMinutes(assignment.end_time_display + ':00')
    return porterStart <= coverageStart && porterEnd >= coverageEnd
  })

  if (fullCoverageExists) return false

  // Sort assignments by start time and check for gaps
  const sortedAssignments = [...availableAssignments].sort((a, b) => {
    return timeToMinutes(a.start_time_display + ':00') - timeToMinutes(b.start_time_display + ':00')
  })

  // Check for gap at the beginning
  if (timeToMinutes(sortedAssignments[0].start_time_display + ':00') > coverageStart) {
    return true
  }

  // Check for gaps between assignments
  for (let i = 0; i < sortedAssignments.length - 1; i++) {
    const currentEnd = timeToMinutes(sortedAssignments[i].end_time_display + ':00')
    const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time_display + ':00')

    if (nextStart > currentEnd) {
      return true
    }
  }

  // Check for gap at the end
  const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time_display + ':00')
  if (lastEnd < coverageEnd) {
    return true
  }

  return false
}

// Helper function to convert time string to minutes
const timeToMinutes = (timeStr: string): number => {
  if (!timeStr) return 0
  const [hours, minutes] = timeStr.split(':').map(Number)
  return (hours * 60) + minutes
}
</script>

<style scoped>
.porter-assignment-manager {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.section-title {
  font-size: var(--font-size-lg);
  font-weight: 600;
  margin: 0;
  color: var(--color-text-primary);
}

.coverage-gap-indicator {
  background-color: var(--color-error-light);
  color: var(--color-error);
  font-size: var(--font-size-xs);
  font-weight: 500;
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--border-radius-full);
}

.empty-state {
  padding: var(--spacing-lg);
  text-align: center;
  color: var(--color-text-muted);
  background-color: var(--color-gray-25);
  border-radius: var(--border-radius-md);
}

.porter-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}

.porter-assignment-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-md);
  padding: var(--spacing-md);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  background-color: var(--color-background);
}

.porter-info {
  min-width: 140px;
}

.porter-pill {
  display: inline-block;
}

.porter-name {
  display: inline-flex;
  align-items: center;
  gap: var(--spacing-xs);
  background-color: var(--color-primary-light);
  color: var(--color-primary);
  border-radius: var(--border-radius-full);
  padding: var(--spacing-xs) var(--spacing-sm);
  font-size: var(--font-size-sm);
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.porter-name:hover {
  background-color: var(--color-primary-alpha);
}

.porter-name.porter-illness {
  background-color: var(--color-error-light);
  color: var(--color-error);
}

.porter-name.porter-annual-leave {
  background-color: var(--color-warning-light);
  color: var(--color-warning);
}

.porter-name.porter-absent {
  opacity: 0.7;
}

.absence-badge {
  font-size: var(--font-size-xs);
  font-weight: 700;
  padding: 2px 4px;
  border-radius: var(--border-radius-sm);
  color: white;
}

.absence-badge.illness {
  background-color: var(--color-error);
}

.absence-badge.annual-leave {
  background-color: var(--color-warning);
}

.absence-badge.other {
  background-color: var(--color-gray-500);
}

.porter-times {
  flex: 1;
}

.remove-button {
  color: var(--color-text-muted);
}

.remove-button:hover {
  color: var(--color-error);
  background-color: var(--color-error-light);
}

.add-porter-section {
  margin-top: var(--spacing-md);
}

.add-porter-button {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: var(--spacing-sm);
}

.no-porters-message {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
  margin: 0;
}

.add-porter-form {
  margin-top: var(--spacing-md);
}

.form-content {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}

.porter-select {
  width: 100%;
  padding: var(--spacing-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  font-size: var(--font-size-md);
  background-color: var(--color-background);
}

.porter-select:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-alpha);
}

.form-actions {
  display: flex;
  gap: var(--spacing-sm);
  justify-content: flex-end;
}

@media (max-width: 768px) {
  .porter-assignment-item {
    flex-direction: column;
    align-items: stretch;
    gap: var(--spacing-sm);
  }

  .porter-info {
    min-width: auto;
  }

  .form-actions {
    justify-content: stretch;
  }

  .form-actions .btn {
    flex: 1;
  }
}
</style>
