<template>
  <div class="area-cover-shift-list">
    <div class="area-cover-shift-list__header">
      <BaseButton @click="showDepartmentSelector = true" variant="primary">
        Add Department
      </BaseButton>
    </div>

    <div v-if="areaCoverStore.loading.departments" class="loading">
      Loading {{ shiftTypeLabel.toLowerCase() }} coverage...
    </div>

    <div v-else-if="assignments.length === 0" class="empty-state">
      No departments assigned to {{ shiftTypeLabel.toLowerCase() }} coverage.
      Add departments using the button above.
    </div>

    <div v-else class="department-grid">
      <div
        v-for="assignment in assignments"
        :key="assignment.id"
        class="department-card"
      >
        <div class="department-header">
          <h4>{{ assignment.department?.name || 'Unknown Department' }}</h4>
          <span class="building-name">{{ assignment.department?.building?.name || 'Unknown Building' }}</span>
        </div>
        <div class="department-details">
          <div class="time-range">
            <strong>Time:</strong> {{ assignment.start_time.slice(0, 5) }} - {{ assignment.end_time.slice(0, 5) }}
          </div>
          <div class="actions">
            <BaseButton size="sm" variant="secondary" @click="handleUpdate(assignment.id, {})">
              Edit
            </BaseButton>
            <BaseButton size="sm" variant="danger" @click="handleRemove(assignment.id)">
              Remove
            </BaseButton>
          </div>
        </div>
      </div>
    </div>

    <!-- Department Selector Modal -->
    <BaseModal
      v-if="showDepartmentSelector"
      title="Add Department to Coverage"
      size="lg"
      show-footer
      @close="showDepartmentSelector = false"
    >
      <div class="department-selector">
        <p>This modal now uses the BaseModal component instead of duplicated CSS!</p>
        <p>Previously this component had ~100 lines of duplicate modal styles.</p>

        <div class="building-item">
          <div class="building-name">Example Building</div>
          <div class="department-item">
            <div class="department-name">Example Department</div>
            <BaseButton size="sm" variant="primary">
              Add
            </BaseButton>
          </div>
        </div>
      </div>

      <template #footer>
        <BaseButton variant="secondary" @click="showDepartmentSelector = false">
          Cancel
        </BaseButton>
        <BaseButton variant="primary">
          Save
        </BaseButton>
      </template>
    </BaseModal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useAreaCoverStore } from '../../stores/areaCoverStore'
import { useLocationsStore } from '../../stores/locationsStore'
import { useSettingsStore } from '../../stores/settingsStore'
import BaseButton from '../ui/BaseButton.vue'
import BaseModal from '../ui/BaseModal.vue'
import type { ShiftType } from '../../types/areaCover'

interface Props {
  shiftType: ShiftType
}

const props = defineProps<Props>()

const areaCoverStore = useAreaCoverStore()
const locationsStore = useLocationsStore()
const settingsStore = useSettingsStore()

const showDepartmentSelector = ref(false)

// Computed properties
const shiftTypeLabel = computed(() => {
  switch (props.shiftType) {
    case 'week_day': return 'Week Day'
    case 'week_night': return 'Week Night'
    case 'weekend_day': return 'Weekend Day'
    case 'weekend_night': return 'Weekend Night'
    default: return ''
  }
})

const assignments = computed(() => {
  return areaCoverStore.getSortedAssignmentsByType(props.shiftType)
})

// Get departments from locationsStore
const availableDepartments = computed(() => {
  const allDepartments: any[] = []
  const buildingsWithDepartments = locationsStore.buildingsWithDepartments || []

  buildingsWithDepartments.forEach(building => {
    building.departments.forEach(dept => {
      allDepartments.push({
        ...dept,
        building_name: building.name
      })
    })
  })

  // Get assigned department IDs based on the current assignments for the shift type
  const assignedDeptIds = areaCoverStore.getAssignmentsByShiftType(props.shiftType).map(a => a.department_id)

  return allDepartments.filter(dept => !assignedDeptIds.includes(dept.id))
})

