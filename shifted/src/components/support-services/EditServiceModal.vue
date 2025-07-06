<template>
  <BaseAssignmentEditModal
    :modal-title="`Edit ${service?.name || 'Service'} Coverage`"
    :assignment="serviceAssignmentData"
    save-button-text="Update Service"
    delete-button-text="Delete Service"
    :show-delete-button="true"
    @close="$emit('close')"
    @save="handleSave"
    @delete="handleDelete"
    @porter-clicked="handlePorterClicked"
  >
    <template #entity-info>
      <ServiceInfo :assignment="assignment" />
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
import { ref, computed, onMounted } from 'vue'
import { useStaffStore } from '../../stores/staffStore'
import { useSupportServicesStore } from '../../stores/supportServicesStore'
import BaseAssignmentEditModal from '../ui/BaseAssignmentEditModal.vue'
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

// Get the service from the assignment
const service = computed(() => props.assignment.service)

// Get porter assignments for this service assignment
const porterAssignments = computed(() => {
  if (!props.assignment?.id) return []

  try {
    // Get porter assignments from the store
    const assignments = supportServicesStore.getPorterAssignmentsByServiceId?.(props.assignment.id) || []

    return assignments.map((pa: any) => ({
      id: pa.id,
      porter_id: pa.porter_id,
      start_time: pa.start_time,
      end_time: pa.end_time,
      porter: pa.porter || {
        id: pa.porter_id,
        first_name: 'Unknown',
        last_name: 'Porter',
        role: 'Porter'
      },
      isNew: false
    }))
  } catch (error) {
    console.error('Error loading porter assignments:', error)
    return []
  }
})

// Transform assignment data for BaseAssignmentEditModal
const serviceAssignmentData = computed(() => {
  if (!props.assignment) return null

  return {
    id: props.assignment.id,
    start_time: props.assignment.start_time,
    end_time: props.assignment.end_time,
    minimum_porters: props.assignment.minimum_porters || 1,
    minimum_porters_mon: props.assignment.minimum_porters_mon || props.assignment.minimum_porters || 1,
    minimum_porters_tue: props.assignment.minimum_porters_tue || props.assignment.minimum_porters || 1,
    minimum_porters_wed: props.assignment.minimum_porters_wed || props.assignment.minimum_porters || 1,
    minimum_porters_thu: props.assignment.minimum_porters_thu || props.assignment.minimum_porters || 1,
    minimum_porters_fri: props.assignment.minimum_porters_fri || props.assignment.minimum_porters || 1,
    minimum_porters_sat: props.assignment.minimum_porters_sat || props.assignment.minimum_porters || 1,
    minimum_porters_sun: props.assignment.minimum_porters_sun || props.assignment.minimum_porters || 1,
    porter_assignments: porterAssignments.value
  }
})

// Methods
const handleSave = async (data: {
  timeRange: { start: string; end: string }
  dayRequirements: number[]
  porterAssignments: any[]
}) => {
  console.log('💾 Saving service assignment:', data)

  if (!props.assignment?.id) return

  try {
    // 1. Update service assignment times and minimum porters
    const updateData = {
      start_time: data.timeRange.start + ':00',
      end_time: data.timeRange.end + ':00',
      minimum_porters: data.dayRequirements[0] || 1,
      // Day-specific minimum porter counts
      minimum_porters_mon: data.dayRequirements[0] || 1,
      minimum_porters_tue: data.dayRequirements[1] || 1,
      minimum_porters_wed: data.dayRequirements[2] || 1,
      minimum_porters_thu: data.dayRequirements[3] || 1,
      minimum_porters_fri: data.dayRequirements[4] || 1,
      minimum_porters_sat: data.dayRequirements[5] || 1,
      minimum_porters_sun: data.dayRequirements[6] || 1
    }

    if (supportServicesStore.updateServiceAssignment) {
      await supportServicesStore.updateServiceAssignment(props.assignment.id, updateData)
    }

    // 2. Handle porter assignments
    const existingAssignments = porterAssignments.value
    const existingIds = existingAssignments.map((a: any) => a.id)
    const newAssignmentIds = data.porterAssignments.filter((a: any) => !a.isNew).map((a: any) => a.id)

    // Remove assignments that are no longer present
    for (const existingId of existingIds) {
      if (!newAssignmentIds.includes(existingId)) {
        if (supportServicesStore.removePorterAssignment) {
          await supportServicesStore.removePorterAssignment(existingId)
        }
      }
    }

    // Process porter assignments
    for (const assignment of data.porterAssignments) {
      if (assignment.isNew) {
        // Add new assignment
        if (supportServicesStore.addPorterToServiceAssignment) {
          await supportServicesStore.addPorterToServiceAssignment(
            props.assignment.id,
            assignment.porter_id,
            assignment.start_time,
            assignment.end_time
          )
        }
      } else {
        // Update existing assignment
        if (supportServicesStore.updatePorterAssignment) {
          await supportServicesStore.updatePorterAssignment(assignment.id, {
            start_time: assignment.start_time,
            end_time: assignment.end_time
          })
        }
      }
    }

    console.log('✅ Service assignment saved successfully')
    emit('saved')
  } catch (error) {
    console.error('❌ Error saving service assignment:', error)
    alert('Failed to save changes. Please try again.')
  }
}

const handleDelete = async () => {
  if (!service.value?.name) return

  if (confirm(`Are you sure you want to delete the ${service.value.name} service?`)) {
    try {
      console.log('🗑️ Deleting service:', service.value.name)

      // Delete the service assignment and all related porter assignments
      if (supportServicesStore.deleteServiceAssignment && props.assignment?.id) {
        await supportServicesStore.deleteServiceAssignment(props.assignment.id)
      }

      console.log('✅ Service deleted successfully')
      emit('saved')
    } catch (error) {
      console.error('❌ Error deleting service:', error)
      alert('Failed to delete service. Please try again.')
    }
  }
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
