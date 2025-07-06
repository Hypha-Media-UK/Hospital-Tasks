import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '../services/supabase'
import { useBaseStoreLoading } from '../composables/useBaseStoreLoading'
import type {
  TaskType,
  TaskItem,
  TaskTypeAssignment,
  TaskItemAssignment,
  TaskTypeWithItems,
  DepartmentAssignmentData
} from '../types/taskTypes'

export const useTaskTypesStore = defineStore('taskTypes', () => {
  // State
  const taskTypes = ref<TaskType[]>([])
  const taskItems = ref<TaskItem[]>([])
  const typeAssignments = ref<TaskTypeAssignment[]>([])
  const itemAssignments = ref<TaskItemAssignment[]>([])

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
  const taskTypesWithItems = computed((): TaskTypeWithItems[] => {
    return taskTypes.value.map(taskType => {
      const items = taskItems.value.filter(
        item => item.task_type_id === taskType.id
      )
      return {
        ...taskType,
        items
      }
    })
  })

  const getTaskItemsByTypeId = (typeId: string): TaskItem[] => {
    return taskItems.value.filter(item => item.task_type_id === typeId)
  }

  const getRegularTaskItem = (typeId: string): TaskItem | undefined => {
    return taskItems.value.find(
      item => item.task_type_id === typeId && item.is_regular
    )
  }

  const hasTypeAssignments = (typeId: string): boolean => {
    return typeAssignments.value.some(
      assignment => assignment.task_type_id === typeId
    )
  }

  const hasItemAssignments = (itemId: string): boolean => {
    return itemAssignments.value.some(
      assignment => assignment.task_item_id === itemId
    )
  }

  const getTypeAssignmentsByTypeId = (typeId: string): TaskTypeAssignment[] => {
    return typeAssignments.value.filter(
      assignment => assignment.task_type_id === typeId
    )
  }

  const getItemAssignmentsByItemId = (itemId: string): TaskItemAssignment[] => {
    return itemAssignments.value.filter(
      assignment => assignment.task_item_id === itemId
    )
  }

  const getTypeDepartmentAssignment = (typeId: string, departmentId: string) => {
    return typeAssignments.value.find(
      a => a.task_type_id === typeId && a.department_id === departmentId
    ) || { is_origin: false, is_destination: false }
  }

  const getItemDepartmentAssignment = (itemId: string, departmentId: string) => {
    return itemAssignments.value.find(
      a => a.task_item_id === itemId && a.department_id === departmentId
    ) || { is_origin: false, is_destination: false }
  }

  // Actions - Task Types
  const fetchTaskTypes = async (): Promise<void> => {
    setEntitiesLoading(true)
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('task_types')
        .select('*')
        .order('name')

      if (fetchError) throw fetchError

      taskTypes.value = data || []
    } catch (err) {
      console.error('Error fetching task types:', err)
      error.value = 'Failed to load task types'
    } finally {
      setEntitiesLoading(false)
    }
  }

  const addTaskType = async (taskType: Omit<TaskType, 'id' | 'created_at' | 'updated_at'>): Promise<TaskType | null> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { data, error: insertError } = await supabase
        .from('task_types')
        .insert(taskType)
        .select()

      if (insertError) throw insertError

      if (data && data.length > 0) {
        taskTypes.value.push(data[0])
        return data[0]
      }

      return null
    } catch (err) {
      console.error('Error adding task type:', err)
      error.value = 'Failed to add task type'
      return null
    } finally {
      setOperationsLoading(false)
    }
  }

  const updateTaskType = async (id: string, updates: Partial<TaskType>): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { data, error: updateError } = await supabase
        .from('task_types')
        .update(updates)
        .eq('id', id)
        .select()

      if (updateError) throw updateError

      if (data && data.length > 0) {
        const index = taskTypes.value.findIndex(t => t.id === id)
        if (index !== -1) {
          taskTypes.value[index] = data[0]
        }
      }

      return true
    } catch (err) {
      console.error('Error updating task type:', err)
      error.value = 'Failed to update task type'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  const deleteTaskType = async (id: string): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { error: deleteError } = await supabase
        .from('task_types')
        .delete()
        .eq('id', id)

      if (deleteError) throw deleteError

      // Remove from local state
      taskTypes.value = taskTypes.value.filter(t => t.id !== id)
      taskItems.value = taskItems.value.filter(i => i.task_type_id !== id)
      typeAssignments.value = typeAssignments.value.filter(a => a.task_type_id !== id)

      return true
    } catch (err) {
      console.error('Error deleting task type:', err)
      error.value = 'Failed to delete task type'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  // Actions - Task Items
  const fetchTaskItems = async (): Promise<void> => {
    setDetailsLoading(true)
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('task_items')
        .select('*')
        .order('name')

      if (fetchError) throw fetchError

      taskItems.value = data || []
    } catch (err) {
      console.error('Error fetching task items:', err)
      error.value = 'Failed to load task items'
    } finally {
      setDetailsLoading(false)
    }
  }

  const addTaskItem = async (taskItem: Omit<TaskItem, 'id' | 'created_at' | 'updated_at'>): Promise<TaskItem | null> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { data, error: insertError } = await supabase
        .from('task_items')
        .insert(taskItem)
        .select()

      if (insertError) throw insertError

      if (data && data.length > 0) {
        taskItems.value.push(data[0])
        return data[0]
      }

      return null
    } catch (err) {
      console.error('Error adding task item:', err)
      error.value = 'Failed to add task item'
      return null
    } finally {
      setOperationsLoading(false)
    }
  }

  const updateTaskItem = async (id: string, updates: Partial<TaskItem>): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { data, error: updateError } = await supabase
        .from('task_items')
        .update(updates)
        .eq('id', id)
        .select()

      if (updateError) throw updateError

      if (data && data.length > 0) {
        const index = taskItems.value.findIndex(i => i.id === id)
        if (index !== -1) {
          taskItems.value[index] = data[0]
        }
      }

      return true
    } catch (err) {
      console.error('Error updating task item:', err)
      error.value = 'Failed to update task item'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  const setTaskItemRegular = async (taskItemId: string, isRegular: boolean = true): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const taskItem = taskItems.value.find(item => item.id === taskItemId)
      if (!taskItem) {
        throw new Error('Task item not found')
      }

      const taskTypeId = taskItem.task_type_id

      if (isRegular) {
        // First, unmark any other regular task items for this task type
        const currentRegularItem = getRegularTaskItem(taskTypeId)
        if (currentRegularItem && currentRegularItem.id !== taskItemId) {
          await supabase
            .from('task_items')
            .update({ is_regular: false })
            .eq('id', currentRegularItem.id)

          // Update in local state
          const index = taskItems.value.findIndex(i => i.id === currentRegularItem.id)
          if (index !== -1) {
            taskItems.value[index].is_regular = false
          }
        }
      }

      // Now update the target task item
      const { data, error: updateError } = await supabase
        .from('task_items')
        .update({ is_regular: isRegular })
        .eq('id', taskItemId)
        .select()

      if (updateError) throw updateError

      if (data && data.length > 0) {
        const index = taskItems.value.findIndex(i => i.id === taskItemId)
        if (index !== -1) {
          taskItems.value[index] = data[0]
        }
      }

      return true
    } catch (err) {
      console.error('Error setting task item as regular:', err)
      error.value = 'Failed to update task item'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  const deleteTaskItem = async (id: string): Promise<boolean> => {
    setOperationsLoading(true)
    error.value = null

    try {
      const { error: deleteError } = await supabase
        .from('task_items')
        .delete()
        .eq('id', id)

      if (deleteError) throw deleteError

      // Remove from local state
      taskItems.value = taskItems.value.filter(i => i.id !== id)
      itemAssignments.value = itemAssignments.value.filter(a => a.task_item_id !== id)

      return true
    } catch (err) {
      console.error('Error deleting task item:', err)
      error.value = 'Failed to delete task item'
      return false
    } finally {
      setOperationsLoading(false)
    }
  }

  // Actions - Assignments
  const fetchTypeAssignments = async (): Promise<void> => {
    setAssignmentsLoading(true)
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('task_type_department_assignments')
        .select('*')

      if (fetchError) throw fetchError

      typeAssignments.value = data || []
    } catch (err) {
      console.error('Error fetching type assignments:', err)
      error.value = 'Failed to load department assignments for task types'
    } finally {
      setAssignmentsLoading(false)
    }
  }

  const fetchItemAssignments = async (): Promise<void> => {
    setAssignmentsLoading(true)
    error.value = null

    try {
      const { data, error: fetchError } = await supabase
        .from('task_item_department_assignments')
        .select('*')

      if (fetchError) throw fetchError

      itemAssignments.value = data || []
    } catch (err) {
      console.error('Error fetching item assignments:', err)
      error.value = 'Failed to load department assignments for task items'
    } finally {
      setAssignmentsLoading(false)
    }
  }

  const updateTypeAssignments = async (taskTypeId: string, departmentAssignments: DepartmentAssignmentData[]): Promise<boolean> => {
    setAssignmentsLoading(true)
    error.value = null

    try {
      // First, delete all existing assignments for this task type
      const { error: deleteError } = await supabase
        .from('task_type_department_assignments')
        .delete()
        .eq('task_type_id', taskTypeId)

      if (deleteError) throw deleteError

      // Filter out assignments where both is_origin and is_destination are false
      const validAssignments = departmentAssignments
        .filter(a => a.is_origin || a.is_destination)
        .map(a => ({
          task_type_id: taskTypeId,
          department_id: a.department_id,
          is_origin: a.is_origin,
          is_destination: a.is_destination
        }))

      // If there are valid assignments, insert them
      if (validAssignments.length > 0) {
        const { error: insertError } = await supabase
          .from('task_type_department_assignments')
          .insert(validAssignments)

        if (insertError) throw insertError
      }

      // Update local state
      typeAssignments.value = typeAssignments.value.filter(
        a => a.task_type_id !== taskTypeId
      )

      validAssignments.forEach(assignment => {
        typeAssignments.value.push(assignment as TaskTypeAssignment)
      })

      return true
    } catch (err) {
      console.error('Error updating type assignments:', err)
      error.value = 'Failed to update department assignments for task type'
      return false
    } finally {
      setAssignmentsLoading(false)
    }
  }

  const updateItemAssignments = async (taskItemId: string, departmentAssignments: DepartmentAssignmentData[]): Promise<boolean> => {
    setAssignmentsLoading(true)
    error.value = null

    try {
      // First, delete all existing assignments for this task item
      const { error: deleteError } = await supabase
        .from('task_item_department_assignments')
        .delete()
        .eq('task_item_id', taskItemId)

      if (deleteError) throw deleteError

      // Filter out assignments where both is_origin and is_destination are false
      const validAssignments = departmentAssignments
        .filter(a => a.is_origin || a.is_destination)
        .map(a => ({
          task_item_id: taskItemId,
          department_id: a.department_id,
          is_origin: a.is_origin,
          is_destination: a.is_destination
        }))

      // If there are valid assignments, insert them
      if (validAssignments.length > 0) {
        const { error: insertError } = await supabase
          .from('task_item_department_assignments')
          .insert(validAssignments)

        if (insertError) throw insertError
      }

      // Update local state
      itemAssignments.value = itemAssignments.value.filter(
        a => a.task_item_id !== taskItemId
      )

      validAssignments.forEach(assignment => {
        itemAssignments.value.push(assignment as TaskItemAssignment)
      })

      return true
    } catch (err) {
      console.error('Error updating item assignments:', err)
      error.value = 'Failed to update department assignments for task item'
      return false
    } finally {
      setAssignmentsLoading(false)
    }
  }

  // Initialize
  const initialize = async (): Promise<void> => {
    await Promise.all([
      fetchTaskTypes(),
      fetchTaskItems(),
      fetchTypeAssignments(),
      fetchItemAssignments()
    ])
  }

  return {
    // State
    taskTypes,
    taskItems,
    typeAssignments,
    itemAssignments,
    error,

    // Loading states
    isEntitiesLoading,
    isDetailsLoading,
    isAssignmentsLoading,
    isOperationsLoading,

    // Getters
    taskTypesWithItems,
    getTaskItemsByTypeId,
    getRegularTaskItem,
    hasTypeAssignments,
    hasItemAssignments,
    getTypeAssignmentsByTypeId,
    getItemAssignmentsByItemId,
    getTypeDepartmentAssignment,
    getItemDepartmentAssignment,

    // Actions
    fetchTaskTypes,
    addTaskType,
    updateTaskType,
    deleteTaskType,
    fetchTaskItems,
    addTaskItem,
    updateTaskItem,
    setTaskItemRegular,
    deleteTaskItem,
    fetchTypeAssignments,
    fetchItemAssignments,
    updateTypeAssignments,
    updateItemAssignments,
    initialize
  }
})
