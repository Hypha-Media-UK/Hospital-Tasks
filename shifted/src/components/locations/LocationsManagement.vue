<template>
  <BaseManagementContainer
    title="Locations"
    :items="locationsStore.buildings"
    :loading="locationsStore.loading.buildings"
    loading-text="Loading locations..."
    :empty-icon="MapPinIcon"
    empty-title="No Buildings Added"
    empty-description="Add your first building to start organizing locations and departments."
    add-button-text="Add Building"
    @add-item="openAddBuildingModal"
  >
    <template #items="{ items }">
      <BuildingCard
        v-for="building in items"
        :key="building.id"
        :building="building"
        @edit="editBuilding"
        @delete="deleteBuilding"
      />
    </template>

    <template #modals>
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
    </template>
  </BaseManagementContainer>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { useLocationsStore } from '../../stores/locationsStore'
import BaseButton from '../ui/BaseButton.vue'
import BaseModal from '../ui/BaseModal.vue'
import BaseManagementContainer from '../ui/BaseManagementContainer.vue'
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
