<template>
  <div class="service-assignment-card">
    <div class="card-header">
      <div class="service-info">
        <h5 class="service-name">{{ assignment.service?.name || 'Unknown Service' }}</h5>
        <p class="service-description">{{ assignment.service?.description || 'No description' }}</p>
      </div>
      <div class="card-actions">
        <button
          class="action-btn edit-btn"
          @click="$emit('edit', assignment)"
          title="Edit Service"
        >
          <EditIcon class="w-4 h-4" />
        </button>
        <button
          class="action-btn delete-btn"
          @click="$emit('delete', assignment)"
          title="Delete Service"
        >
          <TrashIcon class="w-4 h-4" />
        </button>
      </div>
    </div>

    <div class="card-body">
      <div class="time-info">
        <div class="time-range">
          <span class="time-label">Time:</span>
          <span class="time-value">{{ formatTimeRange(assignment.start_time, assignment.end_time) }}</span>
        </div>
        <div v-if="assignment.minimum_porters" class="min-porters">
          <span class="time-label">Min Porters:</span>
          <span class="time-value">{{ assignment.minimum_porters }}</span>
        </div>
      </div>

      <div class="coverage-status">
        <div class="status-indicator" :class="coverageStatusClass">
          <div class="status-dot"></div>
          <span class="status-text">{{ coverageStatusText }}</span>
        </div>
      </div>
    </div>

    <div v-if="assignment.color" class="color-bar" :style="{ backgroundColor: assignment.color }"></div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useSupportServicesStore } from '../../stores/supportServicesStore'
import EditIcon from '../icons/EditIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'
import type { ServiceAssignment } from '../../types/supportServices'

interface Props {
  assignment: ServiceAssignment
}

interface Emits {
  (e: 'edit', assignment: ServiceAssignment): void
  (e: 'delete', assignment: ServiceAssignment): void
}

const props = defineProps<Props>()
defineEmits<Emits>()

const supportServicesStore = useSupportServicesStore()

const formatTimeRange = (startTime: string, endTime: string): string => {
  const formatTime = (time: string) => {
    const [hours, minutes] = time.split(':')
    return `${hours}:${minutes}`
  }
  return `${formatTime(startTime)} - ${formatTime(endTime)}`
}

const coverageStatus = computed(() => {
  const gaps = supportServicesStore.getCoverageGaps(props.assignment.id)
  const shortages = supportServicesStore.getStaffingShortages(props.assignment.id)

  if (gaps.hasGap) return 'gap'
  if (shortages.hasShortage) return 'shortage'
  return 'covered'
})

const coverageStatusClass = computed(() => ({
  'status-covered': coverageStatus.value === 'covered',
  'status-gap': coverageStatus.value === 'gap',
  'status-shortage': coverageStatus.value === 'shortage'
}))

const coverageStatusText = computed(() => {
  switch (coverageStatus.value) {
    case 'covered': return 'Fully Covered'
    case 'gap': return 'Coverage Gap'
    case 'shortage': return 'Staff Shortage'
    default: return 'Unknown'
  }
})
</script>

<style scoped>
.service-assignment-card {
  position: relative;
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  overflow: hidden;
  transition: all 0.2s ease;
}

.service-assignment-card:hover {
  border-color: var(--color-border-hover);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: var(--spacing);
  gap: var(--spacing-sm);
}

.service-info {
  flex: 1;
  min-width: 0;
}

.service-name {
  font-size: 1rem;
  font-weight: 600;
  margin: 0 0 var(--spacing-xs) 0;
  color: var(--color-text);
  line-height: 1.4;
}

.service-description {
  font-size: 0.875rem;
  color: var(--color-text-light);
  margin: 0;
  line-height: 1.4;
}

.card-actions {
  display: flex;
  gap: var(--spacing-xs);
  flex-shrink: 0;
}

.action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border: none;
  border-radius: var(--radius-sm);
  background: var(--color-background-alt);
  color: var(--color-text-light);
  cursor: pointer;
  transition: all 0.2s ease;
}

.action-btn:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.edit-btn:hover {
  background: var(--color-primary-light);
  color: var(--color-primary);
}

.delete-btn:hover {
  background: var(--color-danger-light);
  color: var(--color-danger);
}

.card-body {
  padding: 0 var(--spacing) var(--spacing) var(--spacing);
}

.time-info {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-xs);
  margin-bottom: var(--spacing);
}

.time-range,
.min-porters {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.time-label {
  font-size: 0.875rem;
  color: var(--color-text-light);
  font-weight: 500;
}

.time-value {
  font-size: 0.875rem;
  color: var(--color-text);
  font-weight: 600;
}

.coverage-status {
  display: flex;
  justify-content: flex-end;
}

.status-indicator {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-sm);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.025em;
}

.status-covered {
  background: var(--color-success-light);
  color: var(--color-success);
}

.status-gap {
  background: var(--color-warning-light);
  color: var(--color-warning);
}

.status-shortage {
  background: var(--color-danger-light);
  color: var(--color-danger);
}

.status-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
}

.color-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 3px;
}
</style>
