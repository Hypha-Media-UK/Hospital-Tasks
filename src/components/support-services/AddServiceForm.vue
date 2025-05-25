<template>
  <div class="add-service-form">
    <button 
      v-if="!isAdding" 
      @click="startAdding" 
      class="btn btn--primary add-button"
    >
      <span class="icon">+</span> Add Support Service
    </button>
    
    <div v-else class="form-container">
      <h4>Add New Support Service</h4>
      
      <div class="form-group">
        <label for="newServiceName">Service Name</label>
        <input 
          id="newServiceName" 
          v-model="form.name" 
          type="text" 
          class="form-input"
          placeholder="Enter service name"
          required
        >
      </div>
      
      <div class="form-group">
        <label for="newServiceDescription">Description (optional)</label>
        <textarea 
          id="newServiceDescription" 
          v-model="form.description" 
          class="form-textarea"
          placeholder="Enter description"
          rows="3"
        ></textarea>
      </div>
      
      <div class="form-actions">
        <button 
          @click="cancelAdding" 
          class="btn btn--secondary"
        >
          Cancel
        </button>
        <button 
          @click="submitForm" 
          class="btn btn--primary"
          :disabled="!form.name || isSubmitting"
        >
          {{ isSubmitting ? 'Adding...' : 'Add Service' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue';

const emit = defineEmits(['add']);

const isAdding = ref(false);
const isSubmitting = ref(false);
const form = reactive({
  name: '',
  description: ''
});

function startAdding() {
  isAdding.value = true;
}

function cancelAdding() {
  isAdding.value = false;
  resetForm();
}

function resetForm() {
  form.name = '';
  form.description = '';
}

async function submitForm() {
  if (!form.name || isSubmitting.value) return;
  
  isSubmitting.value = true;
  
  try {
    await emit('add', {
      name: form.name,
      description: form.description || null
    });
    
    isAdding.value = false;
    resetForm();
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.add-service-form {
  margin-bottom: 24px;
  
  .add-button {
    display: flex;
    align-items: center;
    gap: 8px;
    
    .icon {
      font-size: 1.2rem;
    }
  }
  
  .form-container {
    background-color: #f9f9f9;
    border-radius: 8px;
    padding: 16px;
    border: 1px solid rgba(0, 0, 0, 0.1);
    
    h4 {
      margin-top: 0;
      margin-bottom: 16px;
    }
    
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
    }
  }
}

// Button styles (same as in ServiceItem.vue)
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
      background-color: color.scale(#4285F4, $lightness: -10%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: #333;
    
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
