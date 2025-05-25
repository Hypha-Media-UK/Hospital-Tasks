<template>
  <div class="add-service-form">
    <form @submit.prevent="submitForm">
      <div class="form-header">
        <h4>Add Support Service</h4>
      </div>
      
      <div class="form-content">
        <div class="form-group">
          <label for="name">Service Name</label>
          <input 
            type="text"
            id="name"
            v-model="formData.name"
            class="form-control"
            placeholder="Enter service name"
            required
          />
        </div>
        
        <div class="form-group">
          <label for="description">Description</label>
          <textarea
            id="description"
            v-model="formData.description"
            class="form-control"
            placeholder="Enter service description"
            rows="3"
          ></textarea>
        </div>
      </div>
      
      <div class="form-actions">
        <button 
          type="submit" 
          class="btn-add"
          :disabled="submitting || !formData.name"
        >
          <span v-if="submitting">Adding...</span>
          <span v-else>Add Service</span>
        </button>
      </div>
    </form>
    
    <div v-if="error" class="error-message">
      {{ error }}
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';

// Props and emits
const emit = defineEmits(['add']);

// Form state
const formData = ref({
  name: '',
  description: ''
});
const submitting = ref(false);
const error = ref('');

// Form submission
async function submitForm() {
  if (!formData.value.name || submitting.value) return;
  
  submitting.value = true;
  error.value = '';
  
  try {
    // Emit the add event with the form data
    const result = await emit('add', {
      name: formData.value.name,
      description: formData.value.description || null
    });
    
    // Reset form if successful
    if (result !== false) {
      formData.value.name = '';
      formData.value.description = '';
    }
  } catch (err) {
    error.value = 'Failed to add service. Please try again.';
    console.error('Error adding service:', err);
  } finally {
    submitting.value = false;
  }
}
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.add-service-form {
  background-color: white;
  border-radius: mix.radius('md');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  margin-bottom: 24px;
  overflow: hidden;
  
  .form-header {
    padding: 16px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
    
    h4 {
      margin: 0;
      font-size: mix.font-size('md');
      font-weight: 600;
    }
  }
  
  .form-content {
    padding: 16px;
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
  
  .form-actions {
    padding: 16px;
    border-top: 1px solid rgba(0, 0, 0, 0.05);
    display: flex;
    justify-content: flex-end;
  }
  
  .btn-add {
    padding: 8px 16px;
    background-color: mix.color('primary');
    color: white;
    border: none;
    border-radius: mix.radius('md');
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s ease;
    
    &:hover:not(:disabled) {
      background-color: color.scale(mix.color('primary'), $lightness: -10%);
    }
    
    &:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }
  }
  
  .error-message {
    padding: 12px 16px;
    background-color: rgba(234, 67, 53, 0.1);
    color: #c62828;
    margin-top: 16px;
    border-radius: mix.radius('md');
  }
}
</style>
