import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../services/supabase'
import type { Shift, CreateShiftData, LoadingState } from '../types'

export const useShiftsStore = defineStore('shifts', () => {
  // State
  const shifts = ref<Shift[]>([])
  const currentShift = ref<Shift | null>(null)
  const loading = ref<LoadingState>({
    activeShifts: false,
    creating: false,
    updating: false
  })
  const error = ref<string | null>(null)

  // Getters
  const activeShifts = computed(() => {
    return shifts.value.filter(shift => !shift.end_time)
  })

  const activeDayShifts = computed(() => {
    return activeShifts.value.filter(shift =>
      shift.shift_type?.includes('day')
    )
  })

  const activeNightShifts = computed(() => {
    return activeShifts.value.filter(shift =>
      shift.shift_type?.includes('night')
    )
  })

  // Actions
  const fetchActiveShifts = async (): Promise<Shift[]> => {
    loading.value.activeShifts = true
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('shifts')
        .select(`
          *,
          supervisor:staff!shifts_supervisor_id_fkey(
            id,
            first_name,
            last_name
          )
        `)
        .is('end_time', null)
        .order('start_time', { ascending: false })

      if (fetchError) throw fetchError

      shifts.value = data || []
      return data || []
    } catch (err) {
      console.error('Error fetching active shifts:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return []
    } finally {
      loading.value.activeShifts = false
    }
  }

  const fetchShiftById = async (shiftId: string): Promise<Shift | null> => {
    try {
      const { data, error: fetchError } = await supabase
        .from('shifts')
        .select(`
          *,
          supervisor:staff!shifts_supervisor_id_fkey(
            id,
            first_name,
            last_name
          )
        `)
        .eq('id', shiftId)
        .single()

      if (fetchError) throw fetchError

      currentShift.value = data
      return data
    } catch (err) {
      console.error('Error fetching shift:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    }
  }

  const createShift = async (shiftData: CreateShiftData): Promise<Shift | null> => {
    loading.value.creating = true
    error.value = null

    try {
      const { data, error: createError } = await supabase
        .from('shifts')
        .insert([{
          supervisor_id: shiftData.supervisor_id,
          shift_type: shiftData.shift_type,
          start_time: shiftData.start_time,
          created_at: new Date().toISOString()
        }])
        .select(`
          *,
          supervisor:staff!shifts_supervisor_id_fkey(
            id,
            first_name,
            last_name
          )
        `)
        .single()

      if (createError) throw createError

      // Add to local state
      shifts.value.unshift(data)

      return data
    } catch (err) {
      console.error('Error creating shift:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    } finally {
      loading.value.creating = false
    }
  }

  const updateShift = async (shiftId: string, updates: Partial<Shift>): Promise<Shift | null> => {
    loading.value.updating = true
    error.value = null

    try {
      const { data, error: updateError } = await supabase
        .from('shifts')
        .update(updates)
        .eq('id', shiftId)
        .select(`
          *,
          supervisor:staff!shifts_supervisor_id_fkey(
            id,
            first_name,
            last_name
          )
        `)
        .single()

      if (updateError) throw updateError

      // Update local state
      const index = shifts.value.findIndex(shift => shift.id === shiftId)
      if (index !== -1) {
        shifts.value[index] = data
      }

      if (currentShift.value?.id === shiftId) {
        currentShift.value = data
      }

      return data
    } catch (err) {
      console.error('Error updating shift:', err)
      error.value = err instanceof Error ? err.message : 'Unknown error'
      return null
    } finally {
      loading.value.updating = false
    }
  }

  const endShift = async (shiftId: string): Promise<Shift | null> => {
    return updateShift(shiftId, {
      end_time: new Date().toISOString()
    })
  }

  const clearError = (): void => {
    error.value = null
  }

  const resetStore = (): void => {
    shifts.value = []
    currentShift.value = null
    error.value = null
    loading.value = {
      activeShifts: false,
      creating: false,
      updating: false
    }
  }

  return {
    // State
    shifts,
    currentShift,
    loading,
    error,

    // Getters
    activeShifts,
    activeDayShifts,
    activeNightShifts,

    // Actions
    fetchActiveShifts,
    fetchShiftById,
    createShift,
    updateShift,
    endShift,
    clearError,
    resetStore
  }
})
