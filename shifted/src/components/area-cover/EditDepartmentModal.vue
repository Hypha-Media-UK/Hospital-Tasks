<template>
  <BaseEditAssignmentModal
    :modal-title="assignment.department?.name || 'Department'"
    :assignment="assignment"
    save-button-text="Update Coverage"
    delete-button-text="Remove from Coverage"
    :show-delete-button="true"
    :get-porter-assignments="getPorterAssignments"
    @close="$emit('close')"
    @save="handleSave"
    @delete="handleDelete"
    @porter-clicked="handlePorterClicked"
  >
    <template #entity-info>
      <DepartmentInfo :assignment="assignment" />
    </template>
  </BaseEditAssignmentModal>

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
import { ref } from 'vue'
import { useStaffStore } from '../../stores/staffStore'
import { useAreaCoverStore } from '../../stores/areaCoverStore'
import BaseEditAssignmentModal from '../ui/BaseEditAssignmentModal.vue'
import DepartmentInfo from './DepartmentInfo.vue'
import PorterAbsenceModal from '../PorterAbsenceModal.vue'
import type { AreaCoverAssignment } from '../../types/areaCover'
import type { PorterAbsence } from '../../types/staff'

interface Props {
  assignment: AreaCoverAssignment
}

interface Emits {
  (e: 'close'): void
  (e: 'saved'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const staffStore = useStaffStore()
const areaCoverStore = useAreaCoverStore()

const showAbsenceModal = ref(false)
const selectedPorterId = ref<string | null>(null)
const currentPorterAbsence = ref<PorterAbsence | null>(null)

// Get porter assignments for this area cover assignment
const getPorterAssignments = (assignmentId: string) => {
  try {
    return areaCoverStore.getPorterAssignmentsByAreaId(assignmentId) || []
  } catch (error) {
    console.error('Error getting porter assignments:', error)
    return []
  }
}

// Handle save operation
const handleSave = async (data: {
  timeRange: { start: string; end: string }
  dayRequirements: number[]
  porterAssignments: any[]
  removedPorterIds: string[]
}) => {
  try {
    console.log('💾 Saving area cover assignment changes...')

    // 1. Update area cover assignment (times, minimum porters)
    const updateData: any = {
      start_time: data.timeRange.start,
      end_time: data.timeRange.end,
      minimum_porters: data.dayRequirements[0] || 1
    }

    // Add day-specific minimum porter counts
    const days = [
      { field: 'minimum_porters_mon' },
      { field: 'minimum_porters_tue' },
      { field: 'minimum_porters_wed' },
      { field: 'minimum_porters_thu' },
      { field: 'minimum_porters_fri' },
      { field: 'minimum_porters_sat' },
      { field: 'minimum_porters_sun' }
    ]

    days.forEach((day, index) => {
      updateData[day.field] = data.dayRequirements[index] || 1
    })

    await areaCoverStore.updateDepartment(props.assignment.id, updateData)

    // 2. Remove porter assignments that were deleted
    for (const porterId of data.removedPorterIds) {
      await areaCoverStore.removePorterAssignment(porterId)
    }

    // 3. Process porter assignments
    for (const assignment of data.porterAssignments) {
      if (assignment.isNew) {
        // Add new assignment
        await areaCoverStore.addPorterAssignment(
          props.assignment.id,
          assignment.porter_id,
          assignment.start_time,
          assignment.end_time
        )
      } else {
        // Update existing assignment
        await areaCoverStore.updatePorterAssignment(assignment.id, {
          start_time: assignment.start_time_display + ':00',
          end_time: assignment.end_time_display + ':00'
        })
      }
    }

    console.log('✅ Area cover assignment saved successfully')
    emit('saved')
  } catch (error) {
    console.error('❌ Error saving changes:', error)
    alert('Failed to save changes. Please try again.')
  }
}

// Handle delete operation
const handleDelete = async () => {
  if (confirm(`Are you sure you want to remove "${props.assignment.department?.name}" from coverage?`)) {
    try {
      console.log('🗑️ Deleting area cover assignment...')
      await areaCoverStore.removeDepartment(props.assignment.id)
      console.log('✅ Area cover assignment deleted successfully')
      emit('saved')
    } catch (error) {
      console.error('❌ Error deleting area cover assignment:', error)
      alert('Failed to delete assignment. Please try again.')
    }
  }
}

// Handle porter clicked for absence modal
const handlePorterClicked = (porterId: string) => {
  selectedPorterId.value = porterId
  const today = new Date()
  currentPorterAbsence.value = staffStore.getPorterAbsenceDetails?.(porterId, today) || null
  showAbsenceModal.value = true
}

// Handle absence save
const handleAbsenceSave = () => {
  // Refresh the absence data
  currentPorterAbsence.value = null
  showAbsenceModal.value = false
}
</script>

<style scoped>
/* No additional styles needed - everything is handled by BaseEditAssignmentModal */
</style>
