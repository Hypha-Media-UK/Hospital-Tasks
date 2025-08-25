<template>
  <div class="service-item" @click="openEditModal">
    <div class="service-details">
      <h3 class="service-name">{{ service.name }}</h3>
      
      <div v-if="service.description" class="service-description">
        {{ service.description }}
      </div>
    </div>
    
    <div class="service-actions">
      <button @click.stop="confirmDelete" class="btn-delete" title="Delete service">
        <TrashIcon size="16" />
      </button>
    </div>
  </div>
  
  <!-- External Edit Modal Component -->
  <EditServiceModal 
    v-if="showEditModal" 
    :service="service"
    @close="showEditModal = false"
    @update="handleUpdate"
    @delete="handleDelete"
  />
</template>

<script setup>
import { ref, computed } from 'vue';
import TrashIcon from '../icons/TrashIcon.vue';
import EditServiceModal from './EditServiceModal.vue';

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

// Methods
function openEditModal() {
  showEditModal.value = true;
}

function handleUpdate(updatedService) {
  emit('update', updatedService);
  showEditModal.value = false;
}

function handleDelete(serviceId) {
  emit('delete', serviceId);
  showEditModal.value = false;
}

function confirmDelete() {
  if (confirm(`Are you sure you want to delete ${props.service.name}?`)) {
    emit('delete', props.service.id);
  }
}
</script>

<!-- Styles are now handled by the global CSS layers -->