<template>
  <div class="task-type-item">
    <div class="task-type-item__header">
      <div v-if="isEditing" class="task-type-item__edit">
        <input 
          v-model="editName" 
          ref="editInput"
          class="task-type-item__input"
          @keyup.enter="saveTaskType"
          @keyup.esc="cancelEdit"
          @blur="saveTaskType"
        />
      </div>
      <div v-else class="task-type-item__title">
        <h3 class="task-type-item__name">{{ taskType.name }}</h3>
        <div class="task-type-item__actions">
          <IconButton 
            title="Assign Departments"
            :active="hasAssignments"
            @click="showAssignmentModal = true"
          >
            <MapPinIcon :active="hasAssignments" />
          </IconButton>
          
          <IconButton 
            title="Edit Task Type"
            @click="startEdit"
          >
            <EditIcon />
          </IconButton>
          
          <IconButton 
            title="Delete Task Type"
            @click="confirmDelete"
          >
            <TrashIcon />
          </IconButton>
        </div>
      </div>
    </div>
    
    <TaskItemsList :task-type-id="taskType.id" />
    
    <DepartmentAssignmentModal 
      v-if="showAssignmentModal"
      :taskType="taskType"
      @close="showAssignmentModal = false"
      @saved="onAssignmentsSaved"
    />
  </div>
</template>

<script setup>
import { ref, nextTick, computed } from 'vue';
import { useTaskTypesStore } from '../../stores/taskTypesStore';
import TaskItemsList from './TaskItemsList.vue';
import DepartmentAssignmentModal from './DepartmentAssignmentModal.vue';
import IconButton from '../IconButton.vue';
import EditIcon from '../icons/EditIcon.vue';
import TrashIcon from '../icons/TrashIcon.vue';
import MapPinIcon from '../icons/MapPinIcon.vue';

const props = defineProps({
  taskType: {
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

// Check if this task type has any department assignments
const hasAssignments = computed(() => {
  return taskTypesStore.hasTypeAssignments(props.taskType.id);
});

// Start editing the task type name
const startEdit = async () => {
  editName.value = props.taskType.name;
  isEditing.value = true;
  await nextTick();
  editInput.value?.focus();
};

// Save task type changes
const saveTaskType = async () => {
  if (!editName.value.trim()) {
    // Don't allow empty names
    editName.value = props.taskType.name;
    isEditing.value = false;
    return;
  }
  
  if (editName.value !== props.taskType.name) {
    await taskTypesStore.updateTaskType(props.taskType.id, {
      name: editName.value.trim()
    });
  }
  
  isEditing.value = false;
};

// Cancel editing
const cancelEdit = () => {
  isEditing.value = false;
};

// Delete task type with confirmation
const confirmDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.taskType.name}" and all its task items?`)) {
    await taskTypesStore.deleteTaskType(props.taskType.id);
    emit('deleted', props.taskType.id);
  }
};

// Handle assignments saved
const onAssignmentsSaved = () => {
  // This is just a hook in case we need to do something after assignments are saved
};
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.task-type-item {
  background-color: white;
  border-radius: mix.radius('lg');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  margin-bottom: 16px;
  overflow: hidden;
  
  &__header {
    padding: 16px;
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
  }
  
  &__title {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  
  &__name {
    font-size: mix.font-size('lg');
    font-weight: 600;
    margin: 0;
  }
  
  &__actions {
    display: flex;
    gap: 8px;
  }
  
  &__edit {
    width: 100%;
  }
  
  &__input {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid mix.color('primary');
    border-radius: mix.radius('md');
    font-size: mix.font-size('lg');
    font-weight: 600;
    
    &:focus {
      outline: none;
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
}
</style>
