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
  </div>
</template>

<script setup>
import { ref, nextTick, computed } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import IconButton from '../IconButton.vue';
import StarIcon from '../icons/StarIcon.vue';
import EditIcon from '../icons/EditIcon.vue';
import CloseIcon from '../icons/CloseIcon.vue';

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
