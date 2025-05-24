<template>
  <div class="service-item" :class="{ 'is-editing': isEditing }">
    <!-- View Mode -->
    <div v-if="!isEditing" class="service-item__view">
      <div class="service-details">
        <div class="service-name">{{ service.name }}</div>
      </div>
      
      <div class="service-actions">
        <button 
          @click="startEdit" 
          class="btn btn--icon" 
          title="Edit service"
        >
          <EditIcon />
        </button>
        <button 
          @click="confirmDelete" 
          class="btn btn--icon btn--danger" 
          title="Delete service"
        >
          <TrashIcon />
        </button>
      </div>
    </div>
    
    <!-- Edit Mode -->
    <div v-else class="service-item__edit">
      <div class="form-group">
        <label for="serviceName">Service Name</label>
        <input 
          id="serviceName" 
          v-model="editForm.name" 
          type="text" 
          class="form-input"
          placeholder="Enter service name"
          required
        >
      </div>
      
      <div class="form-group">
        <label for="serviceDescription">Description (optional)</label>
        <textarea 
          id="serviceDescription" 
          v-model="editForm.description" 
          class="form-textarea"
          placeholder="Enter description"
          rows="3"
        ></textarea>
      </div>
      
      <div class="form-actions">
        <button 
          @click="cancelEdit" 
          class="btn btn--secondary"
        >
          Cancel
        </button>
        <button 
          @click="saveEdit" 
          class="btn btn--primary"
          :disabled="!editForm.name"
        >
          Save
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue';
import EditIcon from '../icons/EditIcon.vue';
import TrashIcon from '../icons/TrashIcon.vue';

const props = defineProps({
  service: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['update', 'delete']);

const isEditing = ref(false);
const editForm = reactive({
  name: '',
  description: ''
});

function startEdit() {
  editForm.name = props.service.name;
  editForm.description = props.service.description || '';
  isEditing.value = true;
}

function cancelEdit() {
  isEditing.value = false;
}

function saveEdit() {
  if (!editForm.name) return;
  
  emit('update', {
    id: props.service.id,
    name: editForm.name,
    description: editForm.description || null,
    is_active: props.service.is_active
  });
  
  isEditing.value = false;
}

function confirmDelete() {
  if (confirm(`Are you sure you want to delete the "${props.service.name}" service?`)) {
    emit('delete', props.service.id);
  }
}
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.service-item {
  padding: 16px;
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.1);
  background-color: #fff;
  transition: box-shadow 0.2s;
  
  &:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  }
  
  &.is-editing {
    border-color: #4285F4;
    box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
  }
  
  &__view {
    display: flex;
    justify-content: space-between;
    
    .service-details {
      flex: 1;
    }
    
    .service-name {
      font-weight: 600;
    }
    
    .service-description {
      font-size: 0.9rem;
      color: rgba(0, 0, 0, 0.7);
    }
    
    .service-actions {
      display: flex;
      gap: 8px;
      align-items: flex-start;
    }
  }
  
  &__edit {
    .form-group {
      margin-bottom: 16px;
      
      label {
        display: block;
        margin-bottom: 4px;
        font-weight: 500;
        font-size: 0.9rem;
      }
      
      .form-input, .form-textarea {
        width: 100%;
        padding: 8px;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: 4px;
        font-size: 1rem;
        
        &:focus {
          outline: none;
          border-color: #4285F4;
          box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
        }
      }
    }
    
    .form-actions {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
      margin-top: 16px;
    }
  }
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s;
  
  &--primary {
    background-color: #4285F4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: darken(#4285F4, 10%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: #333;
    
    &:hover:not(:disabled) {
      background-color: darken(#f1f1f1, 5%);
    }
  }
  
  &--danger {
    color: #EA4335;
    
    &:hover:not(:disabled) {
      background-color: rgba(234, 67, 53, 0.1);
    }
  }
  
  &--icon {
    padding: 6px;
    background: transparent;
    line-height: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
