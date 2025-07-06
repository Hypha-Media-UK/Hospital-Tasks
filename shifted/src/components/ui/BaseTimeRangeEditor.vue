<template>
  <div class="time-range-editor">
    <BaseFormRow>
      <BaseFormField
        label="Start Time"
        :required="required"
      >
        <input
          type="time"
          :value="startTime"
          @input="updateStartTime"
          class="time-input"
          :disabled="disabled"
        />
      </BaseFormField>

      <BaseFormField
        label="End Time"
        :required="required"
      >
        <input
          type="time"
          :value="endTime"
          @input="updateEndTime"
          class="time-input"
          :disabled="disabled"
        />
      </BaseFormField>
    </BaseFormRow>

    <div v-if="validationError" class="validation-error">
      {{ validationError }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import BaseFormField from './BaseFormField.vue'
import BaseFormRow from './BaseFormRow.vue'

interface Props {
  startTime: string
  endTime: string
  required?: boolean
  disabled?: boolean
  validateRange?: boolean
}

interface Emits {
  (e: 'update:startTime', value: string): void
  (e: 'update:endTime', value: string): void
}

const props = withDefaults(defineProps<Props>(), {
  required: false,
  disabled: false,
  validateRange: true
})

const emit = defineEmits<Emits>()

const updateStartTime = (event: Event) => {
  const target = event.target as HTMLInputElement
  emit('update:startTime', target.value)
}

const updateEndTime = (event: Event) => {
  const target = event.target as HTMLInputElement
  emit('update:endTime', target.value)
}

const validationError = computed(() => {
  if (!props.validateRange || !props.startTime || !props.endTime) {
    return null
  }

  const start = timeToMinutes(props.startTime)
  const end = timeToMinutes(props.endTime)

  if (end <= start) {
    return 'End time must be after start time'
  }

  return null
})

// Helper function to convert time string (HH:MM) to minutes
const timeToMinutes = (timeStr: string): number => {
  if (!timeStr) return 0
  const [hours, minutes] = timeStr.split(':').map(Number)
  return (hours * 60) + minutes
}
</script>

<style scoped>
.time-range-editor {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}

.time-input {
  width: 100%;
  padding: var(--spacing-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  font-size: var(--font-size-md);
  transition: border-color 0.2s ease;
}

.time-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-alpha);
}

.time-input:disabled {
  background-color: var(--color-gray-50);
  cursor: not-allowed;
}

.validation-error {
  color: var(--color-error);
  font-size: var(--font-size-sm);
  margin-top: var(--spacing-xs);
}
</style>
