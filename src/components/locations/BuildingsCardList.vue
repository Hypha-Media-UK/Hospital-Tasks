<template>
  <div class="buildings-card-list">
    <div class="buildings-card-list__header">
      <button 
        class="btn btn--primary"
        @click="showAddForm = true"
        v-if="!showAddForm"
      >
        Add Building
      </button>
    </div>
    
    <div v-if="showAddForm" class="buildings-card-list__form">
      <input 
        v-model="newBuildingName" 
        placeholder="Building name"
        class="buildings-card-list__input"
        ref="newBuildingInput"
        @keyup.enter="addBuilding"
        @keyup.esc="cancelAdd"
      />
      <div class="buildings-card-list__form-actions">
        <button 
          class="btn btn--primary" 
          @click="addBuilding"
          :disabled="!newBuildingName.trim()"
        >
          Add
        </button>
        <button 
          class="btn btn--secondary" 
          @click="cancelAdd"
        >
          Cancel
        </button>
      </div>
    </div>
    
    <div v-if="locationsStore.loading.buildings" class="buildings-card-list__loading">
      Loading buildings...
    </div>
    
    <div v-else-if="buildings.length === 0 && !locationsStore.loading.buildings" class="buildings-card-list__empty">
      No buildings added yet. Add your first building to get started.
    </div>
    
    <div class="buildings-card-list__grid">
      <BuildingCard 
        v-for="building in buildings" 
        :key="building.id"
        :building="building"
        @view-departments="viewBuildingDepartments"
        @deleted="handleBuildingDeleted"
      />
    </div>
    
    <!-- Building Departments Modal -->
    <BuildingDepartmentsModal
      v-if="selectedBuilding"
      :building="selectedBuilding"
      @close="selectedBuilding = null"
    />
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import BuildingCard from './BuildingCard.vue';
import BuildingDepartmentsModal from './BuildingDepartmentsModal.vue';

const locationsStore = useLocationsStore();
const showAddForm = ref(false);
const newBuildingName = ref('');
const newBuildingInput = ref(null);
const selectedBuilding = ref(null);

// Get sorted buildings
const buildings = computed(() => {
  return [...locationsStore.buildings].sort((a, b) => a.name.localeCompare(b.name));
});

// Show add form and focus input
const showAddBuildingForm = async () => {
  showAddForm.value = true;
  await nextTick();
  newBuildingInput.value?.focus();
};

// Add a new building
const addBuilding = async () => {
  if (!newBuildingName.value.trim()) return;
  
  await locationsStore.addBuilding({
    name: newBuildingName.value.trim()
  });
  
  newBuildingName.value = '';
  showAddForm.value = false;
};

// Cancel adding a building
const cancelAdd = () => {
  newBuildingName.value = '';
  showAddForm.value = false;
};

// View building departments
const viewBuildingDepartments = (buildingId) => {
  const building = locationsStore.buildings.find(b => b.id === buildingId);
  if (building) {
    selectedBuilding.value = building;
  }
};

// Handle building deleted event
const handleBuildingDeleted = (buildingId) => {
  // If the deleted building is currently selected, close the modal
  if (selectedBuilding.value && selectedBuilding.value.id === buildingId) {
    selectedBuilding.value = null;
  }
};

// Initialize data
onMounted(async () => {
  await locationsStore.initialize();
});
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.buildings-card-list {
  &__header {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    margin-bottom: 24px;
  }
  
  &__form {
    background-color: white;
    border-radius: mix.radius('lg');
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    padding: 16px;
    margin-bottom: 24px;
  }
  
  &__input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #ddd;
    border-radius: mix.radius('md');
    font-size: mix.font-size('md');
    margin-bottom: 16px;
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
  
  &__form-actions {
    display: flex;
    gap: 12px;
  }
  
  &__loading {
    text-align: center;
    padding: 24px;
    color: rgba(0, 0, 0, 0.6);
  }
  
  &__empty {
    text-align: center;
    padding: 32px;
    background-color: white;
    border-radius: mix.radius('lg');
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    color: rgba(0, 0, 0, 0.6);
  }
  
  &__grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }
}

// Button styles
.btn {
  padding: 8px 16px;
  border-radius: mix.radius('md');
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s ease;
  
  &--primary {
    background-color: mix.color('primary');
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.adjust(mix.color('primary'), $lightness: -5%);
    }
  }
  
  &--secondary {
    background-color: #f1f1f1;
    color: mix.color('text');
    
    &:hover:not(:disabled) {
      background-color: #e5e5e5;
    }
  }
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}
</style>
