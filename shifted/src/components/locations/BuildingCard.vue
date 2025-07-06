<template>
  <BaseCard>
    <template #header>
      <div class="building-info">
        <h3 class="building-name">{{ building.name }}</h3>
        <span class="department-count">
          {{ departmentCount }} {{ departmentCount === 1 ? 'department' : 'departments' }}
        </span>
      </div>
    </template>

    <template #actions>
      <BaseButton variant="ghost" size="sm" @click="$emit('edit', building)">
        <EditIcon class="w-4 h-4" />
      </BaseButton>
      <BaseButton variant="ghost" size="sm" @click="$emit('delete', building)">
        <TrashIcon class="w-4 h-4" />
      </BaseButton>
    </template>

    <template #content>
      <div class="departments-section">
        <div class="departments-header">
          <h4 class="departments-title">Departments</h4>
          <BaseButton variant="ghost" size="sm" @click="showAddDepartment = true">
            <PlusIcon class="w-4 h-4" />
            Add Department
          </BaseButton>
        </div>

        <div v-if="showAddDepartment" class="add-department-form">
          <div class="form-row">
            <input
              v-model="newDepartmentName"
              type="text"
              placeholder="Department name"
              class="form-control"
              ref="departmentInput"
              @keyup.enter="addDepartment"
              @keyup.esc="cancelAddDepartment"
            />
            <BaseButton
              variant="primary"
              size="sm"
              @click="addDepartment"
              :disabled="!newDepartmentName.trim() || locationsStore.loading.departments"
            >
              Add
            </BaseButton>
            <BaseButton variant="secondary" size="sm" @click="cancelAddDepartment">
              Cancel
            </BaseButton>
          </div>
        </div>

        <div v-if="departments.length === 0 && !showAddDepartment" class="no-departments">
          No departments added yet
        </div>

        <div v-else class="departments-list">
          <DepartmentItem
            v-for="department in departments"
            :key="department.id"
            :department="department"
            @edit="editDepartment"
            @delete="deleteDepartment"
            @toggle-frequent="toggleFrequent"
          />
        </div>
      </div>

      <!-- Edit Department Modal -->
      <div v-if="showEditDepartmentModal" class="modal-overlay">
        <div class="modal-container">
          <div class="modal-header">
            <h3 class="modal-title">Edit Department</h3>
            <button class="modal-close" @click="closeEditDepartmentModal">&times;</button>
          </div>

          <div class="modal-body">
            <form @submit.prevent="updateDepartment">
              <div class="form-group">
                <label for="editDepartmentName">Department Name</label>
                <input
                  id="editDepartmentName"
                  v-model="editDepartmentForm.name"
                  type="text"
                  required
                  class="form-control"
                  placeholder="Enter department name"
                />
              </div>

              <div class="form-group">
                <div class="checkbox-container">
                  <input
                    type="checkbox"
                    id="isFrequent"
                    v-model="editDepartmentForm.is_frequent"
                  />
                  <label for="isFrequent">Mark as frequent department</label>
                </div>
              </div>

              <div class="form-actions">
                <BaseButton variant="secondary" @click="closeEditDepartmentModal">
                  Cancel
                </BaseButton>
                <BaseButton
                  variant="primary"
                  type="submit"
                  :disabled="!editDepartmentForm.name.trim() || locationsStore.loading.departments"
                >
                  {{ locationsStore.loading.departments ? 'Updating...' : 'Update Department' }}
                </BaseButton>
              </div>
            </form>
          </div>
        </div>
      </div>
    </template>
  </BaseCard>
</template>

<script setup lang="ts">
import { ref, computed, nextTick } from 'vue'
import { useLocationsStore } from '../../stores/locationsStore'
import BaseButton from '../ui/BaseButton.vue'
import BaseCard from '../ui/BaseCard.vue'
import DepartmentItem from './DepartmentItem.vue'
import EditIcon from '../icons/EditIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import type { Building, Department } from '../../types/locations'

interface Props {
  building: Building
}

interface Emits {
  edit: [building: Building]
  delete: [building: Building]
}

const props = defineProps<Props>()
defineEmits<Emits>()

