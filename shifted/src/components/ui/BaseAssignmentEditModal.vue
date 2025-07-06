<template>
  <BaseModal
    :title="modalTitle"
    size="lg"
    show-footer
    @close="$emit('close')"
  >
    <div class="assignment-edit-content">
      <!-- Entity-specific information slot -->
      <div v-if="$slots['entity-info']" class="entity-info-section">
        <slot name="entity-info" />
      </div>

      <!-- Time Range Editor -->
      <div class="time-range-section">
        <BaseTimeRangeEditor
          :start-time="localStartTime"
          :end-time="localEndTime"
          @update:start-time="localStartTime = $event"
          @update:end-time="localEndTime = $event"
          required
        />
      </div>

      <!-- Day-specific Porter Requirements -->
      <div class="porter-requirements-section">
        <BaseDayPorterRequirements
          v-model="localDayRequirements"
        />
      </div>

      <!-- Porter Assignment Manager -->
      <div class="porter-assignments-section">
        <BasePorterAssignmentManager
          v-model="localPorterAssignments"
          :available-porters="availablePorters"
          :coverage-time-range="coverageTimeRange"
          @porter-clicked="handlePorterClicked"
        />
      </div>

      <!-- Additional content slot -->
      <div v-if="$slots['additional-content']" class="additional-content-section">
        <slot name="additional-content" />
      </div>
    </div>

    <template #footer>
      <div class="modal-footer-actions">
        <div class="footer-left">
          <BaseButton
            v-if="showDeleteButton"
            variant="danger"
            @click="handleDelete"
          >
            {{ deleteButtonText }}
          </BaseButton>
        </div>

        <div class="footer-right">
          <BaseButton
            variant="secondary"
            @click="$emit('close')"
          >
            Cancel
          </BaseButton>
          <BaseButton
            variant="primary"
            @click="handleSave"
            :disabled="!canSave"
          >
            {{ saveButtonText }}
          </BaseButton>
        </div>
      </div>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useStaffStore } from '../../stores/staffStore'
import BaseModal from './BaseModal.vue'
import BaseButton from './BaseButton.vue'
import BaseTimeRangeEditor from './BaseTimeRangeEditor.vue'
import BaseDayPorterRequirements from './BaseDayPorterRequirements.vue'
import BasePorterAssignmentManager from './BasePorterAssignmentManager.vue'
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
  porter_assignments?: PorterAssignment[]
}

interface Props {
  modalTitle: string
  assignment?: AssignmentData | null
  saveButtonText?: string
  deleteButtonText?: string
  showDeleteButton?: boolean
  disabled?: boolean
}

interface Emits {
  (e: 'close'): void
  (e: 'save', data: {
    timeRange: { start: string; end: string }
    dayRequirements: number[]
    porterAssignments: PorterAssignment[]
  }): void
  (e: 'delete'): void
  (e: 'porter-clicked', porterId: string): void
}

const props = withDefaults(defineProps<Props>(), {
  saveButtonText: 'Save Changes',
  deleteButtonText: 'Delete',
  showDeleteButton: false,
  disabled: false
})

const emit = defineEmits<Emits>()

const staffStore = useStaffStore()

// Local state
const localStartTime = ref('')
const localEndTime = ref('')
const localDayRequirements = ref<number[]>([1, 1, 1, 1, 1, 1, 1])
const localPorterAssignments = ref<PorterAssignment[]>([])

// Computed properties
const coverageTimeRange = computed(() => ({
  start: localStartTime.value,
  end: localEndTime.value
}))

const availablePorters = computed(() => {
  // Get all porters from staff store
  const allPorters = staffStore.porters || []

  // Filter out porters that are already assigned
  const assignedPorterIds = localPorterAssignments.value.map(pa => pa.porter_id)

  // Filter out absent porters
  const today = new Date()
  return allPorters.filter(porter => {
    if (assignedPorterIds.includes(porter.id)) return false
    if (staffStore.isPorterAbsent?.(porter.id, today)) return false
    return true
  })
})

