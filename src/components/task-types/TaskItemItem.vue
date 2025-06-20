<template>
  <div class="task-item" :class="{ 'task-item--regular': isRegular }">
    <div v-if="isEditing" class="task-item__edit">
      <input 
        v-model="editName" 
        ref="editInput"
        class="task-item__input"
        @keyup.enter="saveTaskItem"
        @keyup.esc="cancelEdit"
        @blur="saveTaskItem"
      />
    </div>
    <div v-else class="task-item__content">
      <div class="task-item__name">{{ taskItem.name }}</div>
      <div class="task-item__actions">
        <IconButton 
          title="Mark as Regular"
          :active="isRegular"
          @click="toggleRegular"
        >
          <StarIcon :filled="isRegular" />
        </IconButton>
        
        <IconButton 
          title="Assign Departments"
          :active="hasAssignments"
          @click="showAssignmentModal = true"
        >
          <MapPinIcon :active="hasAssignments" />
        </IconButton>
        
        <IconButton 
          title="Edit Task Item"
          @click="startEdit"
        >
          <EditIcon />
        </IconButton>
        
        <IconButton 
          title="Delete Task Item"
          @click="confirmDelete"
        >
          <CloseIcon />
        </IconButton>
      </div>
    </div>
    
    <ItemDepartmentAssignmentModal 
      v-if="showAssignmentModal"
      :taskItem="taskItem"
      @close="showAssignmentModal = false"
      @saved="onAssignmentsSaved"
    />
  </div>
</template>

<script setup>
import { ref, nextTick, computed } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
import IconButton from '../IconButton.vue';
import EditIcon from '../icons/EditIcon.vue';
import CloseIcon from '../icons/CloseIcon.vue';
import MapPinIcon from '../icons/MapPinIcon.vue';
import StarIcon from '../icons/StarIcon.vue';
import ItemDepartmentAssignmentModal from './ItemDepartmentAssignmentModal.vue';

const props = defineProps({
  taskItem: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['deleted']);

const taskTypesStore = useTaskTypesStore();
const isEditing = ref(false);
const editName = ref('');
const editInput = ref(null);
const showAssignmentModal = ref(false);

// Check if this task item has any department assignments
const hasAssignments = computed(() => {
  return taskTypesStore.hasItemAssignments(props.taskItem.id);
});

// Check if this task item is marked as regular
const isRegular = computed(() => {
  return props.taskItem.is_regular === true;
});

// Start editing the task item name
const startEdit = async () => {
  editName.value = props.taskItem.name;
  isEditing.value = true;
  await nextTick();
  editInput.value?.focus();
};

// Save task item changes
const saveTaskItem = async () => {
  if (!editName.value.trim()) {
    // Don't allow empty names
    editName.value = props.taskItem.name;
    isEditing.value = false;
    return;
  }
  
  if (editName.value !== props.taskItem.name) {
    await taskTypesStore.updateTaskItem(props.taskItem.id, {
      name: editName.value.trim()
    });
  }
  
  isEditing.value = false;
};

// Cancel editing
const cancelEdit = () => {
  isEditing.value = false;
};

// Delete task item with confirmation
const confirmDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.taskItem.name}"?`)) {
    await taskTypesStore.deleteTaskItem(props.taskItem.id);
    emit('deleted', props.taskItem.id);
  }
};

// Handle assignments saved
const onAssignmentsSaved = () => {
  // This is just a hook in case we need to do something after assignments are saved
};

// Toggle regular status
const toggleRegular = async () => {
  await taskTypesStore.setTaskItemRegular(props.taskItem.id, !isRegular.value);
};
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.task-item {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border-radius: mix.radius('md');
  transition: background-color 0.2s ease;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.03);
  }
  
  // Highlight the item if it's marked as regular
  &--regular {
    background-color: rgba(66, 133, 244, 0.05);
    border-left: 3px solid rgba(66, 133, 244, 0.6);
  }
  
  &__content {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
  }
  
  &__name {
    font-size: mix.font-size('md');
  }
  
  &__actions {
    display: flex;
    gap: 4px;
  }
  
  &__edit {
    width: 100%;
  }
  
  &__input {
    width: 100%;
    padding: 6px 8px;
    border: 1px solid mix.color('primary');
    border-radius: mix.radius('sm');
    font-size: mix.font-size('md');
    
    &:focus {
      outline: none;
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
}
</style>
