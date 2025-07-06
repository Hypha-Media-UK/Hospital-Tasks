import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../services/supabase'
import { useBaseStoreLoading } from '../composables/useBaseStoreLoading'
import type { Building, Department, DepartmentTaskAssignment, BuildingWithDepartments } from '../types/locations'

export const useLocationsStore = defineStore('locations', () => {
  // State
  const buildings = ref<Building[]>([])
  const departments = ref<Department[]>([])
  const departmentTaskAssignments = ref<DepartmentTaskAssignment[]>([])

  const {
    setEntitiesLoading,
    setDetailsLoading,
    setAssignmentsLoading,
    setOperationsLoading,
    isEntitiesLoading,
    isDetailsLoading,
    isAssignmentsLoading,
    isOperationsLoading
  } = useBaseStoreLoading()

  const error = ref<string | null>(null)

  // Getters
  const sortedBuildings = computed(() => {
    return [...buildings.value].sort((a, b) => a.sort_order - b.sort_order)
  })

  const buildingsWithDepartments = computed((): BuildingWithDepartments[] => {
    return buildings.value.map(building => {
      const buildingDepartments = departments.value.filter(
        dept => dept.building_id === building.id
      )
      return {
        ...building,
        departments: buildingDepartments
      }
    })
  })

  const sortedBuildingsWithDepartments = computed((): BuildingWithDepartments[] => {
    const sorted = [...buildings.value].sort((a, b) => a.sort_order - b.sort_order)

    return sorted.map(building => {
      const buildingDepartments = departments.value.filter(
        dept => dept.building_id === building.id
      )
      return {
        ...building,
        departments: buildingDepartments
      }
    })
  })

  const frequentDepartments = computed(() => {
    const buildingSortMap = new Map<string, number>()
    sortedBuildings.value.forEach((building, index) => {
      buildingSortMap.set(building.id, index)
    })

    const frequentDepts = departments.value.filter(dept => dept.is_frequent)

    return frequentDepts.sort((a, b) => {
      const buildingOrderA = buildingSortMap.get(a.building_id) ?? 999
      const buildingOrderB = buildingSortMap.get(b.building_id) ?? 999

      if (buildingOrderA !== buildingOrderB) {
        return buildingOrderA - buildingOrderB
      }

      return a.sort_order - b.sort_order
    })
  })

  const sortedDepartmentsByBuilding = (buildingId: string) => {
    return departments.value
      .filter(dept => dept.building_id === buildingId)
      .sort((a, b) => a.sort_order - b.sort_order)
  }

  const getDepartmentTaskAssignment = (departmentId: string) => {
    return departmentTaskAssignments.value.find(
      assignment => assignment.department_id === departmentId
    ) || null
  }

  // Actions
  const fetchBuildings = async (): Promise<void> => {
    setEntitiesLoading(true)
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('buildings')
        .select('*')
        .order('sort_order')

      if (fetchError) throw fetchError

      buildings.value = data || []
    } catch (err) {
      console.error('Error fetching buildings:', err)
      error.value = 'Failed to load buildings'
    } finally {
      setEntitiesLoading(false)
    }
  }

  const addBuilding = async (building: Omit<Building, 'id' | 'created_at' | 'updated_at'>): Promise<Building | null> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { data, error: insertError } = await supabase
        .from('buildings')
        .insert(building)
        .select()

      if (insertError) throw insertError

      if (data && data.length > 0) {
        buildings.value.push(data[0])
        return data[0]
      }

      return null
    } catch (err) {
      console.error('Error adding building:', err)
      error.value = 'Failed to add building'
      return null
    } finally {
      setOperationsLoading(false)
    }
  }

  const updateBuilding = async (id: string, updates: Partial<Building>): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { data, error: updateError } = await supabase
        .from('buildings')
        .update(updates)
        .eq('id', id)
        .select()

      if (updateError) throw updateError

      if (data && data.length > 0) {
        const index = buildings.value.findIndex(b => b.id === id)
        if (index !== -1) {
          buildings.value[index] = data[0]
        }
      }

      return true
    } catch (err) {
      console.error('Error updating building:', err)
      error.value = 'Failed to update building'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  const deleteBuilding = async (id: string): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { error: deleteError } = await supabase
        .from('buildings')
        .delete()
        .eq('id', id)

      if (deleteError) throw deleteError

      buildings.value = buildings.value.filter(b => b.id !== id)
      departments.value = departments.value.filter(d => d.building_id !== id)

      return true
    } catch (err) {
      console.error('Error deleting building:', err)
      error.value = 'Failed to delete building'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  const fetchDepartments = async (): Promise<void> => {
    setDetailsLoading(true)
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('departments')
        .select('*')
        .order('sort_order')

      if (fetchError) throw fetchError

      departments.value = data || []
    } catch (err) {
      console.error('Error fetching departments:', err)
      error.value = 'Failed to load departments'
    } finally {
      setDetailsLoading(false)
    }
  }

  const addDepartment = async (department: Omit<Department, 'id' | 'created_at' | 'updated_at'>): Promise<Department | null> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { data, error: insertError } = await supabase
        .from('departments')
        .insert(department)
        .select()

      if (insertError) throw insertError

      if (data && data.length > 0) {
        departments.value.push(data[0])
        return data[0]
      }

      return null
    } catch (err) {
      console.error('Error adding department:', err)
      error.value = 'Failed to add department'
      return null
    } finally {
      setOperationsLoading(false)
    }
  }

  const updateDepartment = async (id: string, updates: Partial<Department>): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { data, error: updateError } = await supabase
        .from('departments')
        .update(updates)
        .eq('id', id)
        .select()

      if (updateError) throw updateError

      if (data && data.length > 0) {
        const index = departments.value.findIndex(d => d.id === id)
        if (index !== -1) {
          departments.value[index] = data[0]
        }
      }

      return true
    } catch (err) {
      console.error('Error updating department:', err)
      error.value = 'Failed to update department'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  const toggleFrequent = async (id: string): Promise<boolean> => {
    const department = departments.value.find(d => d.id === id)
    if (!department) return false

    return updateDepartment(id, { is_frequent: !department.is_frequent })
  }

  const deleteDepartment = async (id: string): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { error: deleteError } = await supabase
        .from('departments')
        .delete()
        .eq('id', id)

      if (deleteError) throw deleteError

      departments.value = departments.value.filter(d => d.id !== id)

      return true
    } catch (err) {
      console.error('Error deleting department:', err)
      error.value = 'Failed to delete department'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  const initialize = async (): Promise<void> => {
    await Promise.all([
      fetchBuildings(),
      fetchDepartments()
    ])
  }

  return {
    // State
    buildings,
    departments,
    departmentTaskAssignments,
    error,

    // Loading states
    isEntitiesLoading,
    isDetailsLoading,
    isAssignmentsLoading,
    isOperationsLoading,

    // Getters
    sortedBuildings,
    buildingsWithDepartments,
    sortedBuildingsWithDepartments,
    frequentDepartments,
    sortedDepartmentsByBuilding,
    getDepartmentTaskAssignment,

    // Actions
    fetchBuildings,
    addBuilding,
    updateBuilding,
    deleteBuilding,
    fetchDepartments,
    addDepartment,
    updateDepartment,
    toggleFrequent,
    deleteDepartment,
    initialize
  }
})
