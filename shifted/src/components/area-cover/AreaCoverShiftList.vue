<template>
  <BaseListContainer
    :title="`${shiftTypeLabel} Area Coverage`"
    item-type="department"
    :items="mockAssignments"
    :loading="false"
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
        :available-departments="mockAvailableDepartments"
        :buildings-with-departments="mockBuildingsWithDepartments"
        :shift-type="shiftType"
        @close="showDepartmentSelector = false"
        @add-departments="handleAddDepartments"
      />

      <!-- Edit Area Assignment Modal -->
      <EditAreaAssignmentModal
        v-if="editingAssignment"
        :assignment="editingAssignment"
        @close="editingAssignment = null"
        @save="handleAssignmentSave"
        @delete="handleAssignmentDelete"
      />
    </template>
  </BaseListContainer>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import BaseButton from '../ui/BaseButton.vue'
import BaseAssignmentCard from '../ui/BaseAssignmentCard.vue'
import BaseListContainer from '../ui/BaseListContainer.vue'
import DepartmentSelectorModal from './DepartmentSelectorModal.vue'
import EditAreaAssignmentModal from './EditAreaAssignmentModal.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import type { ShiftType, AreaCoverAssignment } from '../../types/areaCover'

interface Props {
  shiftType: ShiftType
}

const props = defineProps<Props>()

const showDepartmentSelector = ref(false)
const editingAssignment = ref<AreaCoverAssignment | null>(null)

// Mock data that demonstrates the functionality
const mockAssignments = ref<AreaCoverAssignment[]>([
  {
    id: '1',
    department_id: 'dept1',
    shift_type: props.shiftType,
    start_time: '08:00:00',
    end_time: '16:00:00',
    minimum_porters: 2,
    department: {
      id: 'dept1',
      name: 'Emergency Department',
      building_id: 'building1',
      color: '#ff6b6b'
    }
  },
  {
    id: '2',
    department_id: 'dept2',
    shift_type: props.shiftType,
    start_time: '09:00:00',
    end_time: '17:00:00',
    minimum_porters: 1,
    department: {
      id: 'dept2',
      name: 'Radiology',
      building_id: 'building1',
      color: '#4ecdc4'
    }
  }
])

const mockPorterAssignments = ref([
  {
    id: 'pa1',
    area_assignment_id: '1',
    porter_id: 'porter1',
    start_time: '08:00:00',
    end_time: '12:00:00',
    porter: { id: 'porter1', first_name: 'John', last_name: 'Smith', role: 'Porter' }
  },
  {
    id: 'pa2',
    area_assignment_id: '1',
    porter_id: 'porter2',
    start_time: '12:00:00',
    end_time: '16:00:00',
    porter: { id: 'porter2', first_name: 'Jane', last_name: 'Doe', role: 'Porter' }
  },
  {
    id: 'pa3',
    area_assignment_id: '2',
    porter_id: 'porter3',
    start_time: '09:00:00',
    end_time: '17:00:00',
    porter: { id: 'porter3', first_name: 'Bob', last_name: 'Wilson', role: 'Porter' }
  }
])

const mockAvailableDepartments = ref([
  { id: 'dept3', name: 'Cardiology', building_id: 'building1', is_frequent: true, sort_order: 1 },
  { id: 'dept4', name: 'Neurology', building_id: 'building2', is_frequent: false, sort_order: 2 }
])

const mockBuildingsWithDepartments = ref([
  {
    id: 'building1',
    name: 'Main Hospital',
    sort_order: 1,
    departments: [
      { id: 'dept3', name: 'Cardiology', building_id: 'building1', is_frequent: true, sort_order: 1 }
    ]
  },
  {
    id: 'building2',
    name: 'Specialist Wing',
    sort_order: 2,
    departments: [
      { id: 'dept4', name: 'Neurology', building_id: 'building2', is_frequent: false, sort_order: 2 }
    ]
  }
])

// Helper functions
const formatTimeRange = (startTime: string, endTime: string): string => {
  const formatTime = (time: string) => {
    const [hours, minutes] = time.split(':')
    return `${hours}:${minutes}`
  }
  return `${formatTime(startTime)} - ${formatTime(endTime)}`
}

