<template>
  <BaseEditAssignmentModal
    :modal-title="assignment.service?.name || 'Service'"
    :assignment="assignment"
    save-button-text="Update Service"
    delete-button-text="Delete Service"
    :show-delete-button="true"
    :get-porter-assignments="getPorterAssignments"
    @close="$emit('close')"
    @save="handleSave"
    @delete="handleDelete"
    @porter-clicked="handlePorterClicked"
  >
    <template #entity-info>
      <ServiceInfo :assignment="assignment" />
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
import { useSupportServicesStore } from '../../stores/supportServicesStore'
import BaseEditAssignmentModal from '../ui/BaseEditAssignmentModal.vue'
import ServiceInfo from './ServiceInfo.vue'
import PorterAbsenceModal from '../PorterAbsenceModal.vue'
import type { ServiceAssignment } from '../../types/supportServices'
import type { PorterAbsence } from '../../types/staff'

interface Props {
  assignment: ServiceAssignment
}

interface Emits {
  (e: 'close'): void
  (e: 'saved'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const staffStore = useStaffStore()
const supportServicesStore = useSupportServicesStore()

const showAbsenceModal = ref(false)
const selectedPorterId = ref<string | null>(null)
const currentPorterAbsence = ref<PorterAbsence | null>(null)

// Get porter assignments for this service assignment
const getPorterAssignments = (assignmentId: string) => {
  try {
    return supportServicesStore.getPorterAssignmentsByServiceId(assignmentId) || []
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
    console.log('💾 Saving service assignment changes...')

    // 1. Update service assignment (times, minimum porters)
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

    await supportServicesStore.updateServiceAssignment(props.assignment.id, updateData)

    // 2. Remove porter assignments that were deleted
    for (const porterId of data.removedPorterIds) {
      await supportServicesStore.removePorterAssignment(porterId)
    }

    // 3. Process porter assignments
    for (const assignment of data.porterAssignments) {
      if (assignment.isNew) {
        // Add new assignment
        await supportServicesStore.addPorterToServiceAssignment(
          props.assignment.id,
          assignment.porter_id,
          assignment.start_time,
          assignment.end_time
        )
      } else {
        // Update existing assignment
        await supportServicesStore.updatePorterAssignment(assignment.id, {
          start_time: assignment.start_time_display + ':00',
          end_time: assignment.end_time_display + ':00'
        })
      }
    }

    console.log('✅ Service assignment saved successfully')
    emit('saved')
  } catch (error) {
    console.error('❌ Error saving changes:', error)
    alert('Failed to save changes. Please try again.')
  }
}

// Handle delete operation
const handleDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.assignment.service?.name}"?`)) {
    try {
      console.log('🗑️ Deleting service assignment...')
      await supportServicesStore.deleteServiceAssignment(props.assignment.id)
      console.log('✅ Service assignment deleted successfully')
      emit('saved')
    } catch (error) {
      console.error('❌ Error deleting service assignment:', error)
      alert('Failed to delete service. Please try again.')
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