const locationsStore = useLocationsStore()

// Local state
const showAddDepartment = ref(false)
const showEditDepartmentModal = ref(false)
const newDepartmentName = ref('')
const departmentInput = ref<HTMLInputElement>()

// Edit department form
const editDepartmentForm = ref({
  id: '',
  name: '',
  is_frequent: false
})

// Computed
const departments = computed(() => {
  return locationsStore.sortedDepartmentsByBuilding(props.building.id)
})

const departmentCount = computed(() => departments.value.length)

// Methods
const addDepartment = async () => {
  if (!newDepartmentName.value.trim()) return

  const success = await locationsStore.addDepartment({
    building_id: props.building.id,
    name: newDepartmentName.value.trim(),
    is_frequent: false,
    sort_order: departments.value.length
  })

  if (success) {
    cancelAddDepartment()
  }
}

const cancelAddDepartment = () => {
  showAddDepartment.value = false
  newDepartmentName.value = ''
}

const editDepartment = (department: Department) => {
  editDepartmentForm.value = {
    id: department.id,
    name: department.name,
    is_frequent: department.is_frequent
  }
  showEditDepartmentModal.value = true
}

const updateDepartment = async () => {
  if (!editDepartmentForm.value.name.trim()) return

  const success = await locationsStore.updateDepartment(editDepartmentForm.value.id, {
    name: editDepartmentForm.value.name.trim(),
    is_frequent: editDepartmentForm.value.is_frequent
  })

  if (success) {
    closeEditDepartmentModal()
  }
}

const closeEditDepartmentModal = () => {
  showEditDepartmentModal.value = false
  editDepartmentForm.value = { id: '', name: '', is_frequent: false }
}

const deleteDepartment = async (department: Department) => {
  if (confirm(`Are you sure you want to delete "${department.name}"?`)) {
    await locationsStore.deleteDepartment(department.id)
  }
}

const toggleFrequent = async (department: Department) => {
  await locationsStore.toggleFrequent(department.id)
}

// Auto-focus when showing add form
const showAddDepartmentForm = async () => {
  showAddDepartment.value = true
  await nextTick()
  departmentInput.value?.focus()
}
</script>

<style scoped>
.building-name {
  font-size: 1.125rem;
  font-weight: 600;
  margin: 0 0 var(--spacing-xs) 0;
  color: var(--color-text);
}

.department-count {
  font-size: 0.875rem;
  color: var(--color-text-light);
}

.departments-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing);
}

.departments-title {
  font-size: 1rem;
  font-weight: 500;
  margin: 0;
  color: var(--color-text);
}

.add-department-form {
  margin-bottom: var(--spacing);
  padding: var(--spacing);
  background: var(--color-background-alt);
  border-radius: var(--radius);
}

.form-row {
  display: flex;
  gap: var(--spacing-sm);
  align-items: center;
}

.form-control {
  flex: 1;
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

.no-departments {
  padding: var(--spacing);
  text-align: center;
  color: var(--color-text-light);
  font-style: italic;
  font-size: 0.875rem;
}

.departments-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-xs);
}

/* Modal styles */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-container {
  background-color: var(--color-background);
  border-radius: var(--radius-lg);
  width: 90%;
  max-width: 500px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.modal-header {
  padding: var(--spacing-lg);
  border-bottom: 1px solid var(--color-border);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 600;
}

.modal-close {
  background: transparent;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  padding: 0;
  line-height: 1;
  color: var(--color-text-light);
}

.modal-close:hover {
  color: var(--color-text);
}

.modal-body {
  padding: var(--spacing-lg);
  overflow-y: auto;
  flex: 1;
}

.form-group {
  margin-bottom: var(--spacing);
}

.form-group label {
  display: block;
  margin-bottom: var(--spacing-xs);
  font-weight: 500;
  color: var(--color-text);
}

.checkbox-container {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.checkbox-container input[type="checkbox"] {
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.checkbox-container label {
  display: inline;
  margin-bottom: 0;
  cursor: pointer;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--spacing);
  margin-top: var(--spacing-lg);
}
</style>
