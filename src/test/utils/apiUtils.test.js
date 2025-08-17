import { describe, it, expect, beforeEach, vi } from 'vitest'
import {
  buildQueryString,
  makeApiRequest,
  createApiService,
  ApiError,
  COMMON_FILTERS,
  DEFAULT_PAGINATION
} from '../../utils/apiUtils'

describe('apiUtils', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    // Reset fetch mock
    global.fetch = vi.fn()
  })

  describe('buildQueryString', () => {
    it('should build query string from filters', () => {
      const filters = { name: 'John', age: 25, active: true }
      const result = buildQueryString(filters)
      expect(result).toBe('?name=John&age=25&active=true')
    })

    it('should handle empty filters', () => {
      expect(buildQueryString({})).toBe('')
      expect(buildQueryString()).toBe('')
    })

    it('should skip null and undefined values', () => {
      const filters = { name: 'John', age: null, active: undefined, city: '' }
      const result = buildQueryString(filters)
      expect(result).toBe('?name=John')
    })

    it('should respect allowedParams option', () => {
      const filters = { name: 'John', age: 25, secret: 'hidden' }
      const result = buildQueryString(filters, { allowedParams: ['name', 'age'] })
      expect(result).toBe('?name=John&age=25')
      expect(result).not.toContain('secret')
    })

    it('should merge with defaults', () => {
      const filters = { name: 'John' }
      const defaults = { limit: '10', offset: '0' }
      const result = buildQueryString(filters, { defaults })
      expect(result).toContain('name=John')
      expect(result).toContain('limit=10')
      expect(result).toContain('offset=0')
    })
  })

  describe('makeApiRequest', () => {
    it('should make successful API request', async () => {
      const mockData = { id: 1, name: 'Test' }
      global.fetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: () => Promise.resolve(mockData)
      })

      const result = await makeApiRequest('http://test.com/api')
      expect(result).toEqual(mockData)
      expect(global.fetch).toHaveBeenCalledWith('http://test.com/api', {
        headers: { 'Content-Type': 'application/json' }
      })
    })

    it('should handle 204 No Content response', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        status: 204
      })

      const result = await makeApiRequest('http://test.com/api')
      expect(result).toBeNull()
    })

    it('should throw ApiError for HTTP errors', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: false,
        status: 404,
        json: () => Promise.resolve({ message: 'Not found' })
      })

      await expect(makeApiRequest('http://test.com/api')).rejects.toThrow(ApiError)
    })

    it('should handle network errors', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Network error'))

      await expect(makeApiRequest('http://test.com/api')).rejects.toThrow(ApiError)
    })

    it('should call custom error handler', async () => {
      const onError = vi.fn()
      global.fetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        json: () => Promise.resolve({ message: 'Server error' })
      })

      await expect(
        makeApiRequest('http://test.com/api', {}, { onError, throwOnError: false })
      ).resolves.toBeNull()

      expect(onError).toHaveBeenCalled()
    })
  })

  describe('createApiService', () => {
    let apiService

    beforeEach(() => {
      apiService = createApiService('/test', 'http://api.test.com')
    })

    it('should create service with getAll method', async () => {
      const mockData = [{ id: 1 }, { id: 2 }]
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockData)
      })

      const result = await apiService.getAll({ limit: '10' })
      expect(result).toEqual(mockData)
      expect(global.fetch).toHaveBeenCalledWith(
        'http://api.test.com/test?limit=10',
        { headers: { 'Content-Type': 'application/json' } }
      )
    })

    it('should create service with getById method', async () => {
      const mockData = { id: 1, name: 'Test' }
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockData)
      })

      const result = await apiService.getById(1)
      expect(result).toEqual(mockData)
      expect(global.fetch).toHaveBeenCalledWith(
        'http://api.test.com/test/1',
        { headers: { 'Content-Type': 'application/json' } }
      )
    })

    it('should create service with create method', async () => {
      const newData = { name: 'New Item' }
      const mockResponse = { id: 1, ...newData }
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockResponse)
      })

      const result = await apiService.create(newData)
      expect(result).toEqual(mockResponse)
      expect(global.fetch).toHaveBeenCalledWith(
        'http://api.test.com/test',
        {
          method: 'POST',
          body: JSON.stringify(newData),
          headers: { 'Content-Type': 'application/json' }
        }
      )
    })

    it('should create service with update method', async () => {
      const updates = { name: 'Updated Item' }
      const mockResponse = { id: 1, ...updates }
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockResponse)
      })

      const result = await apiService.update(1, updates)
      expect(result).toEqual(mockResponse)
      expect(global.fetch).toHaveBeenCalledWith(
        'http://api.test.com/test/1',
        {
          method: 'PUT',
          body: JSON.stringify(updates),
          headers: { 'Content-Type': 'application/json' }
        }
      )
    })

    it('should create service with delete method', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        status: 204
      })

      const result = await apiService.delete(1)
      expect(result).toBeNull()
      expect(global.fetch).toHaveBeenCalledWith(
        'http://api.test.com/test/1',
        {
          method: 'DELETE',
          headers: { 'Content-Type': 'application/json' }
        }
      )
    })
  })

  describe('ApiError', () => {
    it('should create ApiError with message and status', () => {
      const error = new ApiError('Test error', 404)
      expect(error.message).toBe('Test error')
      expect(error.status).toBe(404)
      expect(error.name).toBe('ApiError')
    })

    it('should have helper methods for status checking', () => {
      const clientError = new ApiError('Bad request', 400)
      const serverError = new ApiError('Server error', 500)
      const networkError = new ApiError('Network error', 0)

      expect(clientError.isStatus(400)).toBe(true)
      expect(clientError.isClientError()).toBe(true)
      expect(clientError.isServerError()).toBe(false)

      expect(serverError.isServerError()).toBe(true)
      expect(serverError.isClientError()).toBe(false)

      expect(networkError.isNetworkError()).toBe(true)
    })
  })

  describe('COMMON_FILTERS', () => {
    it('should have predefined filter sets', () => {
      expect(COMMON_FILTERS.STAFF).toContain('role')
      expect(COMMON_FILTERS.STAFF).toContain('department_id')
      expect(COMMON_FILTERS.PAGINATION).toContain('limit')
      expect(COMMON_FILTERS.PAGINATION).toContain('offset')
    })
  })

  describe('DEFAULT_PAGINATION', () => {
    it('should have default pagination values', () => {
      expect(DEFAULT_PAGINATION.limit).toBe('100')
      expect(DEFAULT_PAGINATION.offset).toBe('0')
    })
  })
})
