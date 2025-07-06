<template>
  <BaseAssignmentEditModal
    :modal-title="`Edit ${assignment?.department?.name || 'Department'} Coverage`"
    :assignment="assignmentData"
    save-button-text="Update Coverage"
    delete-button-text="Remove from Coverage"
    :show-delete-button="true"
    @close="$emit('close')"
    @save="handleSave"
    @delete="handleDelete"
    @porter-clicked="handlePorterClicked"
  >
    <template #entity-info>
      <DepartmentInfo :assignment="assignment" />
    </template>
  </BaseAssignmentEditModal>

  <!-- Porter Absence Modal -->
  <Teleport to="body">
    <PorterAbsenceModal
      v-if="showAbsenceModal && selectedPorterId"
      :porter-id="selectedPorterId"
      :absence="currentPorterAbsence"
      @close="showAbsenceModal = false"
      @save="handleAbsenceSave"
    />
  </Teleport>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useStaffStore } from '../../stores/staffStore'
import BaseAssignmentEditModal from '../ui/BaseAssignmentEditModal.vue'
import DepartmentInfo from './DepartmentInfo.vue'
import PorterAbsenceModal from '../PorterAbsenceModal.vue'
import type { AreaCoverAssignment } from '../../types/areaCover'
import type { PorterAbsence } from '../../types/staff'

interface Props {
  assignment: AreaCoverAssignment
}

interface Emits {
  (e: 'close'): void
  (e: 'save', data: {
    timeRange: { start: string; end: string }
    dayRequirements: number[]
    porterAssignments: any[]
  }): void
  (e: 'delete'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const staffStore = useStaffStore()

const showAbsenceModal = ref(false)
const selectedPorterId = ref<string | null>(null)
const currentPorterAbsence = ref<PorterAbsence | null>(null)

// Transform assignment data for BaseAssignmentEditModal
const assignmentData = computed(() => {
  if (!props.assignment) return null

  return {
    id: props.assignment.id,
    start_time: props.assignment.start_time,
    end_time: props.assignment.end_time,
    minimum_porters: props.assignment.minimum_porters || 1,
    porter_assignments: [] // This will be populated by the parent component
  }
})

// Methods
const handleSave = (data: {
  timeRange: { start: string; end: string }
  dayRequirements: number[]
  porterAssignments: any[]
}) => {
  emit('save', data)
}

const handleDelete = () => {
  emit('delete')
}

const handlePorterClicked = (porterId: string) => {
  selectedPorterId.value = porterId
  const today = new Date()
  currentPorterAbsence.value = staffStore.getPorterAbsenceDetails?.(porterId, today) || null
  showAbsenceModal.value = true
}

const handleAbsenceSave = () => {
  // Refresh the absence data
  currentPorterAbsence.value = null
  showAbsenceModal.value = false
}
</script>

<style scoped>
/* No additional styles needed - everything is handled by BaseAssignmentEditModal */
</style>
