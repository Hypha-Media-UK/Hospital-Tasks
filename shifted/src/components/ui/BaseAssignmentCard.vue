<template>
  <div
    class="assignment-card"
    @click="$emit('edit')"
  >
    <div class="assignment-header">
      <h4>{{ title }}</h4>
      <div class="actions">
        <button
          class="action-btn edit-btn"
          @click.stop="$emit('edit')"
          title="Edit"
        >
          <EditIcon class="w-4 h-4" />
        </button>
        <button
          class="action-btn delete-btn"
          @click.stop="$emit('delete')"
          title="Delete"
        >
          <TrashIcon class="w-4 h-4" />
        </button>
      </div>
    </div>

    <div class="assignment-details">
      <div class="time-range">
        <strong>Time:</strong> {{ timeRange }}
      </div>

      <div v-if="minimumPorters" class="min-porters">
        <strong>Min Porters:</strong> {{ minimumPorters }}
      </div>

      <div v-if="porterAssignments.length > 0" class="porter-assignments">
        <strong>Porter Assignments:</strong>
        <div class="porter-list">
          <div
            v-for="porter in porterAssignments"
            :key="porter.id"
            class="porter-item"
          >
            <span class="porter-name">
              {{ porter.name }}
              <span v-if="porter.absenceBadge" class="absence-badge" :class="porter.absenceBadge.class">
                {{ porter.absenceBadge.text }}
              </span>
            </span>
            <span class="porter-time">{{ porter.timeRange }}</span>
          </div>
        </div>
      </div>

      <div class="coverage-status">
        <div class="status-indicator" :class="coverageStatusClass">
          <div class="status-dot"></div>
          <span class="status-text">{{ coverageStatus.text }}</span>
        </div>
      </div>
    </div>

    <!-- Slot for component-specific content (like color bar) -->
    <slot name="footer"></slot>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import EditIcon from '../icons/EditIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'

interface PorterAssignment {
  id: string
  name: string
  timeRange: string
  absenceBadge?: {
    text: string
    class: string
  }
}

interface CoverageStatus {
  type: 'covered' | 'gap' | 'shortage'
  text: string
}

interface Props {
  title: string
  timeRange: string
  minimumPorters?: number
  porterAssignments: PorterAssignment[]
  coverageStatus: CoverageStatus
}

interface Emits {
  (e: 'edit'): void
  (e: 'delete'): void
}

const props = defineProps<Props>()
defineEmits<Emits>()

const coverageStatusClass = computed(() => ({
  'status-covered': props.coverageStatus.type === 'covered',
  'status-gap': props.coverageStatus.type === 'gap',
  'status-shortage': props.coverageStatus.type === 'shortage'
}))
</script>

<style scoped>
.assignment-card {
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-lg);
  padding: var(--spacing-lg);
  transition: box-shadow 0.2s ease;
  cursor: pointer;
  position: relative;
}

.assignment-card:hover {
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.assignment-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-md);
}

.assignment-header h4 {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-text-primary);
}

.actions {
  display: flex;
  gap: var(--spacing-sm);
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

.assignment-details {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}

.time-range,
.min-porters {
  font-size: 0.875rem;
  color: var(--color-text-secondary);
}

.porter-assignments {
  font-size: 0.875rem;
  color: var(--color-text-secondary);
}

.porter-list {
  margin-top: var(--spacing-xs);
  display: flex;
  flex-direction: column;
  gap: var(--spacing-xs);
}

.porter-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-xs) var(--spacing-sm);
  background-color: var(--color-background-alt);
  border-radius: var(--radius-sm);
  font-size: 0.8rem;
}

.porter-name {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  color: var(--color-text-primary);
}

.porter-time {
  color: var(--color-text-secondary);
  font-size: 0.75rem;
}

.absence-badge {
  display: inline-block;
  font-size: 0.6rem;
  font-weight: 700;
  padding: 2px 4px;
  border-radius: 3px;
  text-transform: uppercase;
}

.absence-illness {
  background-color: var(--color-danger);
  color: white;
}

.absence-annual-leave {
  background-color: var(--color-warning);
  color: white;
}

.absence-other {
  background-color: var(--color-text-light);
  color: white;
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

/* Responsive design */
@media (max-width: 768px) {
  .assignment-header {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-sm);
  }

  .actions {
    align-self: flex-end;
  }

  .porter-item {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-xs);
  }

  .porter-time {
    font-size: 0.7rem;
  }
}
</style>