const canSave = computed(() => {
  return localStartTime.value && localEndTime.value && !props.disabled
})

// Methods
const initializeState = () => {
  if (!props.assignment) {
    // Default values for new assignment
    localStartTime.value = '08:00'
    localEndTime.value = '16:00'
    localDayRequirements.value = [1, 1, 1, 1, 1, 1, 1]
    localPorterAssignments.value = []
    return
  }

  const assignment = props.assignment

  // Initialize time range
  if (assignment.start_time && typeof assignment.start_time === 'string') {
    localStartTime.value = assignment.start_time.slice(0, 5)
  } else {
    localStartTime.value = '08:00' // Default fallback
  }

  if (assignment.end_time && typeof assignment.end_time === 'string') {
    localEndTime.value = assignment.end_time.slice(0, 5)
  } else {
    localEndTime.value = '16:00' // Default fallback
  }

  // Initialize day requirements
  const hasAnyDaySpecificValues =
    assignment.minimum_porters_mon !== undefined ||
    assignment.minimum_porters_tue !== undefined ||
    assignment.minimum_porters_wed !== undefined ||
    assignment.minimum_porters_thu !== undefined ||
    assignment.minimum_porters_fri !== undefined ||
    assignment.minimum_porters_sat !== undefined ||
    assignment.minimum_porters_sun !== undefined

  if (hasAnyDaySpecificValues) {
    localDayRequirements.value = [
      assignment.minimum_porters_mon ?? assignment.minimum_porters ?? 1,
      assignment.minimum_porters_tue ?? assignment.minimum_porters ?? 1,
      assignment.minimum_porters_wed ?? assignment.minimum_porters ?? 1,
      assignment.minimum_porters_thu ?? assignment.minimum_porters ?? 1,
      assignment.minimum_porters_fri ?? assignment.minimum_porters ?? 1,
      assignment.minimum_porters_sat ?? assignment.minimum_porters ?? 1,
      assignment.minimum_porters_sun ?? assignment.minimum_porters ?? 1
    ]
  } else {
    const defaultValue = assignment.minimum_porters ?? 1
    localDayRequirements.value = Array(7).fill(defaultValue)
  }

  // Initialize porter assignments
  if (assignment.porter_assignments) {
    localPorterAssignments.value = assignment.porter_assignments.map(pa => ({
      ...pa,
      start_time_display: pa.start_time ? pa.start_time.slice(0, 5) : '',
      end_time_display: pa.end_time ? pa.end_time.slice(0, 5) : ''
    }))
  } else {
    localPorterAssignments.value = []
  }
}

const handleSave = () => {
  if (!canSave.value) return

  emit('save', {
    timeRange: {
      start: localStartTime.value + ':00',
      end: localEndTime.value + ':00'
    },
    dayRequirements: localDayRequirements.value,
    porterAssignments: localPorterAssignments.value
  })
}

const handleDelete = () => {
  emit('delete')
}

const handlePorterClicked = (porterId: string) => {
  emit('porter-clicked', porterId)
}

// Watch for changes to assignment prop
watch(() => props.assignment, () => {
  initializeState()
}, { immediate: true, deep: true })

// Initialize staff data if needed
onMounted(async () => {
  if (!staffStore.porters || staffStore.porters.length === 0) {
    await staffStore.fetchPorters?.()
  }
})
</script>

<style scoped>
.assignment-edit-content {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-xl);
}

.entity-info-section,
.time-range-section,
.porter-requirements-section,
.porter-assignments-section,
.additional-content-section {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}

.modal-footer-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}

.footer-left {
  display: flex;
}

.footer-right {
  display: flex;
  gap: var(--spacing-sm);
}

@media (max-width: 768px) {
  .assignment-edit-content {
    gap: var(--spacing-lg);
  }

  .modal-footer-actions {
    flex-direction: column;
    gap: var(--spacing-md);
    align-items: stretch;
  }

  .footer-left,
  .footer-right {
    justify-content: stretch;
  }

  .footer-right {
    order: -1;
  }
}
</style>
