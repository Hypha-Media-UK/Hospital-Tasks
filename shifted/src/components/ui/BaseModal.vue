<template>
  <div class="modal-overlay" @click="handleOverlayClick">
    <div
      class="modal"
      :class="modalClasses"
      @click.stop
    >
      <div v-if="showHeader" class="modal-header">
        <h3 v-if="title" class="modal-title">{{ title }}</h3>
        <slot name="header" />
        <button
          v-if="showCloseButton"
          class="close-button"
          @click="$emit('close')"
          :aria-label="closeButtonLabel"
        >
          ×
        </button>
      </div>

      <div class="modal-body" :class="bodyClasses">
        <slot />
      </div>

      <div v-if="showFooter" class="modal-footer">
        <slot name="footer" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  title?: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  showHeader?: boolean
  showFooter?: boolean
  showCloseButton?: boolean
  closeOnOverlayClick?: boolean
  closeButtonLabel?: string
  bodyPadding?: boolean
}

interface Emits {
  (e: 'close'): void
}

const props = withDefaults(defineProps<Props>(), {
  size: 'md',
  showHeader: true,
  showFooter: false,
  showCloseButton: true,
  closeOnOverlayClick: true,
  closeButtonLabel: 'Close modal',
  bodyPadding: true
})

const emit = defineEmits<Emits>()

const modalClasses = computed(() => ({
  [`modal--${props.size}`]: true
}))

const bodyClasses = computed(() => ({
  'modal-body--no-padding': !props.bodyPadding
}))

const handleOverlayClick = () => {
  if (props.closeOnOverlayClick) {
    emit('close')
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: var(--spacing-md);
}

.modal {
  background: white;
  border-radius: var(--border-radius-lg);
  box-shadow: var(--shadow-lg);
  width: 100%;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* Modal sizes */
.modal--sm {
  max-width: 400px;
}

.modal--md {
  max-width: 500px;
}

.modal--lg {
  max-width: 700px;
}

.modal--xl {
  max-width: 900px;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-lg);
  border-bottom: 1px solid var(--color-border);
  background: var(--color-gray-50);
  flex-shrink: 0;
}

.modal-title {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--color-text-primary);
}

.close-button {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--color-text-secondary);
  padding: 0;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--border-radius-sm);
  transition: all 0.2s ease;
  flex-shrink: 0;
}

.close-button:hover {
  background: var(--color-gray-100);
  color: var(--color-text-primary);
}

.close-button:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary-alpha);
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: var(--spacing-lg);
}

.modal-body--no-padding {
  padding: 0;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: var(--spacing-sm);
  padding: var(--spacing-lg);
  border-top: 1px solid var(--color-border);
  background: var(--color-gray-50);
  flex-shrink: 0;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .modal-overlay {
    padding: var(--spacing-sm);
  }

  .modal {
    width: 100%;
    max-width: none;
    margin: 0;
  }

  .modal-header {
    padding: var(--spacing-md);
  }

  .modal-body {
    padding: var(--spacing-md);
  }

  .modal-footer {
    padding: var(--spacing-md);
    flex-direction: column-reverse;
  }

  .modal-footer > * {
    width: 100%;
  }
}

/* Animation */
.modal-overlay {
  animation: fadeIn 0.2s ease-out;
}

.modal {
  animation: slideIn 0.2s ease-out;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-20px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}
</style>
