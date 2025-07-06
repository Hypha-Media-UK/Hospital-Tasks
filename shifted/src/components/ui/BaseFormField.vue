<template>
  <div class="form-field" :class="{ 'form-field--half': half }">
    <label v-if="label" :for="id" class="form-label">
      {{ label }}
      <span v-if="required" class="required-indicator">*</span>
    </label>

    <!-- Text Input -->
    <input
      v-if="type === 'text' || type === 'email' || type === 'password' || type === 'time' || type === 'date'"
      :id="id"
      :type="type"
      :value="modelValue"
      :placeholder="placeholder"
      :required="required"
      :disabled="disabled"
      :min="min"
      :max="max"
      class="form-control"
      @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value)"
      @blur="$emit('blur')"
      @focus="$emit('focus')"
    />

    <!-- Select -->
    <select
      v-else-if="type === 'select'"
      :id="id"
      :value="modelValue"
      :required="required"
      :disabled="disabled"
      class="form-control"
      @change="$emit('update:modelValue', ($event.target as HTMLSelectElement).value)"
    >
      <option v-if="placeholder" value="">{{ placeholder }}</option>
      <option
        v-for="option in options"
        :key="typeof option === 'string' ? option : option.value"
        :value="typeof option === 'string' ? option : option.value"
      >
        {{ typeof option === 'string' ? option : option.label }}
      </option>
    </select>

    <!-- Textarea -->
    <textarea
      v-else-if="type === 'textarea'"
      :id="id"
      :value="modelValue as string"
      :placeholder="placeholder"
      :required="required"
      :disabled="disabled"
      :rows="rows"
      class="form-control form-control--textarea"
      @input="$emit('update:modelValue', ($event.target as HTMLTextAreaElement).value)"
    ></textarea>

    <!-- Checkbox -->
    <div v-else-if="type === 'checkbox'" class="checkbox-container">
      <input
        :id="id"
        type="checkbox"
        :checked="modelValue as boolean"
        :disabled="disabled"
        class="form-checkbox"
        @change="$emit('update:modelValue', ($event.target as HTMLInputElement).checked)"
      />
      <label v-if="label" :for="id" class="checkbox-label">{{ label }}</label>
    </div>

    <div v-if="error" class="form-error">{{ error }}</div>
    <div v-if="hint" class="form-hint">{{ hint }}</div>
  </div>
</template>

<script setup lang="ts">
interface Option {
  value: string | number
  label: string
}

interface Props {
  id?: string
  label?: string
  type?: 'text' | 'email' | 'password' | 'time' | 'date' | 'select' | 'textarea' | 'checkbox'
  modelValue?: string | number | boolean
  placeholder?: string
  required?: boolean
  disabled?: boolean
  half?: boolean
  min?: string
  max?: string
  rows?: number
  options?: (string | Option)[]
  error?: string
  hint?: string
}

const props = withDefaults(defineProps<Props>(), {
  type: 'text',
  rows: 3
})

defineEmits<{
  'update:modelValue': [value: string | number | boolean]
  blur: []
  focus: []
}>()
</script>

<style scoped>
.form-field {
  margin-bottom: var(--spacing);
}

.form-field--half {
  flex: 1;
  min-width: 120px;
}

.form-label {
  display: block;
  margin-bottom: var(--spacing-xs);
  font-weight: 500;
  color: var(--color-text);
  font-size: 0.875rem;
}

.required-indicator {
  color: var(--color-danger, #dc2626);
  margin-left: 2px;
}

.form-control {
  width: 100%;
  padding: var(--spacing-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  font-size: 0.875rem;
  transition: all 0.2s ease;
  background-color: var(--color-background);
}

.form-control:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-light);
}

.form-control:disabled {
  background-color: var(--color-background-alt);
  color: var(--color-text-light);
  cursor: not-allowed;
}

.form-control--textarea {
  resize: vertical;
  min-height: 80px;
}

.checkbox-container {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.form-checkbox {
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.checkbox-label {
  margin-bottom: 0;
  cursor: pointer;
  font-weight: normal;
}

.form-error {
  margin-top: var(--spacing-xs);
  font-size: 0.75rem;
  color: var(--color-danger, #dc2626);
}

.form-hint {
  margin-top: var(--spacing-xs);
  font-size: 0.75rem;
  color: var(--color-text-light);
}
</style>
