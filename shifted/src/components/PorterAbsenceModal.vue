<template>
  <BaseModal
    title="Porter Absence Details"
    size="md"
    show-footer
    @close="$emit('close')"
  >
    <div class="porter-absence-content">
      <div v-if="absence" class="absence-details">
        <div class="absence-info">
          <h4>Current Absence</h4>
          <div class="absence-item">
            <span class="label">Type:</span>
            <span class="value" :class="absenceTypeClass">{{ absenceTypeLabel }}</span>
          </div>
          <div class="absence-item">
            <span class="label">Start Date:</span>
            <span class="value">{{ formatDate(absence.start_date) }}</span>
          </div>
          <div class="absence-item">
            <span class="label">End Date:</span>
            <span class="value">{{ formatDate(absence.end_date) }}</span>
          </div>
          <div v-if="absence.reason" class="absence-item">
            <span class="label">Reason:</span>
            <span class="value">{{ absence.reason }}</span>
          </div>
          <div v-if="absence.notes" class="absence-item">
            <span class="label">Notes:</span>
            <span class="value">{{ absence.notes }}</span>
          </div>
        </div>
      </div>

      <div v-else class="no-absence">
        <p>No current absence recorded for this porter.</p>
      </div>
    </div>

    <template #footer>
      <BaseButton variant="secondary" @click="$emit('close')">
        Close
      </BaseButton>
      <BaseButton variant="primary" @click="$emit('save')">
        Update Absence
      </BaseButton>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import BaseModal from './ui/BaseModal.vue'
import BaseButton from './ui/BaseButton.vue'
import type { PorterAbsence } from '../types/staff'

interface Props {
  porterId: string
  absence: PorterAbsence | null
}

interface Emits {
  (e: 'close'): void
  (e: 'save'): void
}

const props = defineProps<Props>()
defineEmits<Emits>()

const absenceTypeLabel = computed(() => {
  if (!props.absence) return ''

  switch (props.absence.absence_type) {
    case 'illness': return 'Illness'
    case 'annual_leave': return 'Annual Leave'
    default: return props.absence.absence_type
  }
})

const absenceTypeClass = computed(() => {
  if (!props.absence) return ''

  switch (props.absence.absence_type) {
    case 'illness': return 'type-illness'
    case 'annual_leave': return 'type-annual-leave'
    default: return 'type-other'
  }
})

const formatDate = (dateString: string): string => {
  return new Date(dateString).toLocaleDateString()
}
</script>

<style scoped>
.porter-absence-content {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.absence-details h4 {
  margin: 0 0 var(--spacing-md) 0;
  color: var(--color-text-primary);
}

.absence-info {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}

.absence-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-sm) 0;
  border-bottom: 1px solid var(--color-border);
}

.absence-item:last-child {
  border-bottom: none;
}

.label {
  font-weight: 500;
  color: var(--color-text-muted);
}

.value {
  font-weight: 500;
  color: var(--color-text-primary);
}

.value.type-illness {
  color: var(--color-error);
}

.value.type-annual-leave {
  color: var(--color-warning);
}

.value.type-other {
  color: var(--color-text-muted);
}

.no-absence {
  padding: var(--spacing-xl);
  text-align: center;
  color: var(--color-text-muted);
  background-color: var(--color-gray-25);
  border-radius: var(--border-radius-md);
}

.no-absence p {
  margin: 0;
}
</style>
