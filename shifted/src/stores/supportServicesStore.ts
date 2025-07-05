import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../services/supabase'
import type {
  SupportService,
  ServiceAssignment,
  PorterAssignment,
  ShiftType,
  CoverageGap,
  StaffingShortage,
  CoverageIssue
} from '../types/supportServices'

export const useSupportServicesStore = defineStore('supportServices', () => {
  // State
  const services = ref<SupportService[]>([])
  const serviceAssignments = ref<ServiceAssignment[]>([])
  const porterAssignments = ref<PorterAssignment[]>([])
  const loading = ref({
    services: false,
    save: false
  })
  const error = ref<string | null>(null)

  // Getters
  const sortedServices = computed(() =>
    [...services.value].sort((a, b) => a.name.localeCompare(b.name))
  )

  const activeSupportServices = computed(() =>
    services.value.filter(service => service.is_active !== false)
  )

  const getAssignmentsByShiftType = computed(() => (shiftType: ShiftType) =>
    serviceAssignments.value.filter(a => a.shift_type === shiftType)
  )

  const getPorterAssignmentsByServiceId = computed(() => (serviceAssignmentId: string) =>
    porterAssignments.value.filter(pa =>
      pa.default_service_cover_assignment_id === serviceAssignmentId ||
      pa.support_service_assignment_id === serviceAssignmentId
    )
  )

  // Helper functions
  const timeToMinutes = (timeStr: string): number => {
    if (!timeStr) return 0
    const [hours, minutes] = timeStr.split(':').map(Number)
    return (hours * 60) + minutes
  }

  const minutesToTime = (minutes: number): string => {
    const hours = Math.floor(minutes / 60)
    const mins = minutes % 60
    return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}:00`
  }

  // Coverage analysis
  const getCoverageGaps = (serviceId: string): { hasGap: boolean; gaps: CoverageGap[] } => {
    try {
      const assignment = serviceAssignments.value.find(a => a.id === serviceId)
      if (!assignment) return { hasGap: false, gaps: [] }

      const assignments = porterAssignments.value.filter(
        pa => pa.default_service_cover_assignment_id === serviceId ||
              pa.support_service_assignment_id === serviceId
      )

      if (assignments.length === 0) {
        return {
          hasGap: true,
          gaps: [{
            startTime: assignment.start_time,
            endTime: assignment.end_time,
            type: 'gap'
          }]
        }
      }

      const serviceStart = timeToMinutes(assignment.start_time)
      const serviceEnd = timeToMinutes(assignment.end_time)

      // Check if any porter covers the entire period
      const fullCoverageExists = assignments.some(pa => {
        const porterStart = timeToMinutes(pa.start_time)
        const porterEnd = timeToMinutes(pa.end_time)
        return porterStart <= serviceStart && porterEnd >= serviceEnd
      })

      if (fullCoverageExists) {
        return { hasGap: false, gaps: [] }
      }

      const sortedAssignments = [...assignments].sort((a, b) =>
        timeToMinutes(a.start_time) - timeToMinutes(b.start_time)
      )

      const gaps: CoverageGap[] = []

      // Check for gap at the beginning
      if (timeToMinutes(sortedAssignments[0].start_time) > serviceStart) {
        gaps.push({
          startTime: assignment.start_time,
          endTime: sortedAssignments[0].start_time,
          type: 'gap'
        })
      }

      // Check for gaps between assignments
      for (let i = 0; i < sortedAssignments.length - 1; i++) {
        const currentEnd = timeToMinutes(sortedAssignments[i].end_time)
        const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time)

        if (nextStart > currentEnd) {
          gaps.push({
            startTime: sortedAssignments[i].end_time,
            endTime: sortedAssignments[i + 1].start_time,
            type: 'gap'
          })
        }
      }

      // Check for gap at the end
      const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time)
      if (lastEnd < serviceEnd) {
        gaps.push({
          startTime: sortedAssignments[sortedAssignments.length - 1].end_time,
          endTime: assignment.end_time,
          type: 'gap'
        })
      }

      return {
        hasGap: gaps.length > 0,
        gaps
      }
    } catch (error) {
      console.error('Error in getCoverageGaps:', error)
      return { hasGap: false, gaps: [] }
    }
  }

  const getStaffingShortages = (serviceId: string): { hasShortage: boolean; shortages: StaffingShortage[] } => {
    try {
      const assignment = serviceAssignments.value.find(a => a.id === serviceId)
      if (!assignment) return { hasShortage: false, shortages: [] }

      // If no minimum porters set, no shortage possible
      if (!assignment.minimum_porters &&
          !assignment.minimum_porters_mon &&
          !assignment.minimum_porters_tue &&
          !assignment.minimum_porters_wed &&
          !assignment.minimum_porters_thu &&
          !assignment.minimum_porters_fri &&
          !assignment.minimum_porters_sat &&
          !assignment.minimum_porters_sun) {
        return { hasShortage: false, shortages: [] }
      }

      const assignments = porterAssignments.value.filter(
        pa => pa.default_service_cover_assignment_id === serviceId ||
              pa.support_service_assignment_id === serviceId
      )

      if (assignments.length === 0) {
        return {
          hasShortage: true,
          shortages: [{
            startTime: assignment.start_time,
            endTime: assignment.end_time,
            type: 'shortage',
            porterCount: 0,
            requiredCount: assignment.minimum_porters || 1
          }]
        }
      }

      // Implementation would continue with time segment analysis...
      // For now, return basic implementation
      return { hasShortage: false, shortages: [] }
    } catch (error) {
      console.error('Error in getStaffingShortages:', error)
      return { hasShortage: false, shortages: [] }
    }
  }

  const getCoverageIssues = (serviceId: string): { hasIssues: boolean; issues: CoverageIssue[] } => {
    const gaps = getCoverageGaps(serviceId).gaps
    const shortages = getStaffingShortages(serviceId).shortages

    const allIssues = [...gaps, ...shortages].sort((a, b) =>
      timeToMinutes(a.startTime) - timeToMinutes(b.startTime)
    )

    return {
      hasIssues: allIssues.length > 0,
      issues: allIssues
    }
  }

  // Actions
  const fetchServices = async (): Promise<void> => {
    loading.value.services = true
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('support_services')
        .select('*')
        .order('name')

      if (fetchError) throw fetchError

      services.value = data || []
    } catch (err) {
      console.error('Error fetching support services:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
    } finally {
      loading.value.services = false
    }
  }

  const fetchServiceAssignments = async (): Promise<ServiceAssignment[]> => {
    loading.value.services = true
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('default_service_cover_assignments')
        .select(`
          *,
          service:service_id(id, name, description)
        `)
        .order('service_id')

      if (fetchError) throw fetchError

      serviceAssignments.value = data || []

      // Fetch porter assignments
      if (data && data.length > 0) {
        const assignmentIds = data.map(a => a.id)

        const { data: porterData, error: porterError } = await supabase
          .from('default_service_cover_porter_assignments')
          .select(`
            *,
            porter:porter_id(id, first_name, last_name, role)
          `)
          .in('default_service_cover_assignment_id', assignmentIds)

        if (porterError) throw porterError

        porterAssignments.value = porterData || []
      } else {
        porterAssignments.value = []
      }

      return serviceAssignments.value
    } catch (err) {
      console.error('Error fetching service assignments:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return []
    } finally {
      loading.value.services = false
    }
  }

  const addService = async (name: string, description?: string): Promise<SupportService | null> => {
    loading.value.save = true
    error.value = null

    try {
      const { data, error: insertError } = await supabase
        .from('support_services')
        .insert({ name, description })
        .select()

      if (insertError) throw insertError

      if (data && data.length > 0) {
        services.value.push(data[0])
        return data[0]
      }

      return null
    } catch (err) {
      console.error('Error adding support service:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    } finally {
      loading.value.save = false
    }
  }

  const updateService = async (id: string, updates: Partial<SupportService>): Promise<SupportService | null> => {
    loading.value.save = true
    error.value = null

    try {
      const { data, error: updateError } = await supabase
        .from('support_services')
        .update(updates)
        .eq('id', id)
        .select()

      if (updateError) throw updateError

      if (data && data.length > 0) {
        const index = services.value.findIndex(s => s.id === id)
        if (index !== -1) {
          services.value[index] = data[0]
        }
        return data[0]
      }

      return null
    } catch (err) {
      console.error('Error updating support service:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    } finally {
      loading.value.save = false
    }
  }

  const deleteService = async (id: string): Promise<boolean> => {
    loading.value.save = true
    error.value = null

    try {
      const { error: deleteError } = await supabase
        .from('support_services')
        .delete()
        .eq('id', id)

      if (deleteError) throw deleteError

      services.value = services.value.filter(s => s.id !== id)
      return true
    } catch (err) {
      console.error('Error deleting support service:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return false
    } finally {
      loading.value.save = false
    }
  }

  const initialize = async (): Promise<void> => {
    await Promise.all([
      fetchServices(),
      fetchServiceAssignments()
    ])
  }

  return {
    // State
    services,
    serviceAssignments,
    porterAssignments,
    loading,
    error,

    // Getters
    sortedServices,
    activeSupportServices,
    getAssignmentsByShiftType,
    getPorterAssignmentsByServiceId,
    getCoverageGaps,
    getStaffingShortages,
    getCoverageIssues,

    // Actions
    fetchServices,
    fetchServiceAssignments,
    addService,
    updateService,
    deleteService,
    initialize
  }
})
