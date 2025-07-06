<template>
  <BaseListContainer
    :title="`${shiftTypeLabel} Support Services`"
    item-type="service"
    :items="assignments"
    :loading="loading.services"
    loading-text="Loading services..."
  >
    <template #header-actions>
      <BaseButton
        variant="primary"
        size="sm"
        @click="showAddService = true"
      >
        <PlusIcon class="w-4 h-4" />
        Add Service
      </BaseButton>
    </template>

    <template #empty-state>
      <div class="empty-icon">
        <StarIcon class="w-12 h-12" />
      </div>
      <h3>No Services Configured</h3>
      <p>Add your first support service to get started with area coverage management.</p>
      <BaseButton
        variant="primary"
        @click="showAddService = true"
      >
        <PlusIcon class="w-4 h-4" />
        Add First Service
      </BaseButton>
    </template>

    <template #items="{ items }">
      <ServiceAssignmentCard
        v-for="assignment in items"
        :key="assignment.id"
        :assignment="assignment"
        @edit="editAssignment"
        @delete="deleteAssignment"
      />
    </template>

    <template #modals>
      <!-- Add Service Modal -->
      <AddServiceModal
        v-if="showAddService"
        :shift-type="shiftType"
        @close="showAddService = false"
        @saved="handleServiceAdded"
      />

      <!-- Edit Service Modal -->
      <EditServiceModal
        v-if="editingAssignment"
        :assignment="editingAssignment"
        @close="editingAssignment = null"
        @saved="handleServiceUpdated"
      />
    </template>
  </BaseListContainer>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useSupportServicesStore } from '../../stores/supportServicesStore'
import BaseButton from '../ui/BaseButton.vue'
import BaseListContainer from '../ui/BaseListContainer.vue'
import ServiceAssignmentCard from './ServiceAssignmentCard.vue'
import AddServiceModal from './AddServiceModal.vue'
import EditServiceModal from './EditServiceModal.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import StarIcon from '../icons/StarIcon.vue'
import type { ShiftType, ServiceAssignment } from '../../types/supportServices'

interface Props {
  shiftType: ShiftType
}

const props = defineProps<Props>()

const supportServicesStore = useSupportServicesStore()
const showAddService = ref(false)
const editingAssignment = ref<ServiceAssignment | null>(null)

const { loading } = supportServicesStore

const assignments = computed(() =>
  supportServicesStore.getAssignmentsByShiftType(props.shiftType)
)

const shiftTypeLabel = computed(() => {
  const labels = {
    week_day: 'Week Day',
    week_night: 'Week Night',
    weekend_day: 'Weekend Day',
    weekend_night: 'Weekend Night'
  }
  return labels[props.shiftType]
})

const editAssignment = (assignment: ServiceAssignment) => {
  editingAssignment.value = assignment
}

const deleteAssignment = async (assignment: ServiceAssignment) => {
  if (confirm(`Are you sure you want to delete the ${assignment.service?.name} assignment?`)) {
    // Implementation would call store method
    console.log('Delete assignment:', assignment.id)
  }
}

const handleServiceAdded = () => {
  showAddService.value = false
  // Refresh data if needed
}

const handleServiceUpdated = () => {
  editingAssignment.value = null
  // Refresh data if needed
}
</script>

<style scoped>
.empty-icon {
  margin-bottom: var(--spacing-lg);
  opacity: 0.6;
  color: var(--color-text-muted);
}

.empty-state h3 {
  margin-bottom: var(--spacing-sm);
  color: var(--color-text);
}

.empty-state p {
  margin-bottom: var(--spacing-lg);
  max-width: 400px;
}
</style>
