<template>
  <div class="service-item">
    <div class="service-details">
      <h3 class="service-name">{{ service.name }}</h3>
      
      <div v-if="service.description" class="service-description">
        {{ service.description }}
      </div>
      
      <div class="service-status" :class="{ 'status-active': service.is_active, 'status-inactive': !service.is_active }">
        {{ service.is_active ? 'Active' : 'Inactive' }}
      </div>
    </div>
    
    <div class="service-actions">
      <button @click="openEditModal" class="btn-edit" title="Edit service">
        <span class="icon">✏️</span>
      </button>
      <button @click="confirmDelete" class="btn-delete" title="Delete service">
        <span class="icon">🗑️</span>
      </button>
    </div>
    
    <!-- Edit Modal -->
    <div v-if="showEditModal" class="modal-overlay" @click.self="showEditModal = false">
      <div class="modal-container">
        <div class="modal-header">
          <h3 class="modal-title">Edit Service</h3>
          <button @click="showEditModal = false" class="modal-close">&times;</button>
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
          
          <div class="form-group">
            <label class="checkbox-label">
              <input 
                type="checkbox"
                v-model="editForm.is_active"
              />
              <span class="checkbox-text">Active</span>
            </label>
          </div>
        </div>
        
        <div class="modal-footer">
          <button 
            @click="saveChanges" 
            class="btn btn-primary"
            :disabled="saving"
          >
            {{ saving ? 'Saving...' : 'Save Changes' }}
          </button>
          <button 
            @click="showEditModal = false" 
            class="btn btn-secondary"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';

// Props and emits
const props = defineProps({
  service: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['update', 'delete']);

// Edit modal state
const showEditModal = ref(false);
const editForm = ref({
  name: '',
  description: '',
  is_active: true
});
const saving = ref(false);

// Methods
function openEditModal() {
  // Initialize form with current service data
  editForm.value = {
    name: props.service.name,
    description: props.service.description || '',
    is_active: props.service.is_active
  };
  
  showEditModal.value = true;
}

async function saveChanges() {
  if (!editForm.value.name || saving.value) return;
  
  saving.value = true;
  
  try {
    // Prepare update object
    const updatedService = {
      id: props.service.id,
      name: editForm.value.name,
      description: editForm.value.description || null,
      is_active: editForm.value.is_active
    };
    
    // Emit update event
    await emit('update', updatedService);
    
    // Close modal
    showEditModal.value = false;
  } catch (error) {
    console.error('Error saving service:', error);
  } finally {
    saving.value = false;
  }
}

function confirmDelete() {
  if (confirm(`Are you sure you want to delete ${props.service.name}?`)) {
    emit('delete', props.service.id);
  }
}
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.service-item {
  background-color: white;
  border-radius: mix.radius('md');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  padding: 16px;
  display: flex;
  
  .service-details {
    flex: 1;
  }
  
  .service-name {
    margin-top: 0;
    margin-bottom: 8px;
    font-size: mix.font-size('md');
    font-weight: 600;
  }
  
  .service-description {
    margin-bottom: 12px;
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.7);
  }
  
  .service-status {
    display: inline-block;
    padding: 4px 8px;
    border-radius: mix.radius('sm');
    font-size: mix.font-size('xs');
    font-weight: 500;
    
    &.status-active {
      background-color: rgba(52, 168, 83, 0.1);
      color: #34A853;
    }
    
    &.status-inactive {
      background-color: rgba(234, 67, 53, 0.1);
      color: #EA4335;
    }
  }
  
  .service-actions {
    display: flex;
    flex-direction: column;
    gap: 8px;
    
    button {
      background: none;
      border: none;
      cursor: pointer;
      padding: 6px;
      border-radius: mix.radius('sm');
      
      .icon {
        font-size: 16px;
      }
      
      &.btn-edit:hover {
        background-color: rgba(0, 0, 0, 0.05);
      }
      
      &.btn-delete:hover {
        background-color: rgba(234, 67, 53, 0.1);
      }
    }
  }
}

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
  max-width: 500px;
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
  justify-content: flex-end;
  gap: 12px;
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
  
  .checkbox-label {
    display: flex;
    align-items: center;
    cursor: pointer;
    
    input[type="checkbox"] {
      margin-right: 8px;
    }
    
    .checkbox-text {
      font-weight: 500;
    }
  }
}

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
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
