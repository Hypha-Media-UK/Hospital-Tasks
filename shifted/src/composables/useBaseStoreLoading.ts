import { ref, computed, readonly } from 'vue'

export interface BaseStoreLoading {
  entities: boolean      // Main entities (buildings, taskTypes, etc.)
  details: boolean       // Entity details/children (departments, taskItems)
  assignments: boolean   // Assignment operations
  operations: boolean    // CRUD operations (sorting, etc.)
}

export function useBaseStoreLoading() {
  const loading = ref<BaseStoreLoading>({
    entities: false,
    details: false,
    assignments: false,
    operations: false
  })

  const setLoading = (key: keyof BaseStoreLoading, value: boolean) => {
    loading.value[key] = value
  }

  const setEntitiesLoading = (value: boolean) => {
    loading.value.entities = value
  }

  const setDetailsLoading = (value: boolean) => {
    loading.value.details = value
  }

  const setAssignmentsLoading = (value: boolean) => {
    loading.value.assignments = value
  }

  const setOperationsLoading = (value: boolean) => {
    loading.value.operations = value
  }

  // Computed getters
  const isAnyLoading = computed(() =>
    Object.values(loading.value).some(Boolean)
  )

  const isEntitiesLoading = computed(() => loading.value.entities)
  const isDetailsLoading = computed(() => loading.value.details)
  const isAssignmentsLoading = computed(() => loading.value.assignments)
  const isOperationsLoading = computed(() => loading.value.operations)

  return {
    loading: readonly(loading),
    setLoading,
    setEntitiesLoading,
    setDetailsLoading,
    setAssignmentsLoading,
    setOperationsLoading,
    isAnyLoading,
    isEntitiesLoading,
    isDetailsLoading,
    isAssignmentsLoading,
    isOperationsLoading
  }
}
