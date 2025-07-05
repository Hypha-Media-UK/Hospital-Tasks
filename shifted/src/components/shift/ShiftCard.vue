<template>
  <div
    class="shift-card"
    :class="{ selected }"
    @click="$emit('view')"
  >
    <div class="shift-card-header">
      <div class="shift-info">
        <div class="shift-type">
          <component :is="shiftIcon" :size="20" class="shift-icon" />
          <span class="shift-type-name">{{ shiftTypeName }}</span>
        </div>
        <div class="shift-date">{{ formatDate(shift.start_time) }}</div>
      </div>

      <div class="shift-actions">
        <input
          type="checkbox"
          :checked="selected"
          @click.stop
          @change="$emit('select')"
          class="shift-checkbox"
        />
      </div>
    </div>

    <div class="shift-card-body">
      <div class="shift-detail">
        <span class="detail-label">Supervisor:</span>
        <span class="detail-value">
          {{ shift.supervisor ? `${shift.supervisor.first_name} ${shift.supervisor.last_name}` : 'Not assigned' }}
        </span>
      </div>

      <div class="shift-detail">
        <span class="detail-label">Status:</span>
        <span class="detail-value" :class="statusClass">{{ shiftStatus }}</span>
      </div>

      <div class="shift-detail">
        <span class="detail-label">Duration:</span>
        <span class="detail-value">{{ calculateDuration(shift.start_time) }}</span>
      </div>
    </div>

    <div class="shift-card-footer">
      <button class="btn-view" @click.stop="$emit('view')">
        View Details
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import DayShiftIcon from '../icons/DayShiftIcon.vue'
import NightShiftIcon from '../icons/NightShiftIcon.vue'

const props = defineProps({
  shift: {
    type: Object,
    required: true
  },
  selected: {
    type: Boolean,
    default: false
  }
})

defineEmits(['select', 'view'])

const shiftIcon = computed(() => {
  return props.shift.shift_type?.includes('night') ? NightShiftIcon : DayShiftIcon
})

const shiftTypeName = computed(() => {
  const type = props.shift.shift_type || ''
  if (type.includes('night')) {
    return type.includes('weekend') ? 'Weekend Night' : 'Weekday Night'
  } else {
    return type.includes('weekend') ? 'Weekend Day' : 'Weekday Day'
  }
})

const shiftStatus = computed(() => {
  // Simple status logic - can be enhanced
  if (props.shift.end_time) {
    return 'Completed'
  } else if (props.shift.start_time) {
    return 'Active'
  } else {
    return 'Scheduled'
  }
})

const statusClass = computed(() => {
  switch (shiftStatus.value) {
    case 'Active':
      return 'status-active'
    case 'Completed':
      return 'status-completed'
    case 'Scheduled':
      return 'status-scheduled'
    default:
      return ''
  }
})

const formatDate = (dateString) => {
  if (!dateString) return ''
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  })
}

const calculateDuration = (startTimeString) => {
  if (!startTimeString) return ''

  const startTime = new Date(startTimeString)
  const now = new Date()

  const diffMs = now - startTime
  const diffHrs = Math.floor(diffMs / (1000 * 60 * 60))
  const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60))

  if (diffHrs === 0) {
    return `${diffMins}m`
  } else if (diffMins === 0) {
    return `${diffHrs}h`
  } else {
    return `${diffHrs}h ${diffMins}m`
  }
}
</script>

<style scoped>
.shift-card {
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  padding: var(--spacing);
  cursor: pointer;
  transition: all 0.2s ease-in-out;
  box-shadow: var(--shadow-sm);
}

.shift-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
  border-color: var(--color-primary);
}

.shift-card.selected {
  border-color: var(--color-primary);
  background: rgba(59, 130, 246, 0.05);
}

.shift-card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: var(--spacing);
}

.shift-info {
  flex: 1;
}

.shift-type {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  margin-bottom: var(--spacing-xs);
}

.shift-icon {
  color: var(--color-primary);
}

.shift-type-name {
  font-weight: 600;
  color: var(--color-text);
}

.shift-date {
  font-size: 0.875rem;
  color: var(--color-text-light);
}

.shift-actions {
  display: flex;
  align-items: center;
}

.shift-checkbox {
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.shift-card-body {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing);
}

.shift-detail {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.875rem;
}

.detail-label {
  color: var(--color-text-light);
  font-weight: 500;
}

.detail-value {
  color: var(--color-text);
  font-weight: 500;
}

.status-active {
  color: var(--color-success);
}

.status-completed {
  color: var(--color-text-light);
}

.status-scheduled {
  color: var(--color-warning);
}

.shift-card-footer {
  border-top: 1px solid var(--color-border-light);
  padding-top: var(--spacing);
  text-align: right;
}

.btn-view {
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: var(--radius-sm);
  padding: var(--spacing-xs) var(--spacing);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s ease-in-out;
}

.btn-view:hover {
  background: var(--color-primary-dark);
}
</style>