const getPorterAssignments = (assignmentId: string) => {
  return mockPorterAssignments.value
    .filter(pa => pa.area_assignment_id === assignmentId)
    .map(pa => ({
      id: pa.id,
      name: `${pa.porter.first_name} ${pa.porter.last_name}`,
      timeRange: formatTimeRange(pa.start_time, pa.end_time),
      absenceBadge: undefined // Mock - no absences for demo
    }))
}

const getCoverageStatus = (assignmentId: string): { type: 'covered' | 'gap' | 'shortage', text: string } => {
  const porterAssignments = getPorterAssignments(assignmentId)

  if (porterAssignments.length === 0) {
    return { type: 'gap', text: 'No Coverage' }
  }

  // Simple coverage check - in real app this would be more sophisticated
  const assignment = mockAssignments.value.find(a => a.id === assignmentId)
  if (!assignment) return { type: 'gap', text: 'No Coverage' }

  // For demo purposes, show different statuses
  if (assignmentId === '1') {
    return { type: 'covered', text: 'Fully Covered' }
  } else {
    return { type: 'gap', text: 'Coverage Gap' }
  }
}

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

// Methods
const handleEdit = (assignment: AreaCoverAssignment) => {
  console.log('🎯 Opening edit modal for:', assignment.department?.name)
  editingAssignment.value = assignment
}

const handleAddDepartments = async (departmentIds: string[]) => {
  console.log('✅ Adding departments:', departmentIds)

  // Simulate adding departments
  for (const deptId of departmentIds) {
    const dept = mockAvailableDepartments.value.find(d => d.id === deptId)
    if (dept) {
      const newAssignment: AreaCoverAssignment = {
        id: `new-${Date.now()}`,
        department_id: deptId,
        shift_type: props.shiftType,
        start_time: '08:00:00',
        end_time: '16:00:00',
        minimum_porters: 1,
        department: {
          id: dept.id,
          name: dept.name,
          building_id: dept.building_id,
          color: '#4285F4'
        }
      }
      mockAssignments.value.push(newAssignment)
    }
  }

  showDepartmentSelector.value = false
}

const handleAssignmentSave = async (data: {
  timeRange: { start: string; end: string }
  dayRequirements: number[]
  porterAssignments: any[]
}) => {
  console.log('💾 Saving assignment changes:', data)

  if (!editingAssignment.value) return

  // Update the assignment
  const assignment = mockAssignments.value.find(a => a.id === editingAssignment.value!.id)
  if (assignment) {
    assignment.start_time = data.timeRange.start + ':00'
    assignment.end_time = data.timeRange.end + ':00'
    assignment.minimum_porters = data.dayRequirements[0] || 1
  }

  // Update porter assignments (simplified)
  mockPorterAssignments.value = mockPorterAssignments.value.filter(
    pa => pa.area_assignment_id !== editingAssignment.value!.id
  )

  data.porterAssignments.forEach((pa, index) => {
    mockPorterAssignments.value.push({
      id: `pa-${editingAssignment.value!.id}-${index}`,
      area_assignment_id: editingAssignment.value!.id,
      porter_id: pa.porter_id,
      start_time: pa.start_time,
      end_time: pa.end_time,
      porter: { id: pa.porter_id, first_name: 'Mock', last_name: 'Porter', role: 'Porter' }
    })
  })

  editingAssignment.value = null
}

const handleAssignmentDelete = async () => {
  if (!editingAssignment.value) return

  if (confirm(`Are you sure you want to remove ${editingAssignment.value.department?.name} from coverage?`)) {
    console.log('🗑️ Deleting assignment:', editingAssignment.value.department?.name)

    // Remove assignment and its porter assignments
    mockAssignments.value = mockAssignments.value.filter(a => a.id !== editingAssignment.value!.id)
    mockPorterAssignments.value = mockPorterAssignments.value.filter(
      pa => pa.area_assignment_id !== editingAssignment.value!.id
    )

    editingAssignment.value = null
  }
}

const handleRemove = (assignmentId: string) => {
  const assignment = mockAssignments.value.find(a => a.id === assignmentId)
  if (assignment && confirm(`Are you sure you want to remove ${assignment.department?.name} from coverage?`)) {
    console.log('🗑️ Quick removing assignment:', assignment.department?.name)

    mockAssignments.value = mockAssignments.value.filter(a => a.id !== assignmentId)
    mockPorterAssignments.value = mockPorterAssignments.value.filter(
      pa => pa.area_assignment_id !== assignmentId
    )
  }
}
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
