<template>
  <BaseAssignmentCard
    :title="assignment.service?.name || 'Unknown Service'"
    :time-range="formatTimeRange(assignment.start_time, assignment.end_time)"
    :minimum-porters="assignment.minimum_porters"
    :porter-assignments="formattedPorterAssignments"
    :coverage-status="formattedCoverageStatus"
    @edit="$emit('edit', assignment)"
    @delete="$emit('delete', assignment)"
  >
    <template #footer>
      <div v-if="assignment.color" class="color-bar" :style="{ backgroundColor: assignment.color }"></div>
    </template>
  </BaseAssignmentCard>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useSupportServicesStore } from '../../stores/supportServicesStore'
import { useStaffStore } from '../../stores/staffStore'
import BaseAssignmentCard from '../ui/BaseAssignmentCard.vue'
import type { ServiceAssignment } from '../../types/supportServices'

interface Props {
  assignment: ServiceAssignment
}

interface Emits {
  (e: 'edit', assignment: ServiceAssignment): void
  (e: 'delete', assignment: ServiceAssignment): void
}

const props = defineProps<Props>()
defineEmits<Emits>()

const supportServicesStore = useSupportServicesStore()
const staffStore = useStaffStore()

const formatTimeRange = (startTime: string, endTime: string): string => {
  const formatTime = (time: string) => {
    const [hours, minutes] = time.split(':')
    return `${hours}:${minutes}`
  }
  return `${formatTime(startTime)} - ${formatTime(endTime)}`
}

// Get porter assignments for this service
const porterAssignments = computed(() => {
  return supportServicesStore.getPorterAssignmentsByServiceId(props.assignment.id) || []
})

// Get porter absence details
const getPorterAbsence = (porterId: string) => {
  const today = new Date()
  return staffStore.getPorterAbsenceDetails(porterId, today)
}

// Get absence badge CSS class
const getAbsenceBadgeClass = (porterId: string) => {
  const absence = getPorterAbsence(porterId)
  if (!absence) return ''

  switch (absence.absence_type) {
    case 'illness': return 'absence-illness'
    case 'annual_leave': return 'absence-annual-leave'
    default: return 'absence-other'
  }
}

// Get absence badge text
const getAbsenceBadgeText = (porterId: string) => {
  const absence = getPorterAbsence(porterId)
  if (!absence) return ''

  switch (absence.absence_type) {
    case 'illness': return 'ILL'
    case 'annual_leave': return 'AL'
    default: return 'ABS'
  }
}

// Format porter assignments for BaseAssignmentCard
const formattedPorterAssignments = computed(() => {
  return porterAssignments.value.map(porter => ({
    id: porter.id,
    name: `${porter.porter?.first_name} ${porter.porter?.last_name}`,
    timeRange: formatTimeRange(porter.start_time, porter.end_time),
    absenceBadge: getPorterAbsence(porter.porter_id) ? {
      text: getAbsenceBadgeText(porter.porter_id),
      class: getAbsenceBadgeClass(porter.porter_id)
    } : undefined
  }))
})

const coverageStatus = computed(() => {
  const gaps = supportServicesStore.getCoverageGaps(props.assignment.id)
  const shortages = supportServicesStore.getStaffingShortages(props.assignment.id)

  if (gaps.hasGap) return 'gap'
  if (shortages.hasShortage) return 'shortage'
  return 'covered'
})

// Format coverage status for BaseAssignmentCard
const formattedCoverageStatus = computed(() => ({
  type: coverageStatus.value as 'covered' | 'gap' | 'shortage',
  text: coverageStatus.value === 'covered' ? 'Fully Covered' :
        coverageStatus.value === 'gap' ? 'Coverage Gap' :
        coverageStatus.value === 'shortage' ? 'Staff Shortage' : 'Unknown'
}))
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
