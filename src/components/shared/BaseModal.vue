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

<!-- Styles are now handled by the global CSS layers -->