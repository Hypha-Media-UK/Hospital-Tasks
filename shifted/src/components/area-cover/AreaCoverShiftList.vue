<template>
  <BaseListContainer
    :title="`${shiftTypeLabel} Area Coverage`"
    item-type="department"
    :items="assignments"
    :loading="areaCoverStore.loading.departments"
    :loading-text="`Loading ${shiftTypeLabel.toLowerCase()} coverage...`"
  >
    <template #header-actions>
      <BaseButton @click="showDepartmentSelector = true" variant="primary" size="sm">
        <PlusIcon class="w-4 h-4" />
        Add Department
      </BaseButton>
    </template>

    <template #empty-state>
      <p>No departments assigned to {{ shiftTypeLabel.toLowerCase() }} coverage.</p>
      <p>Add departments using the button above.</p>
    </template>

    <template #items="{ items }">
      <BaseAssignmentCard
        v-for="assignment in items"
        :key="assignment.id"
        :title="assignment.department?.name || 'Unknown Department'"
        :time-range="formatTimeRange(assignment.start_time, assignment.end_time)"
        :minimum-porters="assignment.minimum_porters"
        :porter-assignments="getPorterAssignments(assignment.id)"
        :coverage-status="getCoverageStatus(assignment.id)"
        @edit="handleEdit(assignment)"
        @delete="handleRemove(assignment.id)"
      >
        <template #footer>
          <div v-if="assignment.department?.color" class="color-bar" :style="{ backgroundColor: assignment.department.color }"></div>
        </template>
      </BaseAssignmentCard>
    </template>

    <template #modals>
      <!-- Department Selector Modal -->
      <DepartmentSelectorModal
        v-if="showDepartmentSelector"
        :available-departments="availableDepartments"
        :buildings-with-departments="buildingsWithDepartments"
        :shift-type="shiftType"
        @close="showDepartmentSelector = false"
        @add-departments="handleAddDepartments"
      />

      <!-- Edit Department Modal -->
      <EditDepartmentModal
        v-if="editingAssignment"
        :assignment="editingAssignment"
        @close="editingAssignment = null"
        @saved="handleAssignmentSaved"
      />
    </template>
  </BaseListContainer>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useAreaCoverStore } from '../../stores/areaCoverStore'
import { useLocationsStore } from '../../stores/locationsStore'
import BaseButton from '../ui/BaseButton.vue'
import BaseAssignmentCard from '../ui/BaseAssignmentCard.vue'
import BaseListContainer from '../ui/BaseListContainer.vue'
import DepartmentSelectorModal from './DepartmentSelectorModal.vue'
import EditDepartmentModal from './EditDepartmentModal.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import type { ShiftType, AreaCoverAssignment } from '../../types/areaCover'

interface Props {
  shiftType: ShiftType
}

const props = defineProps<Props>()

const areaCoverStore = useAreaCoverStore()
const locationsStore = useLocationsStore()

const showDepartmentSelector = ref(false)
const editingAssignment = ref<AreaCoverAssignment | null>(null)


// Helper functions
const formatTimeRange = (startTime: string, endTime: string): string => {
  const formatTime = (time: string) => {
    const [hours, minutes] = time.split(':')
    return `${hours}:${minutes}`
  }
  return `${formatTime(startTime)} - ${formatTime(endTime)}`
}

const getPorterAssignments = (assignmentId: string) => {
  const porterAssignments = areaCoverStore.getPorterAssignmentsByAreaId(assignmentId)
  return porterAssignments.map(pa => ({
    id: pa.id,
    name: `${pa.porter?.first_name || 'Unknown'} ${pa.porter?.last_name || 'Porter'}`,
    timeRange: formatTimeRange(pa.start_time, pa.end_time),
    absenceBadge: undefined // TODO: Add absence checking
  }))
}

const getCoverageStatus = (assignmentId: string): { type: 'covered' | 'gap' | 'shortage', text: string } => {
  const coverageAnalysis = areaCoverStore.getCoverageIssues(assignmentId)

  if (!coverageAnalysis.hasIssues) {
    return { type: 'covered', text: 'Fully Covered' }
  }

  // Check if there are any gaps (no coverage at all)
  const hasGaps = coverageAnalysis.issues.some(issue => issue.type === 'gap')
  if (hasGaps) {
    return { type: 'gap', text: 'Coverage Gap' }
  }

  // Check if there are staffing shortages
  const hasShortages = coverageAnalysis.issues.some(issue => issue.type === 'shortage')
  if (hasShortages) {
    return { type: 'shortage', text: 'Staffing Shortage' }
  }

  return { type: 'covered', text: 'Fully Covered' }
}

// Computed properties
const assignments = computed(() => {
  return areaCoverStore.getSortedAssignmentsByType(props.shiftType)
})

const availableDepartments = computed(() => {
  return locationsStore.departments.filter(dept =>
    !assignments.value.some(assignment => assignment.department_id === dept.id)
  )
})

const buildingsWithDepartments = computed(() => {
  return locationsStore.buildingsWithDepartments.map(building => ({
    ...building,
    departments: building.departments.filter(dept =>
      !assignments.value.some(assignment => assignment.department_id === dept.id)
    )
  })).filter(building => building.departments.length > 0)
})

const shiftTypeLabel = computed(() => {
  switch (props.shiftType) {
    case 'week_day': return 'Week Day'
    case 'week_night': return 'Week Night'
    case 'weekend_day': return 'Weekend Day'
    case 'weekend_night': return 'Weekend Night'
    default: return ''
  }
})

// Methods
const handleEdit = (assignment: AreaCoverAssignment) => {
  console.log('🎯 Opening edit modal for:', assignment.department?.name)
  editingAssignment.value = assignment
}

const handleAddDepartments = async (departmentIds: string[]) => {
  console.log('✅ Adding departments:', departmentIds)

  try {
    for (const deptId of departmentIds) {
      await areaCoverStore.addDepartment(
        deptId,
        props.shiftType,
        '08:00:00',
        '16:00:00',
        '#4285F4'
      )
    }
    console.log('✅ Departments added successfully')
  } catch (error) {
    console.error('❌ Error adding departments:', error)
    alert('Failed to add departments. Please try again.')
  }

  showDepartmentSelector.value = false
}

const handleAssignmentSaved = async () => {
  console.log('✅ Assignment saved successfully')
  editingAssignment.value = null
  // Refresh the data to show updated information
  await areaCoverStore.fetchAreaAssignments()
}

const handleRemove = async (assignmentId: string) => {
  const assignment = assignments.value.find(a => a.id === assignmentId)
  if (assignment && confirm(`Are you sure you want to remove ${assignment.department?.name} from coverage?`)) {
    console.log('🗑️ Removing assignment:', assignment.department?.name)

    try {
      await areaCoverStore.removeDepartment(assignmentId)
      console.log('✅ Assignment removed successfully')
    } catch (error) {
      console.error('❌ Error removing assignment:', error)
      alert('Failed to remove assignment. Please try again.')
    }
  }
}

// Initialize data on component mount
onMounted(async () => {
  console.log('🚀 AreaCoverShiftList mounted, loading data...')
  await Promise.all([
    areaCoverStore.fetchAreaAssignments(),
    locationsStore.fetchDepartments()
  ])
  console.log('✅ Area cover data loaded')
})
</script>

<style scoped>
.color-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 3px;
}
</style>
