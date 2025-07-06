<template>
  <div class="department-info">
    <BaseCard>
      <div class="department-header">
        <div class="department-details">
          <h3 class="department-name">{{ assignment.department?.name || 'Unknown Department' }}</h3>
          <p class="building-name">{{ assignment.department?.building?.name || 'Unknown Building' }}</p>
        </div>

        <div class="department-meta">
          <div class="shift-type-badge" :class="shiftTypeBadgeClass">
            {{ shiftTypeLabel }}
          </div>
        </div>
      </div>

      <div v-if="assignment.department" class="department-stats">
        <div class="stat-item">
          <span class="stat-label">Department ID:</span>
          <span class="stat-value">{{ assignment.department.id }}</span>
        </div>

        <div class="stat-item">
          <span class="stat-label">Shift Type:</span>
          <span class="stat-value">{{ shiftTypeLabel }}</span>
        </div>

        <div v-if="assignment.minimum_porters" class="stat-item">
          <span class="stat-label">Minimum Porters:</span>
          <span class="stat-value">{{ assignment.minimum_porters }}</span>
        </div>
      </div>
    </BaseCard>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import BaseCard from '../ui/BaseCard.vue'
import type { AreaCoverAssignment } from '../../types/areaCover'

interface Props {
  assignment: AreaCoverAssignment
}

const props = defineProps<Props>()

// Computed properties
const shiftTypeLabel = computed(() => {
  switch (props.assignment.shift_type) {
    case 'week_day': return 'Week Day'
    case 'week_night': return 'Week Night'
    case 'weekend_day': return 'Weekend Day'
    case 'weekend_night': return 'Weekend Night'
    default: return props.assignment.shift_type
  }
})

const shiftTypeBadgeClass = computed(() => {
  switch (props.assignment.shift_type) {
    case 'week_day': return 'badge-week-day'
    case 'week_night': return 'badge-week-night'
    case 'weekend_day': return 'badge-weekend-day'
    case 'weekend_night': return 'badge-weekend-night'
    default: return 'badge-default'
  }
})
</script>

<style scoped>
.department-info {
  margin-bottom: var(--spacing-lg);
}

.department-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: var(--spacing-md);
}

.department-details {
  flex: 1;
}

.department-name {
  margin: 0 0 var(--spacing-xs) 0;
  font-size: var(--font-size-xl);
  font-weight: 600;
  color: var(--color-text-primary);
}

.building-name {
  margin: 0;
  font-size: var(--font-size-md);
  color: var(--color-text-muted);
}

.department-meta {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.shift-type-badge {
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--border-radius-full);
  font-size: var(--font-size-sm);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.badge-week-day {
  background-color: var(--color-primary-light);
  color: var(--color-primary);
}

.badge-week-night {
  background-color: var(--color-secondary-light);
  color: var(--color-secondary);
}

.badge-weekend-day {
  background-color: var(--color-success-light);
  color: var(--color-success);
}

.badge-weekend-night {
  background-color: var(--color-warning-light);
  color: var(--color-warning);
}

.badge-default {
  background-color: var(--color-gray-100);
  color: var(--color-text-muted);
}

.department-stats {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
  padding-top: var(--spacing-md);
  border-top: 1px solid var(--color-border);
}

.stat-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.stat-label {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
  font-weight: 500;
}

.stat-value {
  font-size: var(--font-size-sm);
  color: var(--color-text-primary);
  font-weight: 500;
}

@media (max-width: 768px) {
  .department-header {
    flex-direction: column;
    gap: var(--spacing-md);
    align-items: stretch;
  }

  .department-meta {
    justify-content: flex-start;
  }

  .department-stats {
    gap: var(--spacing-xs);
  }

  .stat-item {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-xs);
  }
}
</style>
