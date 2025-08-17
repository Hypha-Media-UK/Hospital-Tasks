import { describe, it, expect, beforeEach, vi } from 'vitest'
import { useLoadingState, useSimpleLoading, LOADING_STATES } from '../../composables/useLoadingState'

describe('useLoadingState', () => {
  describe('useLoadingState', () => {
    let loadingManager

    beforeEach(() => {
      loadingManager = useLoadingState(['fetch', 'create', 'update'])
    })

    it('should initialize with provided states', () => {
      expect(loadingManager.loading.fetch).toBe(false)
      expect(loadingManager.loading.create).toBe(false)
      expect(loadingManager.loading.update).toBe(false)
    })

    it('should initialize with object states', () => {
      const manager = useLoadingState({ fetch: true, create: false })
      expect(manager.loading.fetch).toBe(true)
      expect(manager.loading.create).toBe(false)
    })

    it('should set and get loading states', () => {
      loadingManager.setLoading('fetch', true)
      expect(loadingManager.isLoading('fetch')).toBe(true)
      expect(loadingManager.loading.fetch).toBe(true)

      loadingManager.setLoading('fetch', false)
      expect(loadingManager.isLoading('fetch')).toBe(false)
    })

    it('should track if any operation is loading', () => {
      expect(loadingManager.isAnyLoading.value).toBe(false)

      loadingManager.setLoading('fetch', true)
      expect(loadingManager.isAnyLoading.value).toBe(true)

      loadingManager.setLoading('create', true)
      expect(loadingManager.isAnyLoading.value).toBe(true)

      loadingManager.setLoading('fetch', false)
      expect(loadingManager.isAnyLoading.value).toBe(true) // create is still true

      loadingManager.setLoading('create', false)
      expect(loadingManager.isAnyLoading.value).toBe(false)
    })

    it('should reset all loading states', () => {
      loadingManager.setLoading('fetch', true)
      loadingManager.setLoading('create', true)
      
      loadingManager.resetLoading()
      
      expect(loadingManager.loading.fetch).toBe(false)
      expect(loadingManager.loading.create).toBe(false)
      expect(loadingManager.isAnyLoading.value).toBe(false)
    })

    it('should manage error state', () => {
      expect(loadingManager.error.value).toBeNull()

      loadingManager.setError('Test error')
      expect(loadingManager.error.value).toBe('Test error')

      loadingManager.clearError()
      expect(loadingManager.error.value).toBeNull()
    })

    it('should handle Error objects', () => {
      const error = new Error('Test error message')
      loadingManager.setError(error)
      expect(loadingManager.error.value).toBe('Test error message')
    })

    it('should execute async operations with loading state', async () => {
      const mockAsyncFn = vi.fn().mockResolvedValue('success')

      expect(loadingManager.isLoading('fetch')).toBe(false)

      const promise = loadingManager.withLoading('fetch', mockAsyncFn)
      
      // Should be loading during execution
      expect(loadingManager.isLoading('fetch')).toBe(true)

      const result = await promise

      // Should not be loading after completion
      expect(loadingManager.isLoading('fetch')).toBe(false)
      expect(result).toBe('success')
      expect(mockAsyncFn).toHaveBeenCalled()
    })

    it('should handle async operation errors', async () => {
      const error = new Error('Async error')
      const mockAsyncFn = vi.fn().mockRejectedValue(error)

      await expect(
        loadingManager.withLoading('fetch', mockAsyncFn)
      ).rejects.toThrow('Async error')

      expect(loadingManager.isLoading('fetch')).toBe(false)
      expect(loadingManager.error.value).toBe('Async error')
    })

    it('should support options for withLoading', async () => {
      const error = new Error('Test error')
      const mockAsyncFn = vi.fn().mockRejectedValue(error)

      // Set initial error
      loadingManager.setError('Initial error')

      await expect(
        loadingManager.withLoading('fetch', mockAsyncFn, { 
          clearErrorOnStart: false,
          setErrorOnFailure: false 
        })
      ).rejects.toThrow('Test error')

      // Error should not be cleared or set
      expect(loadingManager.error.value).toBe('Initial error')
    })

    it('should add and remove loading states dynamically', () => {
      loadingManager.addLoadingState('newOperation', true)
      expect(loadingManager.loading.newOperation).toBe(true)

      loadingManager.removeLoadingState('newOperation')
      expect(loadingManager.loading.newOperation).toBeUndefined()
    })

    it('should get all loading states', () => {
      loadingManager.setLoading('fetch', true)
      const states = loadingManager.getAllLoadingStates()
      
      expect(states).toEqual({
        fetch: true,
        create: false,
        update: false
      })
    })
  })

  describe('useSimpleLoading', () => {
    let simpleLoading

    beforeEach(() => {
      simpleLoading = useSimpleLoading()
    })

    it('should initialize with default value', () => {
      expect(simpleLoading.loading.value).toBe(false)
      
      const withInitial = useSimpleLoading(true)
      expect(withInitial.loading.value).toBe(true)
    })

    it('should set loading state', () => {
      simpleLoading.setLoading(true)
      expect(simpleLoading.loading.value).toBe(true)

      simpleLoading.setLoading(false)
      expect(simpleLoading.loading.value).toBe(false)
    })

    it('should manage error state', () => {
      expect(simpleLoading.error.value).toBeNull()

      simpleLoading.setError('Test error')
      expect(simpleLoading.error.value).toBe('Test error')

      simpleLoading.clearError()
      expect(simpleLoading.error.value).toBeNull()
    })

    it('should execute async operations with loading state', async () => {
      const mockAsyncFn = vi.fn().mockResolvedValue('success')

      expect(simpleLoading.loading.value).toBe(false)

      const promise = simpleLoading.withLoading(mockAsyncFn)
      
      // Should be loading during execution
      expect(simpleLoading.loading.value).toBe(true)

      const result = await promise

      // Should not be loading after completion
      expect(simpleLoading.loading.value).toBe(false)
      expect(result).toBe('success')
    })

    it('should handle async operation errors', async () => {
      const error = new Error('Async error')
      const mockAsyncFn = vi.fn().mockRejectedValue(error)

      await expect(
        simpleLoading.withLoading(mockAsyncFn)
      ).rejects.toThrow('Async error')

      expect(simpleLoading.loading.value).toBe(false)
      expect(simpleLoading.error.value).toBe('Async error')
    })
  })

  describe('LOADING_STATES', () => {
    it('should have predefined loading state configurations', () => {
      expect(LOADING_STATES.STAFF).toContain('supervisors')
      expect(LOADING_STATES.STAFF).toContain('porters')
      expect(LOADING_STATES.LOCATIONS).toContain('buildings')
      expect(LOADING_STATES.SHIFTS).toContain('activeShifts')
    })

    it('should be usable with useLoadingState', () => {
      const staffLoading = useLoadingState(LOADING_STATES.STAFF)
      expect(staffLoading.loading.supervisors).toBe(false)
      expect(staffLoading.loading.porters).toBe(false)
      expect(staffLoading.loading.creating).toBe(false)
    })
  })
})
