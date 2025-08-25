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

<!-- Styles are now handled by the global CSS layers -->