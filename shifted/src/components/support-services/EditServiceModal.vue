<template>
  <div class="modal-overlay" @click="$emit('close')">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <h3>Edit Support Service</h3>
        <button class="close-btn" @click="$emit('close')">×</button>
      </div>
      <div class="modal-body">
        <p>Edit Service Modal - Coming Soon</p>
        <p>Service: {{ assignment.service?.name }}</p>
        <p>Shift Type: {{ assignment.shift_type }}</p>
      </div>
      <div class="modal-footer">
        <BaseButton variant="secondary" @click="$emit('close')">Cancel</BaseButton>
        <BaseButton variant="primary" @click="$emit('saved')">Save</BaseButton>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import BaseButton from '../ui/BaseButton.vue'
import type { ServiceAssignment } from '../../types/supportServices'

interface Props {
  assignment: ServiceAssignment
}

interface Emits {
  (e: 'close'): void
  (e: 'saved'): void
}

defineProps<Props>()
defineEmits<Emits>()
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
}

.modal-content {
  background: var(--color-background);
  border-radius: var(--radius-lg);
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
  max-width: 500px;
  width: 90%;
  max-height: 90vh;
  overflow: hidden;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-lg);
  border-bottom: 1px solid var(--color-border);
}

.modal-header h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--color-text-light);
  padding: 0;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--radius);
}

.close-btn:hover {
  background: var(--color-background-alt);
  color: var(--color-text);
}

.modal-body {
  padding: var(--spacing-lg);
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: var(--spacing);
  padding: var(--spacing-lg);
  border-top: 1px solid var(--color-border);
}
</style>
