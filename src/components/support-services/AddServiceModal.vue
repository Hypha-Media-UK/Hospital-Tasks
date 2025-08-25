<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <h3 class="modal-title">Add Support Service</h3>
        <button class="modal-close" @click.stop="$emit('close')">&times;</button>
      </div>
      
      <div class="modal-body">
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
      
      <div class="modal-footer">
        <button 
          @click="saveService" 
          class="btn btn--primary"
          :disabled="submitting || !formData.name"
        >
          {{ submitting ? 'Adding...' : 'Add Service' }}
        </button>
        <button 
          @click.stop="$emit('close')" 
          class="btn btn--secondary"
          :disabled="submitting"
        >
          Cancel
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';

// Props and emits
const emit = defineEmits(['add', 'close']);

// Form state
const formData = ref({
  name: '',
  description: ''
});
const submitting = ref(false);

// Form submission
async function saveService() {
  if (!formData.value.name || submitting.value) return;
  
  submitting.value = true;
  
  try {
    // Emit the add event with the form data
    await emit('add', {
      name: formData.value.name,
      description: formData.value.description || null
    });
    
    // Close the modal - the parent component will handle success/error
    emit('close');
  } catch (err) {
  } finally {
    submitting.value = false;
  }
}
</script>

<!-- Styles are now handled by the global CSS layers -->