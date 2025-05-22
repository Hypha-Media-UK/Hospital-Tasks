<template>
  <div 
    class="department-card" 
    :style="{ borderLeftColor: assignment.color || '#4285F4' }"
    @click="showEditModal = true"
  >
    <div class="department-card__content">
      <div class="department-card__name">
        {{ assignment.department.name }}
      </div>
      <div class="department-card__building">
        {{ assignment.department.building?.name || 'Unknown Building' }}
      </div>
      <div v-if="assignment.porter" class="department-card__porter">
        <span class="porter-name">
          {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
        </span>
      </div>
    </div>
    
    <!-- Edit Department Modal -->
    <EditDepartmentModal 
      v-if="showEditModal" 
      :assignment="assignment"
      @close="showEditModal = false"
      @update="handleUpdate"
      @remove="handleRemove"
    />
  </div>
</template>

<script setup>
import { ref } from 'vue';
import EditDepartmentModal from './EditDepartmentModal.vue';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['update', 'remove']);

const showEditModal = ref(false);

// Forward events from modal to parent
const handleUpdate = (assignmentId, updates) => {
  emit('update', assignmentId, updates);
};

const handleRemove = (assignmentId) => {
  emit('remove', assignmentId);
  showEditModal.value = false;
};
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.department-card {
  background-color: white;
  border-radius: mix.radius('md');
  border-left: 4px solid #4285F4; // Default color, will be overridden by inline style
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  transition: box-shadow 0.2s ease;
  cursor: pointer;
  
  &:hover {
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
    background-color: rgba(0, 0, 0, 0.01);
  }
  
  &__content {
    padding: 12px 16px;
  }
  
  &__name {
    font-weight: 600;
    font-size: mix.font-size('md');
    margin-bottom: 4px;
  }
  
  &__building {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
    margin-bottom: 4px;
  }
  
  &__porter {
    margin-top: 8px;
    
    .porter-name {
      display: inline-block;
      background-color: rgba(66, 133, 244, 0.1);
      color: mix.color('primary');
      border-radius: 100px;
      padding: 2px 8px;
      font-size: mix.font-size('xs');
      font-weight: 500;
    }
  }
}
</style>
