<template>
  <BaseModal
    :title="title"
    size="lg"
    show-footer
    @close="closeModal"
  >
    <div v-if="loading" class="loading">
      Loading departments...
    </div>

    <div v-else-if="departments.length === 0" class="empty-state">
      <p>No departments available. Please add departments first.</p>
    </div>

    <div v-else class="assignments-form">
      <div class="form-description">
        <p>Select which departments this {{ isTaskType ? 'task type' : 'task item' }} applies to:</p>
        <div class="legend">
          <div class="legend-item">
            <span class="legend-color origin"></span>
            <span>Origin - Where tasks start</span>
          </div>
          <div class="legend-item">
            <span class="legend-color destination"></span>
            <span>Destination - Where tasks end</span>
          </div>
        </div>
      </div>

      <div class="departments-list">
        <div
          v-for="department in departments"
          :key="department.id"
          class="department-row"
        >
          <div class="department-info">
            <span class="department-name">{{ department.name }}</span>
            <span class="building-name">{{ getBuildingName(department.building_id) }}</span>
          </div>

          <div class="assignment-controls">
            <label class="checkbox-label">
              <input
                type="checkbox"
                :checked="getAssignment(department.id).is_origin"
                @change="updateAssignment(department.id, 'is_origin', ($event.target as HTMLInputElement).checked)"
              />
              <span class="checkbox-text">Origin</span>
            </label>

            <label class="checkbox-label">
              <input
                type="checkbox"
                :checked="getAssignment(department.id).is_destination"
                @change="updateAssignment(department.id, 'is_destination', ($event.target as HTMLInputElement).checked)"
              />
              <span class="checkbox-text">Destination</span>
            </label>
          </div>
        </div>
      </div>
    </div>

    <template #footer>
      <BaseButton @click="closeModal" variant="secondary">
        Cancel
      </BaseButton>
      <BaseButton
        @click="saveAssignments"
        variant="primary"
        :disabled="saving"
      >
        {{ saving ? 'Saving...' : 'Save Assignments' }}
      </BaseButton>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useTaskTypesStore } from '../../stores/taskTypesStore'
import { useLocationsStore } from '../../stores/locationsStore'
import type { DepartmentAssignmentData } from '../../types/taskTypes'
import BaseButton from '../ui/BaseButton.vue'
import BaseModal from '../ui/BaseModal.vue'

interface Props {
  taskTypeId?: string
  taskItemId?: string
  title: string
}

interface Emits {
  (e: 'close'): void
  (e: 'saved'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const taskTypesStore = useTaskTypesStore()
const locationsStore = useLocationsStore()

// State
const loading = ref(true)
const saving = ref(false)
const assignments = ref<Record<string, DepartmentAssignmentData>>({})

// Computed
const isTaskType = computed(() => !!props.taskTypeId)
const departments = computed(() => locationsStore.departments)
const buildings = computed(() => locationsStore.buildings)

// Methods
const getBuildingName = (buildingId: string): string => {
  const building = buildings.value.find(b => b.id === buildingId)
  return building?.name || 'Unknown Building'
}

const getAssignment = (departmentId: string): DepartmentAssignmentData => {
  return assignments.value[departmentId] || {
    department_id: departmentId,
    is_origin: false,
    is_destination: false
  }
}

const updateAssignment = (departmentId: string, field: 'is_origin' | 'is_destination', value: boolean) => {
  if (!assignments.value[departmentId]) {
    assignments.value[departmentId] = {
      department_id: departmentId,
      is_origin: false,
      is_destination: false
    }
  }

  assignments.value[departmentId][field] = value
}

const loadExistingAssignments = () => {
  if (props.taskTypeId) {
    // Load task type assignments
    const existingAssignments = taskTypesStore.getTypeAssignmentsByTypeId(props.taskTypeId)
    existingAssignments.forEach(assignment => {
      assignments.value[assignment.department_id] = {
        department_id: assignment.department_id,
        is_origin: assignment.is_origin,
        is_destination: assignment.is_destination
      }
    })
  } else if (props.taskItemId) {
    // Load task item assignments
    const existingAssignments = taskTypesStore.getItemAssignmentsByItemId(props.taskItemId)
    existingAssignments.forEach(assignment => {
      assignments.value[assignment.department_id] = {
        department_id: assignment.department_id,
        is_origin: assignment.is_origin,
        is_destination: assignment.is_destination
      }
    })
  }
}

const saveAssignments = async () => {
  saving.value = true

  try {
    const assignmentsList = Object.values(assignments.value)

    let success = false
    if (props.taskTypeId) {
      success = await taskTypesStore.updateTypeAssignments(props.taskTypeId, assignmentsList)
    } else if (props.taskItemId) {
      success = await taskTypesStore.updateItemAssignments(props.taskItemId, assignmentsList)
    }

    if (success) {
      emit('saved')
    }
  } catch (error) {
    console.error('Error saving assignments:', error)
  } finally {
    saving.value = false
  }
}

const closeModal = () => {
  emit('close')
}

// Initialize
onMounted(async () => {
  loading.value = true

  try {
    // Ensure locations are loaded
    if (locationsStore.buildings.length === 0) {
      await locationsStore.initialize()
    }

    // Load existing assignments
    loadExistingAssignments()
  } catch (error) {
    console.error('Error loading data:', error)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.loading {
  text-align: center;
  padding: var(--spacing-xl);
  color: var(--color-text-secondary);
}

.empty-state {
  text-align: center;
  padding: var(--spacing-xl);
  color: var(--color-text-secondary);
}

.empty-state p {
  margin: 0;
}

.form-description {
  margin-bottom: var(--spacing-lg);
}

.form-description p {
  margin: 0 0 var(--spacing-md);
  color: var(--color-text-secondary);
}

.legend {
  display: flex;
  gap: var(--spacing-lg);
  padding: var(--spacing-md);
  background: var(--color-gray-50);
  border-radius: var(--border-radius-md);
}

.legend-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  font-size: 0.875rem;
  color: var(--color-text-secondary);
}

.legend-color {
  width: 16px;
  height: 16px;
  border-radius: var(--border-radius-sm);
}

.legend-color.origin {
  background: var(--color-success);
}

.legend-color.destination {
  background: var(--color-primary);
}

.departments-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}

.department-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-md);
  background: white;
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  transition: all 0.2s ease;
}

.department-row:hover {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 1px var(--color-primary-alpha);
}

.department-info {
  flex: 1;
  min-width: 0;
}

.department-name {
  display: block;
  font-weight: 500;
  color: var(--color-text-primary);
}

.building-name {
  display: block;
  font-size: 0.875rem;
  color: var(--color-text-secondary);
}

.assignment-controls {
  display: flex;
  gap: var(--spacing-lg);
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  cursor: pointer;
  font-size: 0.875rem;
  color: var(--color-text-secondary);
}

.checkbox-label input[type="checkbox"] {
  margin: 0;
}

.checkbox-text {
  user-select: none;
}

@media (max-width: 768px) {
  .legend {
    flex-direction: column;
    gap: var(--spacing-sm);
  }

  .department-row {
    flex-direction: column;
    align-items: stretch;
    gap: var(--spacing-sm);
  }

  .assignment-controls {
    justify-content: center;
  }
}
</style>
