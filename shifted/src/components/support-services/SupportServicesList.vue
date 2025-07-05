<template>
  <div class="support-services-list">
    <div class="list-header">
      <div class="header-info">
        <h4>{{ shiftTypeLabel }} Support Services</h4>
        <p v-if="assignments.length > 0">
          {{ assignments.length }} service{{ assignments.length !== 1 ? 's' : '' }} configured
        </p>
        <p v-else class="no-services">
          No services configured for this shift type
        </p>
      </div>
      <BaseButton
        variant="primary"
        size="sm"
        @click="showAddService = true"
      >
        <PlusIcon class="w-4 h-4" />
        Add Service
      </BaseButton>
    </div>

    <div v-if="loading.services" class="loading-state">
      <div class="loading-spinner"></div>
      <p>Loading services...</p>
    </div>

    <div v-else-if="assignments.length === 0" class="empty-state">
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
    </div>

    <div v-else class="services-grid">
      <ServiceAssignmentCard
        v-for="assignment in assignments"
        :key="assignment.id"
        :assignment="assignment"
        @edit="editAssignment"
        @delete="deleteAssignment"
      />
    </div>

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
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useSupportServicesStore } from '../../stores/supportServicesStore'
import BaseButton from '../ui/BaseButton.vue'
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
.support-services-list {
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

.header-info p {
  color: var(--color-text-light);
  font-size: 0.875rem;
  margin: 0;
}

.no-services {
  color: var(--color-text-muted);
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  gap: var(--spacing);
  color: var(--color-text-light);
}

.loading-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-border);
  border-top: 3px solid var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  text-align: center;
  color: var(--color-text-light);
}

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

.services-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--spacing);
}

@container (min-width: 640px) {
  .services-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@container (min-width: 1024px) {
  .services-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}
</style>
