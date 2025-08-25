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

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.service-item {
  background-color: #f9f9f9;
  border-radius: mix.radius('md');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  padding: 16px;
  display: flex;
  flex-direction: column;
  position: relative;
  min-height: 100px;
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  
  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 3px 6px rgba(0, 0, 0, 0.15);
    background-color: rgba(0, 0, 0, 0.01);
  }
  
  .service-details {
    flex: 1;
    margin-bottom: 12px;
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
  
  .service-actions {
    display: flex;
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
      
      &.btn-delete:hover {
        background-color: rgba(234, 67, 53, 0.1);
      }
    }
  }
}
</style>
