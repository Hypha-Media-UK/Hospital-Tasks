<template>
  <div class="task-type-card">
    <div class="task-type-details">
      <h3 class="task-type-name">{{ taskType.name }}</h3>
      
      <div class="task-type-stats">
        <div class="item-count">
          {{ itemCount }} {{ itemCount === 1 ? 'Item' : 'Items' }}
        </div>
      </div>
    </div>
    
    <div class="task-type-actions">
      <button @click="viewItems" class="btn-view" title="View task items">
        <EditIcon size="16" />
      </button>
      <button @click="confirmDelete" class="btn-delete" title="Delete task type">
        <TrashIcon size="16" />
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
import EditIcon from '../icons/EditIcon.vue';
import TrashIcon from '../icons/TrashIcon.vue';

const props = defineProps({
  taskType: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['view-items', 'deleted']);

const taskTypesStore = useTaskTypesStore();

// Computed property to count items
const itemCount = computed(() => {
  return taskTypesStore.getTaskItemsByType(props.taskType.id).length;
});

// View items
const viewItems = () => {
  emit('view-items', props.taskType.id);
};

// Delete task type with confirmation
const confirmDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.taskType.name}" and all its items?`)) {
    await taskTypesStore.deleteTaskType(props.taskType.id);
    emit('deleted', props.taskType.id);
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.task-type-card {
  background-color: white;
  border-radius: mix.radius('md');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  padding: 16px;
  display: flex;
  flex-direction: column;
  position: relative;
  
  .task-type-details {
    flex: 1;
  }
  
  .task-type-name {
    margin-top: 0;
    margin-bottom: 8px;
    font-size: mix.font-size('md');
    font-weight: 600;
  }
  
  .task-type-stats {
    display: flex;
    margin-bottom: 12px;
    
    .item-count {
      background-color: rgba(66, 133, 244, 0.1);
      color: mix.color('primary');
      border-radius: mix.radius('sm');
      padding: 4px 8px;
      font-size: mix.font-size('xs');
      font-weight: 500;
    }
  }
  
  .task-type-actions {
    display: flex;
    gap: 8px;
    
    button {
      background: none;
      border: none;
      cursor: pointer;
      padding: 6px;
      border-radius: mix.radius('sm');
      
      &.btn-view:hover {
        background-color: rgba(66, 133, 244, 0.1);
      }
      
      &.btn-delete:hover {
        background-color: rgba(234, 67, 53, 0.1);
      }
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
