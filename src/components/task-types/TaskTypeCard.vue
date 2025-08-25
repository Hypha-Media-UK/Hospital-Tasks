<template>
  <div class="task-type-card" @click="viewItems">
    <div class="task-type-details">
      <h3 class="task-type-name">{{ taskType.name }}</h3>
    </div>
    
    <div class="task-type-card-footer">
      <div class="task-type-actions">
        <button @click.stop="confirmDelete" class="btn-delete" title="Delete task type">
          <TrashIcon size="16" />
        </button>
      </div>
      
      <div class="item-count">
        {{ itemCount }} {{ itemCount === 1 ? 'Item' : 'Items' }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
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

<!-- Styles are now handled by the global CSS layers -->