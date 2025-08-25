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
  } finally {
    submitting.value = false;
  }
}
</script>

<!-- Styles are now handled by the global CSS layers -->