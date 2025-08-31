<template>
  <div class="department-item">
    <div v-if="isEditing" class="department-item__edit">
      <input 
        v-model="editName" 
        ref="editInput"
        class="department-item__input"
        @keyup.enter="saveDepartment"
        @keyup.esc="cancelEdit"
        @blur="saveDepartment"
      />
    </div>
    <div v-else class="department-item__content">
      <div class="department-item__name">{{ department.name }}</div>
      <div class="department-item__actions">
        <IconButton 
          title="Mark as Frequent"
          :active="department.is_frequent"
          @click="toggleFrequent"
        >
          <StarIcon :filled="department.is_frequent" />
        </IconButton>
        
        <IconButton 
          title="Assign Task Type & Item"
          :active="hasTaskAssignment"
          @click="showTaskAssignment"
        >
          <TaskIcon :filled="hasTaskAssignment" />
        </IconButton>
        
        <IconButton 
          title="Edit Department"
          @click="startEdit"
        >
          <EditIcon />
        </IconButton>
        
        <IconButton 
          title="Delete Department"
          @click="confirmDelete"
        >
          <CloseIcon />
        </IconButton>
      </div>
    </div>
    
    <!-- Task Assignment Modal -->
    <DepartmentTaskAssignmentModal
      v-if="showTaskAssignmentModal"
      :department="department"
      @close="showTaskAssignmentModal = false"
      @saved="onTaskAssignmentSaved"
    />
  </div>
</template>

<script setup>
import { ref, nextTick, computed } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import IconButton from '../IconButton.vue';
import StarIcon from '../icons/StarIcon.vue';
import EditIcon from '../icons/EditIcon.vue';
import CloseIcon from '../icons/CloseIcon.vue';
import TaskIcon from '../icons/TaskIcon.vue';
import DepartmentTaskAssignmentModal from './DepartmentTaskAssignmentModal.vue';

const props = defineProps({
  department: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['deleted']);

const locationsStore = useLocationsStore();
const isEditing = ref(false);
const editName = ref('');
const editInput = ref(null);
const showTaskAssignmentModal = ref(false);

// Check if this department has a task assignment
const hasTaskAssignment = computed(() => {
  const assignment = locationsStore.getDepartmentTaskAssignment(props.department.id);
  return !!assignment;
});

// Start editing the department name
const startEdit = async () => {
  editName.value = props.department.name;
  isEditing.value = true;
  await nextTick();
  editInput.value?.focus();
};

// Save department changes
const saveDepartment = async () => {
  if (!editName.value.trim()) {
    // Don't allow empty names
    editName.value = props.department.name;
    isEditing.value = false;
    return;
  }
  
  if (editName.value !== props.department.name) {
    await locationsStore.updateDepartment(props.department.id, {
      name: editName.value.trim()
    });
  }
  
  isEditing.value = false;
};

// Cancel editing
const cancelEdit = () => {
  isEditing.value = false;
};

// Toggle frequent status
const toggleFrequent = async () => {
  await locationsStore.toggleFrequent(props.department.id);
};

// Delete department with confirmation
const confirmDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.department.name}"?`)) {
    await locationsStore.deleteDepartment(props.department.id);
    emit('deleted', props.department.id);
  }
};

// Show task assignment modal
const showTaskAssignment = () => {
  showTaskAssignmentModal.value = true;
};

// Handle task assignment saved
const onTaskAssignmentSaved = () => {
  // This is just a hook in case we want to do something after saving
};
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.department-item {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border-radius: mix.radius('md');
  transition: background-color 0.2s ease;
  
  &:hover {
    background-color: rgba(0, 0, 0, 0.03);
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
    gap: 8px;
    padding: 4px;
    background-color: rgba(0, 0, 0, 0.02);
    border-radius: mix.radius('md');
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
