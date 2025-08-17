<template>
  <div class="modal-overlay" @click.self="handleOverlayClick">
    <div 
      class="modal-container" 
      :class="[
        `modal-container--${size}`,
        { 'modal-container--full-height': fullHeight }
      ]"
    >
      <!-- Header -->
      <div class="modal-header" v-if="!hideHeader">
        <div class="modal-title-section">
          <h2 class="modal-title">{{ title }}</h2>
          <p v-if="subtitle" class="modal-subtitle">{{ subtitle }}</p>
        </div>
        
        <div class="modal-actions">
          <!-- Custom header actions slot -->
          <slot name="header-actions"></slot>
          
          <!-- Close button -->
          <button 
            v-if="!hideCloseButton"
            @click="handleClose" 
            class="modal-close-button"
            :aria-label="closeButtonLabel"
          >
            &times;
          </button>
        </div>
      </div>
      
      <!-- Body -->
      <div class="modal-body" :class="{ 'modal-body--no-padding': noPadding }">
        <slot></slot>
      </div>
      
      <!-- Footer -->
      <div class="modal-footer" v-if="$slots.footer">
        <slot name="footer"></slot>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted } from 'vue';

const props = defineProps({
  title: {
    type: String,
    default: ''
  },
  subtitle: {
    type: String,
    default: ''
  },
  size: {
    type: String,
    default: 'medium',
    validator: (value) => ['small', 'medium', 'large', 'extra-large'].includes(value)
  },
  fullHeight: {
    type: Boolean,
    default: false
  },
  hideHeader: {
    type: Boolean,
    default: false
  },
  hideCloseButton: {
    type: Boolean,
    default: false
  },
  closeOnOverlay: {
    type: Boolean,
    default: true
  },
  closeOnEscape: {
    type: Boolean,
    default: true
  },
  noPadding: {
    type: Boolean,
    default: false
  },
  closeButtonLabel: {
    type: String,
    default: 'Close modal'
  }
});

const emit = defineEmits(['close']);

const handleClose = () => {
  emit('close');
};

const handleOverlayClick = () => {
  if (props.closeOnOverlay) {
    handleClose();
  }
};

const handleEscapeKey = (event) => {
  if (event.key === 'Escape' && props.closeOnEscape) {
    handleClose();
  }
};

// Add escape key listener
onMounted(() => {
  if (props.closeOnEscape) {
    document.addEventListener('keydown', handleEscapeKey);
  }
});

onUnmounted(() => {
  if (props.closeOnEscape) {
    document.removeEventListener('keydown', handleEscapeKey);
  }
});
</script>

<style lang="scss" scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.modal-container {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  
  &--small {
    width: 100%;
    max-width: 400px;
  }
  
  &--medium {
    width: 100%;
    max-width: 600px;
  }
  
  &--large {
    width: 100%;
    max-width: 900px;
  }
  
  &--extra-large {
    width: 100%;
    max-width: 1200px;
  }
  
  &--full-height {
    height: 90vh;
  }
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 1.5rem;
  border-bottom: 1px solid #e0e0e0;
  flex-shrink: 0;
}

.modal-title-section {
  flex: 1;
  margin-right: 1rem;
}

.modal-title {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: #333;
}

.modal-subtitle {
  margin: 0.25rem 0 0 0;
  font-size: 0.875rem;
  color: #666;
}

.modal-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.modal-close-button {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  padding: 0.25rem;
  line-height: 1;
  color: #666;
  border-radius: 4px;
  transition: background-color 0.2s ease;
  
  &:hover {
    background-color: #f5f5f5;
    color: #333;
  }
  
  &:focus {
    outline: 2px solid #4285F4;
    outline-offset: 2px;
  }
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
  
  &--no-padding {
    padding: 0;
  }
}

.modal-footer {
  padding: 1rem 1.5rem;
  border-top: 1px solid #e0e0e0;
  background-color: #f9f9f9;
  flex-shrink: 0;
}

// Responsive adjustments
@media (max-width: 768px) {
  .modal-overlay {
    padding: 0.5rem;
  }
  
  .modal-container {
    max-height: 95vh;
    
    &--full-height {
      height: 95vh;
    }
  }
  
  .modal-header {
    padding: 1rem;
  }
  
  .modal-body {
    padding: 1rem;
  }
  
  .modal-footer {
    padding: 0.75rem 1rem;
  }
}
</style>
