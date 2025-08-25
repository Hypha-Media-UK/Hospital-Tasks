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
      class="card-grid"
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

<!-- Styles are now handled by the global CSS layers -->