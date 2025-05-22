<template>
  <div class="building-item">
    <div class="building-item__header">
      <div v-if="isEditing" class="building-item__edit">
        <input 
          v-model="editName" 
          ref="editInput"
          class="building-item__input"
          @keyup.enter="saveBuilding"
          @keyup.esc="cancelEdit"
          @blur="saveBuilding"
        />
      </div>
      <div v-else class="building-item__title">
        <h3 class="building-item__name">{{ building.name }}</h3>
        <div class="building-item__actions">
          <IconButton 
            title="Edit Building"
            @click="startEdit"
          >
            <EditIcon />
          </IconButton>
          
          <IconButton 
            title="Delete Building"
            @click="confirmDelete"
          >
            <TrashIcon />
          </IconButton>
        </div>
      </div>
    </div>
    
    <DepartmentsList :building-id="building.id" />
  </div>
</template>

<script setup>
import { ref, nextTick } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import DepartmentsList from './DepartmentsList.vue';
import IconButton from '../IconButton.vue';
import EditIcon from '../icons/EditIcon.vue';
import TrashIcon from '../icons/TrashIcon.vue';

const props = defineProps({
  building: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['deleted']);

const locationsStore = useLocationsStore();
const isEditing = ref(false);
const editName = ref('');
const editInput = ref(null);

// Start editing the building name
const startEdit = async () => {
  editName.value = props.building.name;
  isEditing.value = true;
  await nextTick();
  editInput.value?.focus();
};

// Save building changes
const saveBuilding = async () => {
  if (!editName.value.trim()) {
    // Don't allow empty names
    editName.value = props.building.name;
    isEditing.value = false;
    return;
  }
  
  if (editName.value !== props.building.name) {
    await locationsStore.updateBuilding(props.building.id, {
      name: editName.value.trim()
    });
  }
  
  isEditing.value = false;
};

// Cancel editing
const cancelEdit = () => {
  isEditing.value = false;
};

// Delete building with confirmation
const confirmDelete = async () => {
  if (confirm(`Are you sure you want to delete "${props.building.name}" and all its departments?`)) {
    await locationsStore.deleteBuilding(props.building.id);
    emit('deleted', props.building.id);
  }
};
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.building-item {
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
