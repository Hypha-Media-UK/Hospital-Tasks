<template>
  <div class="service-info">
    <BaseCard>
      <div class="service-header">
        <div class="service-details">
          <h3 class="service-name">{{ assignment.service?.name || 'Unknown Service' }}</h3>
          <p v-if="assignment.service?.description" class="service-description">
            {{ assignment.service.description }}
          </p>
        </div>

        <div class="service-meta">
          <div class="service-type-badge">
            Support Service
          </div>
        </div>
      </div>

      <div v-if="assignment.service" class="service-stats">
        <div class="stat-item">
          <span class="stat-label">Service ID:</span>
          <span class="stat-value">{{ assignment.service.id }}</span>
        </div>

        <div class="stat-item">
          <span class="stat-label">Assignment ID:</span>
          <span class="stat-value">{{ assignment.id }}</span>
        </div>

        <div v-if="assignment.minimum_porters" class="stat-item">
          <span class="stat-label">Minimum Porters:</span>
          <span class="stat-value">{{ assignment.minimum_porters }}</span>
        </div>

        <div class="stat-item">
          <span class="stat-label">Coverage Time:</span>
          <span class="stat-value">{{ formatTimeRange(assignment.start_time, assignment.end_time) }}</span>
        </div>
      </div>
    </BaseCard>
  </div>
</template>

<script setup lang="ts">
import BaseCard from '../ui/BaseCard.vue'
import type { ServiceAssignment } from '../../types/supportServices'

interface Props {
  assignment: ServiceAssignment
}

const props = defineProps<Props>()

// Helper function to format time range
const formatTimeRange = (startTime: string, endTime: string): string => {
  const formatTime = (time: string) => {
    if (!time) return ''
    const [hours, minutes] = time.split(':')
    return `${hours}:${minutes}`
  }
  return `${formatTime(startTime)} - ${formatTime(endTime)}`
}
</script>

<style scoped>
.service-info {
  margin-bottom: var(--spacing-lg);
}

.service-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: var(--spacing-md);
}

.service-details {
  flex: 1;
}

.service-name {
  margin: 0 0 var(--spacing-xs) 0;
  font-size: var(--font-size-xl);
  font-weight: 600;
  color: var(--color-text-primary);
}

.service-description {
  margin: 0;
  font-size: var(--font-size-md);
  color: var(--color-text-muted);
  line-height: 1.5;
}

.service-meta {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.service-type-badge {
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--border-radius-full);
  font-size: var(--font-size-sm);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  background-color: var(--color-success-light);
  color: var(--color-success);
}

.service-stats {
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
  .service-header {
    flex-direction: column;
    gap: var(--spacing-md);
    align-items: stretch;
  }

  .service-meta {
    justify-content: flex-start;
  }

  .service-stats {
    gap: var(--spacing-xs);
  }

  .stat-item {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-xs);
  }
}
</style>
