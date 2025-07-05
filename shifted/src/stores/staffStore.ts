import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../services/supabase'
import type {
  Staff,
  PorterAbsence,
  StaffFilters,
  StaffLoadingState,
  AvailabilityPattern,
  ShiftDefaults,
  ShiftType
} from '../types/staff'

export const useStaffStore = defineStore('staff', () => {
  // State
  const staff = ref<Staff[]>([])
  const supervisors = ref<Staff[]>([])
  const porters = ref<Staff[]>([])
  const porterAbsences = ref<PorterAbsence[]>([])
  const loading = ref<StaffLoadingState>({
    supervisors: false,
    porters: false,
    staff: false,
    absences: false
  })
  const error = ref<string | null>(null)

  // Filters
  const filters = ref<StaffFilters>({
    sortBy: 'firstName',
    porterTypeFilter: 'all',
    shiftTimeFilter: 'all',
    sortDirection: 'asc',
    searchQuery: ''
  })

  // Availability patterns
  const availabilityPatterns: AvailabilityPattern[] = [
    'Weekdays - Days',
    'Weekdays - Nights',
    'Weekdays - Days and Nights',
    'Weekends - Days',
    'Weekends - Nights',
    'Weekends - Days and Nights',
    '4 on 4 off - Days',
    '4 on 4 off - Nights',
    '4 on 4 off - Days and Nights'
  ]

  // Getters
  const sortedSupervisors = computed(() => {
    return supervisors.value.slice().sort((a, b) => {
      if (filters.value.sortBy === 'firstName') {
        return a.first_name.localeCompare(b.first_name)
      } else {
        return a.last_name.localeCompare(b.last_name)
      }
    })
  })

  const sortedPorters = computed(() => {
    let filteredPorters = [...porters.value]

    // Apply porter type filter
    if (filters.value.porterTypeFilter !== 'all') {
      filteredPorters = filteredPorters.filter(porter =>
        porter.porter_type === filters.value.porterTypeFilter
      )
    }

    // Apply search query filter
    if (filters.value.searchQuery.trim()) {
      const query = filters.value.searchQuery.toLowerCase().trim()
      filteredPorters = filteredPorters.filter(porter => {
        const fullName = `${porter.first_name} ${porter.last_name}`.toLowerCase()
        return fullName.includes(query)
      })
    }

    // Sort the filtered list
    return filteredPorters.sort((a, b) => {
      let comparison = 0
      if (filters.value.sortBy === 'firstName') {
        comparison = a.first_name.localeCompare(b.first_name)
      } else {
        comparison = a.last_name.localeCompare(b.last_name)
      }

      return filters.value.sortDirection === 'asc' ? comparison : -comparison
    })
  })

  const activeSupervisors = computed(() => {
    return supervisors.value.filter(supervisor => supervisor.active !== false)
  })

  const getStaffByIdComputed = computed(() => (id: string) => {
    return [...supervisors.value, ...porters.value].find(staff => staff.id === id)
  })

  const isPorterAbsent = computed(() => (porterId: string, date: Date | string) => {
    const checkDate = typeof date === 'string' ? new Date(date) : date

    return porterAbsences.value.some(absence => {
      const startDate = new Date(absence.start_date)
      const endDate = new Date(absence.end_date)
      return absence.porter_id === porterId &&
             checkDate >= startDate &&
             checkDate <= endDate
    })
  })

  const getPorterAbsenceDetails = computed(() => (porterId: string, date: Date | string) => {
    const checkDate = typeof date === 'string' ? new Date(date) : date

    return porterAbsences.value.find(absence => {
      const startDate = new Date(absence.start_date)
      const endDate = new Date(absence.end_date)
      return absence.porter_id === porterId &&
             checkDate >= startDate &&
             checkDate <= endDate
    }) || null
  })

  const formatAvailability = (porter: Staff): string => {
    if (porter.availability_pattern) {
      if (porter.availability_pattern.includes('Days and Nights')) {
        return `${porter.availability_pattern} (24hrs)`
      } else if (porter.contracted_hours_start && porter.contracted_hours_end) {
        return `${porter.availability_pattern} (${porter.contracted_hours_start.substring(0, 5)}-${porter.contracted_hours_end.substring(0, 5)})`
      } else {
        return porter.availability_pattern
      }
    }
    return 'No availability set'
  }

  const getPorterShiftType = (porter: Staff, shiftDefaults: ShiftDefaults): ShiftType => {
    if (!porter.contracted_hours_start || !porter.contracted_hours_end || !shiftDefaults) {
      return 'unknown'
    }

    const porterStart = porter.contracted_hours_start.substring(0, 5)
    const porterEnd = porter.contracted_hours_end.substring(0, 5)

    const dayStart = shiftDefaults.week_day.startTime
    const dayEnd = shiftDefaults.week_day.endTime
    const nightStart = shiftDefaults.week_night.startTime
    const nightEnd = shiftDefaults.week_night.endTime

    const timeToMinutes = (timeStr: string) => {
      const [hours, minutes] = timeStr.split(':').map(Number)
      return hours * 60 + minutes
    }

    const porterStartMin = timeToMinutes(porterStart)
    const porterEndMin = timeToMinutes(porterEnd)
    const dayStartMin = timeToMinutes(dayStart)
    const dayEndMin = timeToMinutes(dayEnd)
    const nightStartMin = timeToMinutes(nightStart)
    const nightEndMin = timeToMinutes(nightEnd)

    // Calculate overlap with day shift
    let dayOverlap = 0
    if (porterStartMin <= dayEndMin && porterEndMin >= dayStartMin) {
      const overlapStart = Math.max(porterStartMin, dayStartMin)
      const overlapEnd = Math.min(porterEndMin, dayEndMin)
      dayOverlap = Math.max(0, overlapEnd - overlapStart)
    }

    // Calculate overlap with night shift
    let nightOverlap = 0
    if (porterStartMin <= nightEndMin && porterEndMin >= nightStartMin) {
      const overlapStart = Math.max(porterStartMin, nightStartMin)
      const overlapEnd = Math.min(porterEndMin, nightEndMin)
      nightOverlap = Math.max(0, overlapEnd - overlapStart)
    }

    if (dayOverlap > nightOverlap) {
      return 'day'
    } else if (nightOverlap > dayOverlap) {
      return 'night'
    } else {
      return 'unknown'
    }
  }

  // Actions
  const fetchSupervisors = async (): Promise<Staff[]> => {
    loading.value.supervisors = true
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('staff')
        .select('*')
        .eq('role', 'supervisor')
        .order('first_name', { ascending: true })

      if (fetchError) throw fetchError

      supervisors.value = data || []
      return data || []
    } catch (err) {
      console.error('Error fetching supervisors:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return []
    } finally {
      loading.value.supervisors = false
    }
  }

  const fetchAllStaff = async (): Promise<Staff[]> => {
    loading.value.staff = true
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('staff')
        .select('*')
        .order('first_name', { ascending: true })

      if (fetchError) throw fetchError

      staff.value = data || []
      return data || []
    } catch (err) {
      console.error('Error fetching staff:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return []
    } finally {
      loading.value.staff = false
    }
  }

  const getStaffById = async (staffId: string): Promise<Staff | null> => {
    try {
      const { data, error: fetchError } = await supabase
        .from('staff')
        .select('*')
        .eq('id', staffId)
        .single()

      if (fetchError) throw fetchError

      return data
    } catch (err) {
      console.error('Error fetching staff member:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    }
  }

  const createStaffMember = async (staffData: Omit<Staff, 'id' | 'created_at' | 'updated_at'>): Promise<Staff | null> => {
    try {
      const { data, error: createError } = await supabase
        .from('staff')
        .insert([staffData])
        .select()
        .single()

      if (createError) throw createError

      // Add to appropriate local state
      if (staffData.role === 'supervisor') {
        supervisors.value.push(data)
      }
      staff.value.push(data)

      return data
    } catch (err) {
      console.error('Error creating staff member:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    }
  }

  const updateStaffMember = async (staffId: string, updates: Partial<Staff>): Promise<Staff | null> => {
    try {
      const { data, error: updateError } = await supabase
        .from('staff')
        .update(updates)
        .eq('id', staffId)
        .select()
        .single()

      if (updateError) throw updateError

      // Update local state
      const staffIndex = staff.value.findIndex(member => member.id === staffId)
      if (staffIndex !== -1) {
        staff.value[staffIndex] = data
      }

      const supervisorIndex = supervisors.value.findIndex(supervisor => supervisor.id === staffId)
      if (supervisorIndex !== -1) {
        supervisors.value[supervisorIndex] = data
      }

      return data
    } catch (err) {
      console.error('Error updating staff member:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    }
  }

  const deleteStaffMember = async (staffId: string): Promise<boolean> => {
    try {
      const { error: deleteError } = await supabase
        .from('staff')
        .delete()
        .eq('id', staffId)

      if (deleteError) throw deleteError

      // Remove from local state
      staff.value = staff.value.filter(member => member.id !== staffId)
      supervisors.value = supervisors.value.filter(supervisor => supervisor.id !== staffId)

      return true
    } catch (err) {
      console.error('Error deleting staff member:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return false
    }
  }

  // Porter-specific actions
  const fetchPorters = async (): Promise<Staff[]> => {
    loading.value.porters = true
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('staff')
        .select('*, department:department_id(id, name, building_id)')
        .eq('role', 'porter')
        .order('first_name')

      if (fetchError) throw fetchError

      porters.value = data || []
      return data || []
    } catch (err) {
      console.error('Error fetching porters:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return []
    } finally {
      loading.value.porters = false
    }
  }

  // Absence management
  const fetchPorterAbsences = async (): Promise<PorterAbsence[]> => {
    loading.value.absences = true
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('porter_absences')
        .select('*, porter:porter_id(id, first_name, last_name)')
        .order('start_date')

      if (fetchError) throw fetchError

      porterAbsences.value = data || []
      return data || []
    } catch (err) {
      console.error('Error fetching porter absences:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return []
    } finally {
      loading.value.absences = false
    }
  }

  const addPorterAbsence = async (absenceData: Omit<PorterAbsence, 'id' | 'created_at' | 'updated_at'>): Promise<PorterAbsence | null> => {
    loading.value.absences = true
    error.value = null

    try {
      const { data, error: insertError } = await supabase
        .from('porter_absences')
        .insert(absenceData)
        .select('*, porter:porter_id(id, first_name, last_name)')

      if (insertError) throw insertError

      if (data && data.length > 0) {
        porterAbsences.value.push(data[0])
        return data[0]
      }

      return null
    } catch (err) {
      console.error('Error adding porter absence:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    } finally {
      loading.value.absences = false
    }
  }

  const updatePorterAbsence = async (id: string, updates: Partial<PorterAbsence>): Promise<PorterAbsence | null> => {
    loading.value.absences = true
    error.value = null

    try {
      const { data, error: updateError } = await supabase
        .from('porter_absences')
        .update(updates)
        .eq('id', id)
        .select('*, porter:porter_id(id, first_name, last_name)')

      if (updateError) throw updateError

      if (data && data.length > 0) {
        const index = porterAbsences.value.findIndex(a => a.id === id)
        if (index !== -1) {
          porterAbsences.value[index] = data[0]
        }
        return data[0]
      }

      return null
    } catch (err) {
      console.error('Error updating porter absence:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    } finally {
      loading.value.absences = false
    }
  }

  const deletePorterAbsence = async (id: string): Promise<boolean> => {
    loading.value.absences = true
    error.value = null

    try {
      const { error: deleteError } = await supabase
        .from('porter_absences')
        .delete()
        .eq('id', id)

      if (deleteError) throw deleteError

      porterAbsences.value = porterAbsences.value.filter(a => a.id !== id)
      return true
    } catch (err) {
      console.error('Error deleting porter absence:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return false
    } finally {
      loading.value.absences = false
    }
  }

  // Filter actions
  const setSortBy = (sortField: 'firstName' | 'lastName'): void => {
    filters.value.sortBy = sortField
  }

  const setPorterTypeFilter = (filterType: 'all' | 'shift' | 'relief'): void => {
    filters.value.porterTypeFilter = filterType
  }

  const setShiftTimeFilter = (filterType: 'all' | 'day' | 'night'): void => {
    filters.value.shiftTimeFilter = filterType
  }

  const setSearchQuery = (query: string): void => {
    filters.value.searchQuery = query
  }

  const toggleSortDirection = (): void => {
    filters.value.sortDirection = filters.value.sortDirection === 'asc' ? 'desc' : 'asc'
  }

  const resetToAZSort = (): void => {
    filters.value.sortBy = 'firstName'
    filters.value.sortDirection = 'asc'
  }

  // Department assignment
  const assignDepartment = async (staffId: string, departmentId: string | null): Promise<boolean> => {
    loading.value.staff = true
    error.value = null

    try {
      const { data, error: updateError } = await supabase
        .from('staff')
        .update({ department_id: departmentId })
        .eq('id', staffId)
        .select('*, department:department_id(id, name, building_id)')

      if (updateError) throw updateError

      if (data && data.length > 0) {
        const updatedStaff = data[0]

        if (updatedStaff.role === 'supervisor') {
          const index = supervisors.value.findIndex(s => s.id === staffId)
          if (index !== -1) {
            supervisors.value[index] = updatedStaff
          }
        } else {
          const index = porters.value.findIndex(p => p.id === staffId)
          if (index !== -1) {
            porters.value[index] = updatedStaff
          }
        }
      }

      return true
    } catch (err) {
      console.error('Error assigning department:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return false
    } finally {
      loading.value.staff = false
    }
  }

  // Initialize store
  const initialize = async (): Promise<void> => {
    await Promise.all([
      fetchSupervisors(),
      fetchPorters(),
      fetchPorterAbsences()
    ])
  }

  const clearError = (): void => {
    error.value = null
  }

  const resetStore = (): void => {
    staff.value = []
    supervisors.value = []
    porters.value = []
    porterAbsences.value = []
    error.value = null
    loading.value = {
      supervisors: false,
      porters: false,
      staff: false,
      absences: false
    }
    filters.value = {
      sortBy: 'firstName',
      porterTypeFilter: 'all',
      shiftTimeFilter: 'all',
      sortDirection: 'asc',
      searchQuery: ''
    }
  }

  return {
    // State
    staff,
    supervisors,
    porters,
    porterAbsences,
    loading,
    error,
    filters,
    availabilityPatterns,

    // Getters
    sortedSupervisors,
    sortedPorters,
    activeSupervisors,
    getStaffByIdComputed,
    isPorterAbsent,
    getPorterAbsenceDetails,

    // Utility functions
    formatAvailability,
    getPorterShiftType,

    // Actions
    fetchSupervisors,
    fetchPorters,
    fetchAllStaff,
    getStaffById,
    createStaffMember,
    updateStaffMember,
    deleteStaffMember,
    fetchPorterAbsences,
    addPorterAbsence,
    updatePorterAbsence,
    deletePorterAbsence,
    setSortBy,
    setPorterTypeFilter,
    setShiftTimeFilter,
    setSearchQuery,
    toggleSortDirection,
    resetToAZSort,
    assignDepartment,
    initialize,
    clearError,
    resetStore
  }
})