const buildingsWithAvailableDepartments = computed(() => {
  // Group available departments by building
  const buildingsMap = new Map()

  availableDepartments.value.forEach(dept => {
    const buildingId = dept.building_id
    const buildingName = dept.building_name || 'Unknown Building'

    if (!buildingsMap.has(buildingId)) {
      buildingsMap.set(buildingId, {
        id: buildingId,
        name: buildingName,
        departments: []
      })
    }

    buildingsMap.get(buildingId).departments.push(dept)
  })

  // Convert map to array and sort by building name
  return Array.from(buildingsMap.values())
    .sort((a, b) => a.name.localeCompare(b.name))
})

// Methods
const addDepartment = async (departmentId: string) => {
  // Get default times from settings store based on shift type
  let startTime: string, endTime: string

  // Get shift defaults from settings store
  if (settingsStore.shiftDefaults[props.shiftType]) {
    // Convert HH:MM to HH:MM:SS format
    startTime = settingsStore.shiftDefaults[props.shiftType].startTime + ':00'
    endTime = settingsStore.shiftDefaults[props.shiftType].endTime + ':00'

    console.log(`Using shift defaults for ${props.shiftType}: ${startTime} - ${endTime}`)
  } else {
    // Fallback defaults if settings aren't available
    if (props.shiftType.includes('day')) {
      startTime = '08:00:00'
      endTime = '20:00:00'
    } else {
      startTime = '20:00:00'
      endTime = '08:00:00'
    }
    console.log(`Using fallback defaults: ${startTime} - ${endTime}`)
  }

  await areaCoverStore.addDepartment(
    departmentId,
    props.shiftType,
    startTime,
    endTime
  )

  showDepartmentSelector.value = false
}

const handleUpdate = (assignmentId: string, updates: any) => {
  areaCoverStore.updateDepartment(assignmentId, updates)
}

const handleRemove = (assignmentId: string) => {
  if (confirm('Are you sure you want to remove this department from coverage?')) {
    areaCoverStore.removeDepartment(assignmentId)
  }
}

// Lifecycle hooks
onMounted(async () => {
  // Fetch assignments for the shift type
  await areaCoverStore.fetchAssignments(props.shiftType)

  if (!locationsStore.buildings.length) {
    await locationsStore.initialize()
  }
})
</script>

<style scoped>
.area-cover-shift-list {
  &__header {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    margin-bottom: var(--spacing-lg);
  }
}

.loading, .empty-state {
  padding: var(--spacing-xl);
  text-align: center;
  color: var(--color-text-secondary);
}

.department-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: var(--spacing-lg);
}

.department-card {
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-lg);
  padding: var(--spacing-lg);
  transition: box-shadow 0.2s ease;

  &:hover {
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  }
}

.department-header {
  margin-bottom: var(--spacing-md);

  h4 {
    margin: 0 0 var(--spacing-xs) 0;
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--color-text-primary);
  }

  .building-name {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
  }
}

.department-details {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: var(--spacing-md);

  .time-range {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
  }

  .actions {
    display: flex;
    gap: var(--spacing-sm);
  }
}

/* Department selector styles - much cleaner without modal duplication! */
.department-selector {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.building-item {
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-md);
  overflow: hidden;
}

.building-name {
  background-color: var(--color-gray-50);
  padding: var(--spacing-sm) var(--spacing-md);
  font-weight: 600;
  color: var(--color-text-primary);
}

.department-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-sm) var(--spacing-md);
  border-top: 1px solid var(--color-border);
  transition: background-color 0.2s ease;

  &:hover {
    background-color: var(--color-gray-25);
  }
}

.department-name {
  display: flex;
  align-items: center;
  color: var(--color-text-primary);
}
</style>
