<template>
  <div class="buildings-card-list">
    <div class="buildings-card-list__header">
      <div class="title-section">
        <h3>Buildings</h3>
        <p class="drag-hint" v-if="buildings.length > 1">
          <span class="drag-icon">⇅</span> Drag to reorder buildings
        </p>
      </div>
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
    
    <draggable 
      v-model="sortableBuildings" 
      class="buildings-card-list__grid"
      item-key="id"
      :animation="200"
      :disabled="locationsStore.loading.sorting"
      @end="onDragEnd"
      handle=".building-card__drag-handle"
    >
      <template #item="{element}">
        <BuildingCard 
          :building="element"
          :key="element.id"
          @view-departments="viewBuildingDepartments"
        />
      </template>
    </draggable>
    
    <!-- Building Departments Modal -->
    <BuildingDepartmentsModal
      v-if="selectedBuilding"
      :building="selectedBuilding"
      @close="selectedBuilding = null"
    />
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted, watch } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import BuildingCard from './BuildingCard.vue';
import BuildingDepartmentsModal from './BuildingDepartmentsModal.vue';
import draggable from 'vuedraggable';

const locationsStore = useLocationsStore();
const showAddForm = ref(false);
const newBuildingName = ref('');
const newBuildingInput = ref(null);
const selectedBuilding = ref(null);

// Get sorted buildings for display purposes
const buildings = computed(() => {
  return locationsStore.sortedBuildings;
});

// Local state to store the buildings array for drag and drop
const localBuildings = ref([]);

// Initialize local buildings from store when component mounts or when store changes
watch(() => locationsStore.sortedBuildings, (newBuildings) => {
  localBuildings.value = [...newBuildings];
}, { immediate: true });

// Use local buildings for the draggable component
const sortableBuildings = computed({
  get: () => {
    return localBuildings.value;
  },
  set: (newValue) => {
    // Update local state immediately to prevent reversion
    localBuildings.value = newValue;
    
    // Update sort_order properties on the local buildings
    localBuildings.value.forEach((building, index) => {
      building.sort_order = index * 10; // Multiply by 10 to leave room for insertions later
    });
  }
});

// Handle drag end event - persist changes to database
const onDragEnd = async (event) => {
  if (event.oldIndex === event.newIndex) return; // No change in order
  
  // Update the sort orders of all buildings
  const updates = localBuildings.value.map((building, index) => ({
    id: building.id,
    sort_order: index * 10 // Multiply by 10 to leave room for insertions later
  }));
  
  // Save the changes to the database
  await locationsStore.updateBuildingsSortOrder(updates);
};

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
    justify-content: space-between;
    margin-bottom: 24px;
    
    .title-section {
      display: flex;
      flex-direction: column;
      
      h3 {
        margin: 0;
        font-size: mix.font-size('lg');
      }
      
      .drag-hint {
        font-size: mix.font-size('sm');
        color: rgba(0, 0, 0, 0.6);
        margin: 4px 0 0 0;
        
        .drag-icon {
          font-weight: bold;
          color: mix.color('primary');
        }
      }
    }
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
