<template>
  <div class="modal-overlay" @click.stop="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">Edit Service</h3>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
        <div class="form-group">
          <label for="edit-name">Service Name</label>
          <input 
            type="text"
            id="edit-name"
            v-model="editForm.name"
            class="form-control"
            required
          />
        </div>
        
        <div class="form-group">
          <label for="edit-description">Description</label>
          <textarea
            id="edit-description"
            v-model="editForm.description"
            class="form-control"
            rows="3"
          ></textarea>
        </div>
      </div>
      
      <div class="modal-footer">
        <div class="modal-footer-left">
          <button 
            class="btn btn-danger" 
            @click.stop="confirmDelete"
          >
            Delete Service
          </button>
        </div>
        <div class="modal-footer-right">
          <button 
            @click.stop="$emit('close')" 
            class="btn btn-secondary"
          >
            Cancel
          </button>
          <button 
            @click.stop="saveChanges" 
            class="btn btn-primary"
            :disabled="saving || !editForm.name.trim()"
          >
            {{ saving ? 'Saving...' : 'Save Changes' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';

const props = defineProps({
  service: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['close', 'update', 'delete']);

// Form state
const editForm = ref({
  name: '',
  description: ''
});
const saving = ref(false);

// Initialize form with service data
onMounted(() => {
  editForm.value = {
    name: props.service.name || '',
    description: props.service.description || ''
  };
});

// Save changes
async function saveChanges() {
  if (!editForm.value.name.trim() || saving.value) return;
  
  saving.value = true;
  
  try {
    // Prepare update object
    const updatedService = {
      id: props.service.id,
      name: editForm.value.name.trim(),
      description: editForm.value.description || null
    };
    
    // Emit update event
    emit('update', updatedService);
  } catch (error) {
    console.error('Error saving service:', error);
  } finally {
    saving.value = false;
  }
}

// Delete service
function confirmDelete() {
  if (confirm(`Are you sure you want to delete "${props.service.name}"?`)) {
    emit('delete', props.service.id);
  }
}
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

// Modal styles
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-container {
  background-color: white;
  border-radius: mix.radius('lg');
  width: 90%;
  max-width: 550px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.modal-header {
  padding: 16px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  margin: 0;
  font-size: mix.font-size('lg');
  font-weight: 600;
}

.modal-close {
  background: transparent;
  border: none;
  font-size: 24px;
  cursor: pointer;
  padding: 0;
  line-height: 1;
}

.modal-body {
  padding: 16px;
  overflow-y: auto;
  flex: 1;
}

.modal-footer {
  padding: 16px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  display: flex;
  justify-content: space-between;
  
  &-left {
    display: flex;
    gap: 12px;
  }
  
  &-right {
    display: flex;
    gap: 12px;
  }
}

.form-group {
  margin-bottom: 16px;
  
  label {
    display: block;
    margin-bottom: 8px;
    font-weight: 500;
  }
  
  .form-control {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(mix.color('primary'), 0.2);
    }
  }
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &.btn-primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
  }
  
  &.btn-secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: color.scale(#f1f1f1, $lightness: -5%);
    }
  }
  
  &.btn-danger {
    background-color: #dc3545;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#dc3545, $lightness: -10%);
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
