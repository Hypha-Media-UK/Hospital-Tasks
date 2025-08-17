/**
 * Loading State Composable
 * Provides reusable loading state management for stores and components
 */

import { ref, reactive, computed } from 'vue';

/**
 * Create a loading state manager
 * @param {Array|Object} initialStates - Initial loading states (array of strings or object)
 * @returns {Object} Loading state manager
 */
export function useLoadingState(initialStates = []) {
  // Handle both array and object initialization
  const loadingStates = reactive(
    Array.isArray(initialStates) 
      ? Object.fromEntries(initialStates.map(state => [state, false]))
      : { ...initialStates }
  );
  
  const error = ref(null);
  
  /**
   * Set loading state for a specific operation
   * @param {string} operation - Operation name
   * @param {boolean} isLoading - Loading state
   */
  const setLoading = (operation, isLoading) => {
    loadingStates[operation] = isLoading;
  };
  
  /**
   * Check if a specific operation is loading
   * @param {string} operation - Operation name
   * @returns {boolean} Loading state
   */
  const isLoading = (operation) => {
    return loadingStates[operation] || false;
  };
  
  /**
   * Check if any operation is loading
   * @returns {boolean} True if any operation is loading
   */
  const isAnyLoading = computed(() => {
    return Object.values(loadingStates).some(state => state);
  });
  
  /**
   * Get all loading states
   * @returns {Object} All loading states
   */
  const getAllLoadingStates = () => {
    return { ...loadingStates };
  };
  
  /**
   * Reset all loading states to false
   */
  const resetLoading = () => {
    Object.keys(loadingStates).forEach(key => {
      loadingStates[key] = false;
    });
  };
  
  /**
   * Set error state
   * @param {string|Error|null} errorValue - Error message or Error object
   */
  const setError = (errorValue) => {
    if (errorValue instanceof Error) {
      error.value = errorValue.message;
    } else {
      error.value = errorValue;
    }
  };
  
  /**
   * Clear error state
   */
  const clearError = () => {
    error.value = null;
  };
  
  /**
   * Execute an async operation with automatic loading state management
   * @param {string} operation - Operation name
   * @param {Function} asyncFn - Async function to execute
   * @param {Object} options - Configuration options
   * @param {boolean} options.clearErrorOnStart - Clear error when starting (default: true)
   * @param {boolean} options.setErrorOnFailure - Set error on failure (default: true)
   * @returns {Promise} Result of the async operation
   */
  const withLoading = async (operation, asyncFn, options = {}) => {
    const { clearErrorOnStart = true, setErrorOnFailure = true } = options;
    
    setLoading(operation, true);
    
    if (clearErrorOnStart) {
      clearError();
    }
    
    try {
      const result = await asyncFn();
      return result;
    } catch (err) {
      if (setErrorOnFailure) {
        setError(err);
      }
      throw err;
    } finally {
      setLoading(operation, false);
    }
  };
  
  /**
   * Add a new loading state dynamically
   * @param {string} operation - Operation name
   * @param {boolean} initialValue - Initial loading state (default: false)
   */
  const addLoadingState = (operation, initialValue = false) => {
    loadingStates[operation] = initialValue;
  };
  
  /**
   * Remove a loading state
   * @param {string} operation - Operation name
   */
  const removeLoadingState = (operation) => {
    delete loadingStates[operation];
  };
  
  return {
    // State
    loading: loadingStates,
    error,
    
    // Computed
    isAnyLoading,
    
    // Methods
    setLoading,
    isLoading,
    getAllLoadingStates,
    resetLoading,
    setError,
    clearError,
    withLoading,
    addLoadingState,
    removeLoadingState
  };
}

/**
 * Create a simple loading state for a single operation
 * @param {boolean} initialValue - Initial loading state
 * @returns {Object} Simple loading state manager
 */
export function useSimpleLoading(initialValue = false) {
  const loading = ref(initialValue);
  const error = ref(null);
  
  const setLoading = (value) => {
    loading.value = value;
  };
  
  const setError = (errorValue) => {
    if (errorValue instanceof Error) {
      error.value = errorValue.message;
    } else {
      error.value = errorValue;
    }
  };
  
  const clearError = () => {
    error.value = null;
  };
  
  const withLoading = async (asyncFn, options = {}) => {
    const { clearErrorOnStart = true, setErrorOnFailure = true } = options;
    
    loading.value = true;
    
    if (clearErrorOnStart) {
      clearError();
    }
    
    try {
      const result = await asyncFn();
      return result;
    } catch (err) {
      if (setErrorOnFailure) {
        setError(err);
      }
      throw err;
    } finally {
      loading.value = false;
    }
  };
  
  return {
    loading,
    error,
    setLoading,
    setError,
    clearError,
    withLoading
  };
}

/**
 * Common loading state configurations for different store types
 */
export const LOADING_STATES = {
  STAFF: ['supervisors', 'porters', 'staff', 'absences', 'creating', 'updating', 'deleting'],
  LOCATIONS: ['buildings', 'departments', 'sorting', 'departmentTaskAssignments'],
  TASK_TYPES: ['taskTypes', 'taskItems', 'itemAssignments', 'typeAssignments', 'creating', 'updating', 'deleting'],
  SUPPORT_SERVICES: ['services', 'assignments', 'creating', 'updating', 'deleting'],
  SHIFTS: ['activeShifts', 'archivedShifts', 'currentShift', 'shiftTasks', 'areaCover', 'supportServices', 'porterPool'],
  SETTINGS: ['appSettings', 'shiftDefaults', 'updating'],
  AREA_COVER: ['departments', 'save']
};
