<template>
  <div class="day-porter-requirements">
    <BaseFormField label="Minimum Porter Count by Day">
      <div class="day-toggle">
        <label class="toggle-label">
          <input
            type="checkbox"
            :checked="useSameForAllDays"
            @change="handleSameForAllDaysChange"
          />
          <span class="toggle-text">Same for all days</span>
        </label>
      </div>

      <div v-if="useSameForAllDays" class="single-input-wrapper">
        <div class="min-porters-input">
          <input
            type="number"
            :value="sameForAllDaysValue"
            @input="handleSameValueChange"
            min="0"
            class="number-input"
          />
          <div class="min-porters-description">
            Minimum number of porters required for all days
          </div>
        </div>
      </div>

      <div v-else class="days-grid">
        <div v-for="(day, index) in days" :key="day.code" class="day-input">
          <label :for="`min-porters-${day.code}`">{{ day.code }}</label>
          <input
            type="number"
            :id="`min-porters-${day.code}`"
            :value="dayValues[index]"
            @input="(event) => handleDayValueChange(index, event)"
            min="0"
            class="number-input day-input"
          />
        </div>
      </div>
    </BaseFormField>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import BaseFormField from './BaseFormField.vue'

interface DayRequirement {
  code: string
  name: string
  field: string
}

interface Props {
  modelValue: number[]
  disabled?: boolean
}

interface Emits {
  (e: 'update:modelValue', value: number[]): void
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false
})

const emit = defineEmits<Emits>()

const days: DayRequirement[] = [
  { code: 'Mo', name: 'Monday', field: 'minimum_porters_mon' },
  { code: 'Tu', name: 'Tuesday', field: 'minimum_porters_tue' },
  { code: 'We', name: 'Wednesday', field: 'minimum_porters_wed' },
  { code: 'Th', name: 'Thursday', field: 'minimum_porters_thu' },
  { code: 'Fr', name: 'Friday', field: 'minimum_porters_fri' },
  { code: 'Sa', name: 'Saturday', field: 'minimum_porters_sat' },
  { code: 'Su', name: 'Sunday', field: 'minimum_porters_sun' }
]

const dayValues = ref<number[]>([...props.modelValue])
const useSameForAllDays = ref(true)
const sameForAllDaysValue = ref(1)

// Initialize state
const initializeState = () => {
  dayValues.value = [...props.modelValue]

  // Check if all days have the same value
  const allSameValue = dayValues.value.every(val => val === dayValues.value[0])
  useSameForAllDays.value = allSameValue

  if (allSameValue) {
    sameForAllDaysValue.value = dayValues.value[0] || 1
  }
}

// Watch for external changes to modelValue
watch(() => props.modelValue, () => {
  initializeState()
}, { immediate: true })

const handleSameForAllDaysChange = (event: Event) => {
  const target = event.target as HTMLInputElement
  useSameForAllDays.value = target.checked

  if (useSameForAllDays.value) {
    // When toggling to "same for all days", use the first day's value
    sameForAllDaysValue.value = dayValues.value[0] || 1
    applySameValueToAllDays()
  }
}

const handleSameValueChange = (event: Event) => {
  const target = event.target as HTMLInputElement
  sameForAllDaysValue.value = parseInt(target.value) || 0
  applySameValueToAllDays()
}

const handleDayValueChange = (index: number, event: Event) => {
  const target = event.target as HTMLInputElement
  const newValue = parseInt(target.value) || 0

  dayValues.value[index] = newValue
  emit('update:modelValue', [...dayValues.value])
}

const applySameValueToAllDays = () => {
  if (useSameForAllDays.value) {
    dayValues.value = Array(7).fill(sameForAllDaysValue.value)
    emit('update:modelValue', [...dayValues.value])
  }
}
</script>

<style scoped>
.day-porter-requirements {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}

.day-toggle {
  margin-bottom: var(--spacing-sm);
}

.toggle-label {
  display: flex;
  align-items: center;
  cursor: pointer;
  font-size: var(--font-size-sm);
}

.toggle-text {
  margin-left: var(--spacing-sm);
}

.single-input-wrapper {
  margin-top: var(--spacing-sm);
}

.min-porters-input {
  display: flex;
  align-items: center;
  gap: var(--spacing-md);
}

.min-porters-description {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
}

.days-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: var(--spacing-sm);
  margin-top: var(--spacing-sm);
}

@media (max-width: 600px) {
  .days-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

@media (max-width: 400px) {
  .days-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

.day-input {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--spacing-xs);
}

.day-input label {
  font-weight: 500;
  font-size: var(--font-size-sm);
  color: var(--color-text-secondary);
}

.number-input {
  width: 100%;
  padding: var(--spacing-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  font-size: var(--font-size-md);
  text-align: center;
  transition: border-color 0.2s ease;
}

.number-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-alpha);
}

.day-input .number-input {
  max-width: 60px;
}

.single-input-wrapper .number-input {
  width: 80px;
}
</style>
