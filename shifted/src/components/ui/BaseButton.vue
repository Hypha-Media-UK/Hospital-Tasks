<template>
  <button
    :class="buttonClasses"
    :disabled="disabled || loading"
    :type="type"
    @click="handleClick"
  >
    <span v-if="loading" class="button-spinner"></span>
    <component v-if="icon && !loading" :is="icon" :size="iconSize" />
    <span v-if="$slots.default" :class="{ 'ml-2': icon && !loading }">
      <slot />
    </span>
  </button>
</template>

<script setup lang="ts">
import { computed, useSlots } from 'vue'

interface Props {
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  loading?: boolean
  type?: 'button' | 'submit' | 'reset'
  icon?: any
  iconSize?: number | string
}

interface Emits {
  click: [event: MouseEvent]
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  size: 'md',
  disabled: false,
  loading: false,
  type: 'button',
  iconSize: 16
})

const emit = defineEmits<Emits>()
const slots = useSlots()

const buttonClasses = computed(() => [
  'base-button',
  `base-button--${props.variant}`,
  `base-button--${props.size}`,
  {
    'base-button--disabled': props.disabled || props.loading,
    'base-button--loading': props.loading,
    'base-button--icon-only': props.icon && !slots.default
  }
])

const handleClick = (event: MouseEvent) => {
  if (!props.disabled && !props.loading) {
    emit('click', event)
  }
}
</script>

<style scoped>
.base-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  border: none;
  border-radius: 0.375rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
  position: relative;
  white-space: nowrap;
}

/* Sizes */
.base-button--sm {
  padding: 0.375rem 0.75rem;
  font-size: 0.875rem;
  line-height: 1.25rem;
}

.base-button--md {
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  line-height: 1.25rem;
}

.base-button--lg {
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
  line-height: 1.5rem;
}

.base-button--icon-only {
  padding: 0.5rem;
}

.base-button--icon-only.base-button--sm {
  padding: 0.375rem;
}

.base-button--icon-only.base-button--lg {
  padding: 0.75rem;
}

/* Variants */
.base-button--primary {
  background-color: #4285f4;
  color: white;
}

.base-button--primary:hover:not(.base-button--disabled) {
  background-color: #3367d6;
}

.base-button--secondary {
  background-color: #f8fafc;
  color: #334155;
  border: 1px solid #e2e8f0;
}

.base-button--secondary:hover:not(.base-button--disabled) {
  background-color: #f1f5f9;
  border-color: #cbd5e1;
}

.base-button--danger {
  background-color: #dc3545;
  color: white;
}

.base-button--danger:hover:not(.base-button--disabled) {
  background-color: #c82333;
}

.base-button--ghost {
  background-color: transparent;
  color: #64748b;
}

.base-button--ghost:hover:not(.base-button--disabled) {
  background-color: #f1f5f9;
  color: #334155;
}

/* States */
.base-button--disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.base-button--loading {
  cursor: wait;
}

/* Spinner */
.button-spinner {
  width: 1rem;
  height: 1rem;
  border: 2px solid transparent;
  border-top: 2px solid currentColor;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* Utility classes */
.ml-2 {
  margin-left: 0.5rem;
}
</style>
