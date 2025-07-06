<template>
  <BaseModal
    title="Add Department to Coverage"
    size="lg"
    show-footer
    @close="$emit('close')"
  >
    <div class="department-selector">
      <div v-if="availableDepartments.length === 0" class="empty-state">
        <p>No departments available to add.</p>
        <p>All departments have already been assigned or no departments exist.</p>
      </div>

      <div v-else class="selector-content">
        <div class="search-section">
          <BaseFormField label="Search Departments">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Search by department or building name..."
              class="search-input"
            />
          </BaseFormField>
        </div>

        <div class="buildings-list">
          <div
            v-for="building in filteredBuildings"
            :key="building.id"
            class="building-item"
          >
            <div class="building-header">
              <h4 class="building-name">{{ building.name }}</h4>
              <span class="department-count">
                {{ building.departments.length }} department{{ building.departments.length !== 1 ? 's' : '' }}
              </span>
            </div>

            <div class="departments-list">
              <div
                v-for="department in building.departments"
                :key="department.id"
                class="department-item"
                :class="{ 'department-selected': selectedDepartments.has(department.id) }"
              >
                <div class="department-info">
                  <div class="department-name">{{ department.name }}</div>
                </div>

                <div class="department-actions">
                  <BaseButton
                    v-if="!selectedDepartments.has(department.id)"
                    variant="primary"
                    size="sm"
                    @click="selectDepartment(department.id)"
                  >
                    Select
                  </BaseButton>
                  <BaseButton
                    v-else
                    variant="secondary"
                    size="sm"
                    @click="deselectDepartment(department.id)"
                  >
                    Selected
                  </BaseButton>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="modal-footer-actions">
        <div class="footer-info">
          <span v-if="selectedDepartments.size > 0" class="selection-count">
            {{ selectedDepartments.size }} department{{ selectedDepartments.size !== 1 ? 's' : '' }} selected
          </span>
        </div>

        <div class="footer-actions">
          <BaseButton
            variant="secondary"
            @click="$emit('close')"
          >
            Cancel
          </BaseButton>
          <BaseButton
            variant="primary"
            @click="addSelectedDepartments"
            :disabled="selectedDepartments.size === 0"
          >
            Add {{ selectedDepartments.size > 1 ? 'Departments' : 'Department' }}
          </BaseButton>
        </div>
      </div>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import BaseModal from '../ui/BaseModal.vue'
import BaseButton from '../ui/BaseButton.vue'
import BaseFormField from '../ui/BaseFormField.vue'
import type { Building, Department } from '../../types/locations'

interface BuildingWithDepartments extends Building {
  departments: Department[]
}

interface Props {
  availableDepartments: Department[]
  buildingsWithDepartments: BuildingWithDepartments[]
  shiftType: string
}

interface Emits {
  (e: 'close'): void
  (e: 'add-departments', departmentIds: string[]): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const searchQuery = ref('')
const selectedDepartments = ref(new Set<string>())

// Computed properties
const filteredBuildings = computed(() => {
  if (!searchQuery.value.trim()) {
    return props.buildingsWithDepartments
  }

  const query = searchQuery.value.toLowerCase()

  return props.buildingsWithDepartments
    .map(building => ({
      ...building,
      departments: building.departments.filter(dept =>
        dept.name.toLowerCase().includes(query) ||
        building.name.toLowerCase().includes(query)
      )
    }))
    .filter(building => building.departments.length > 0)
})

// Methods
const selectDepartment = (departmentId: string) => {
  selectedDepartments.value.add(departmentId)
}

const deselectDepartment = (departmentId: string) => {
  selectedDepartments.value.delete(departmentId)
}

const addSelectedDepartments = () => {
  if (selectedDepartments.value.size === 0) return

  emit('add-departments', Array.from(selectedDepartments.value))
}
</script>

<style scoped>
.department-selector {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
  max-height: 60vh;
}

.empty-state {
  padding: var(--spacing-xl);
  text-align: center;
  color: var(--color-text-muted);
  background-color: var(--color-gray-25);
  border-radius: var(--border-radius-md);
}

.empty-state p {
  margin: 0;
}

.empty-state p:first-child {
  font-weight: 500;
  margin-bottom: var(--spacing-sm);
}

.selector-content {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.search-section {
  flex-shrink: 0;
}

.search-input {
  width: 100%;
  padding: var(--spacing-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  font-size: var(--font-size-md);
}

.search-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-alpha);
}

.buildings-list {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.building-item {
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  overflow: hidden;
  background-color: var(--color-background);
}

.building-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-md);
  background-color: var(--color-gray-50);
  border-bottom: 1px solid var(--color-border);
}

.building-name {
  margin: 0;
  font-size: var(--font-size-lg);
  font-weight: 600;
  color: var(--color-text-primary);
}

.department-count {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
}

.departments-list {
  display: flex;
  flex-direction: column;
}

.department-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-md);
  border-bottom: 1px solid var(--color-border);
  transition: background-color 0.2s ease;
}

.department-item:last-child {
  border-bottom: none;
}

.department-item:hover {
  background-color: var(--color-gray-25);
}

.department-item.department-selected {
  background-color: var(--color-primary-light);
}

.department-info {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  flex: 1;
}

.department-name {
  font-weight: 500;
  color: var(--color-text-primary);
}

.department-color-indicator {
  display: flex;
  align-items: center;
}

.color-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  border: 1px solid var(--color-border);
}

.department-actions {
  flex-shrink: 0;
}

.modal-footer-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}

.footer-info {
  display: flex;
  align-items: center;
}

.selection-count {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
  font-weight: 500;
}

.footer-actions {
  display: flex;
  gap: var(--spacing-sm);
}

@media (max-width: 768px) {
  .department-selector {
    max-height: 50vh;
  }

  .department-item {
    flex-direction: column;
    align-items: stretch;
    gap: var(--spacing-sm);
  }

  .department-actions {
    align-self: flex-end;
  }

  .modal-footer-actions {
    flex-direction: column;
    gap: var(--spacing-md);
    align-items: stretch;
  }

  .footer-actions {
    order: -1;
  }
}
</style>
