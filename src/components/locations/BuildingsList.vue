<template>
  <div class="buildings-list">
    <div class="buildings-list__header">
      <h2 class="buildings-list__title">Buildings</h2>
      <button 
        class="btn btn--primary"
        @click="showAddForm = true"
        v-if="!showAddForm"
      >
        Add Building
      </button>
    </div>
    
    <div v-if="showAddForm" class="buildings-list__form">
      <input 
        v-model="newBuildingName" 
        placeholder="Building name"
        class="buildings-list__input"
        ref="newBuildingInput"
        @keyup.enter="addBuilding"
        @keyup.esc="cancelAdd"
      />
      <div class="buildings-list__form-actions">
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
    
    <div v-if="locationsStore.loading.buildings" class="buildings-list__loading">
      Loading buildings...
    </div>
    
    <div v-else-if="buildings.length === 0 && !locationsStore.loading.buildings" class="buildings-list__empty">
      No buildings added yet. Add your first building to get started.
    </div>
    
    <transition-group name="list" tag="div" class="buildings-list__items">
      <BuildingItem 
        v-for="building in buildings" 
        :key="building.id"
        :building="building"
      />
    </transition-group>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted } from 'vue';
import { useLocationsStore } from '../../stores/locationsStore';
import BuildingItem from './BuildingItem.vue';

const locationsStore = useLocationsStore();
const showAddForm = ref(false);
const newBuildingName = ref('');
const newBuildingInput = ref(null);

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

// Initialize data
onMounted(async () => {
  await locationsStore.initialize();
});
</script>

<!-- Styles are now handled by the global CSS layers -->