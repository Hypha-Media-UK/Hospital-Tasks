<template>
  <div class="locations-management">
    <div class="management-header">
      <h2 class="management-title">Locations</h2>
      <BaseButton variant="primary" @click="showAddBuildingModal = true">
        <PlusIcon class="w-4 h-4" />
        Add Building
      </BaseButton>
    </div>

    <div v-if="locationsStore.loading.buildings" class="loading-state">
      <div class="loading-spinner"></div>
      <p>Loading locations...</p>
    </div>

    <div v-else-if="locationsStore.buildings.length === 0" class="empty-state">
      <div class="empty-icon">
        <MapPinIcon class="w-16 h-16" />
      </div>
      <h3>No Buildings Added</h3>
      <p>Add your first building to start organizing locations and departments.</p>
      <BaseButton variant="primary" @click="showAddBuildingModal = true">
        <PlusIcon class="w-4 h-4" />
        Add Building
      </BaseButton>
    </div>

    <div v-else class="buildings-list">
      <BuildingCard
        v-for="building in locationsStore.sortedBuildings"
        :key="building.id"
        :building="building"
        @edit="editBuilding"
        @delete="deleteBuilding"
      />
    </div>

    <!-- Add Building Modal -->
    <BaseModal
      v-if="showAddBuildingModal"
      title="Add Building"
      size="md"
      show-footer
      @close="closeAddBuildingModal"
    >
      <form @submit.prevent="addBuilding">
        <div class="form-group">
          <label for="buildingName">Building Name</label>
          <input
            id="buildingName"
            v-model="buildingForm.name"
            type="text"
            required
            class="form-control"
            placeholder="Enter building name"
            ref="buildingNameInput"
          />
        </div>
      </form>

      <template #footer>
        <BaseButton variant="secondary" @click="closeAddBuildingModal">
          Cancel
        </BaseButton>
        <BaseButton
          variant="primary"
          @click="addBuilding"
          :disabled="!buildingForm.name.trim() || locationsStore.loading.buildings"
        >
          {{ locationsStore.loading.buildings ? 'Adding...' : 'Add Building' }}
        </BaseButton>
      </template>
    </BaseModal>

    <!-- Edit Building Modal -->
    <BaseModal
      v-if="showEditBuildingModal"
      title="Edit Building"
      size="md"
      show-footer
      @close="closeEditBuildingModal"
    >
      <form @submit.prevent="updateBuilding">
        <div class="form-group">
          <label for="editBuildingName">Building Name</label>
          <input
            id="editBuildingName"
            v-model="editBuildingForm.name"
            type="text"
            required
            class="form-control"
            placeholder="Enter building name"
          />
        </div>
      </form>

      <template #footer>
        <BaseButton variant="secondary" @click="closeEditBuildingModal">
          Cancel
        </BaseButton>
        <BaseButton
          variant="primary"
          @click="updateBuilding"
          :disabled="!editBuildingForm.name.trim() || locationsStore.loading.buildings"
        >
          {{ locationsStore.loading.buildings ? 'Updating...' : 'Update Building' }}
        </BaseButton>
      </template>
    </BaseModal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { useLocationsStore } from '../../stores/locationsStore'
import BaseButton from '../ui/BaseButton.vue'
import BaseModal from '../ui/BaseModal.vue'
import BuildingCard from './BuildingCard.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import MapPinIcon from '../icons/MapPinIcon.vue'
import type { Building } from '../../types/locations'

const locationsStore = useLocationsStore()

// Modal state
const showAddBuildingModal = ref(false)
const showEditBuildingModal = ref(false)
const buildingNameInput = ref<HTMLInputElement>()

// Form state
const buildingForm = ref({
  name: ''
})

const editBuildingForm = ref({
  id: '',
  name: ''
})

// Methods
const addBuilding = async () => {
  if (!buildingForm.value.name.trim()) return

  const success = await locationsStore.addBuilding({
    name: buildingForm.value.name.trim(),
    sort_order: locationsStore.buildings.length
  })

  if (success) {
    closeAddBuildingModal()
  }
}

const editBuilding = (building: Building) => {
  editBuildingForm.value = {
    id: building.id,
    name: building.name
  }
  showEditBuildingModal.value = true
}

const updateBuilding = async () => {
  if (!editBuildingForm.value.name.trim()) return

  const success = await locationsStore.updateBuilding(editBuildingForm.value.id, {
    name: editBuildingForm.value.name.trim()
  })

  if (success) {
    closeEditBuildingModal()
  }
}

const deleteBuilding = async (building: Building) => {
  if (confirm(`Are you sure you want to delete "${building.name}" and all its departments?`)) {
    await locationsStore.deleteBuilding(building.id)
  }
}

const closeAddBuildingModal = () => {
  showAddBuildingModal.value = false
  buildingForm.value.name = ''
}

const closeEditBuildingModal = () => {
  showEditBuildingModal.value = false
  editBuildingForm.value = { id: '', name: '' }
}

// Auto-focus input when modal opens
const openAddBuildingModal = async () => {
  showAddBuildingModal.value = true
  await nextTick()
  buildingNameInput.value?.focus()
}

// Initialize
onMounted(async () => {
  await locationsStore.initialize()
})
</script>

<style scoped>
.locations-management {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.management-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--spacing);
}

.management-title {
  font-size: 1.5rem;
  font-weight: 600;
  margin: 0;
  color: var(--color-text);
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  gap: var(--spacing);
  color: var(--color-text-light);
}

.loading-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-border);
  border-top: 3px solid var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  text-align: center;
  background: var(--color-background-alt);
  border-radius: var(--radius-lg);
  border: 2px dashed var(--color-border);
}

.empty-icon {
  margin-bottom: var(--spacing-lg);
  color: var(--color-text-light);
  opacity: 0.6;
}

.empty-state h3 {
  margin-bottom: var(--spacing-sm);
  color: var(--color-text);
}

.empty-state p {
  margin-bottom: var(--spacing-lg);
  color: var(--color-text-light);
}

.buildings-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing);
}

/* Form styles */
.form-group {
  margin-bottom: var(--spacing);
}

.form-group label {
  display: block;
  margin-bottom: var(--spacing-xs);
  font-weight: 500;
  color: var(--color-text);
}

.form-control {
  width: 100%;
  padding: var(--spacing-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  font-size: 0.875rem;
}

.form-control:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-light);
}
</style>
