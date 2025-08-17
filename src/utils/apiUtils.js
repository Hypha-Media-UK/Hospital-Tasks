/**
 * API Utility Functions
 * Consolidates common API patterns and reduces repetitive code
 */

/**
 * Build query string from filters object
 * @param {Object} filters - Object containing filter parameters
 * @param {Object} options - Configuration options
 * @param {Array} options.allowedParams - Array of allowed parameter names (for security)
 * @param {Object} options.defaults - Default values for parameters
 * @returns {string} Query string (with leading ? if not empty)
 */
export function buildQueryString(filters = {}, options = {}) {
  const { allowedParams = null, defaults = {} } = options;
  const params = new URLSearchParams();
  
  // Merge defaults with provided filters
  const mergedFilters = { ...defaults, ...filters };
  
  // Add parameters to URLSearchParams
  Object.entries(mergedFilters).forEach(([key, value]) => {
    // Skip if allowedParams is specified and key is not in the list
    if (allowedParams && !allowedParams.includes(key)) {
      return;
    }
    
    // Skip null, undefined, or empty string values
    if (value !== null && value !== undefined && value !== '') {
      params.append(key, value.toString());
    }
  });
  
  const queryString = params.toString();
  return queryString ? `?${queryString}` : '';
}

/**
 * Generic API request handler with enhanced error handling
 * @param {string} url - Full URL for the request
 * @param {Object} options - Fetch options
 * @param {Object} config - Additional configuration
 * @param {boolean} config.throwOnError - Whether to throw on HTTP errors (default: true)
 * @param {Function} config.onError - Custom error handler
 * @returns {Promise} Response data or null
 */
export async function makeApiRequest(url, options = {}, config = {}) {
  const { throwOnError = true, onError = null } = config;
  
  const defaultOptions = {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    },
    ...options
  };

  try {
    const response = await fetch(url, defaultOptions);
    
    // Handle non-JSON responses (like 204 No Content)
    if (response.status === 204) {
      return null;
    }
    
    const data = await response.json();
    
    if (!response.ok) {
      const error = new ApiError(
        data.message || 'API request failed',
        response.status,
        data
      );
      
      if (onError) {
        onError(error);
      }
      
      if (throwOnError) {
        throw error;
      }
      
      return null;
    }
    
    return data;
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    
    // Network or other errors
    const networkError = new ApiError('Network error or server unavailable', 0, null);
    
    if (onError) {
      onError(networkError);
    }
    
    if (throwOnError) {
      throw networkError;
    }
    
    return null;
  }
}

/**
 * Create a standardized API service object
 * @param {string} baseEndpoint - Base endpoint path (e.g., '/staff')
 * @param {string} apiBaseUrl - Base API URL
 * @param {Object} options - Configuration options
 * @param {Array} options.allowedFilters - Allowed filter parameters for getAll
 * @param {Object} options.defaultFilters - Default filter values
 * @returns {Object} API service object with standard CRUD methods
 */
export function createApiService(baseEndpoint, apiBaseUrl, options = {}) {
  const { allowedFilters = null, defaultFilters = {} } = options;
  
  return {
    // Get all items with optional filtering
    async getAll(filters = {}) {
      const queryString = buildQueryString(filters, { 
        allowedParams: allowedFilters,
        defaults: defaultFilters 
      });
      const url = `${apiBaseUrl}${baseEndpoint}${queryString}`;
      return makeApiRequest(url);
    },

    // Get item by ID
    async getById(id) {
      const url = `${apiBaseUrl}${baseEndpoint}/${id}`;
      return makeApiRequest(url);
    },

    // Create new item
    async create(data) {
      const url = `${apiBaseUrl}${baseEndpoint}`;
      return makeApiRequest(url, {
        method: 'POST',
        body: JSON.stringify(data)
      });
    },

    // Update item
    async update(id, updates) {
      const url = `${apiBaseUrl}${baseEndpoint}/${id}`;
      return makeApiRequest(url, {
        method: 'PUT',
        body: JSON.stringify(updates)
      });
    },

    // Delete item
    async delete(id) {
      const url = `${apiBaseUrl}${baseEndpoint}/${id}`;
      return makeApiRequest(url, {
        method: 'DELETE'
      });
    }
  };
}

/**
 * Enhanced API Error class
 */
export class ApiError extends Error {
  constructor(message, status, data) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.data = data;
    this.timestamp = new Date().toISOString();
  }
  
  /**
   * Check if error is a specific HTTP status
   * @param {number} status - HTTP status code to check
   * @returns {boolean}
   */
  isStatus(status) {
    return this.status === status;
  }
  
  /**
   * Check if error is a client error (4xx)
   * @returns {boolean}
   */
  isClientError() {
    return this.status >= 400 && this.status < 500;
  }
  
  /**
   * Check if error is a server error (5xx)
   * @returns {boolean}
   */
  isServerError() {
    return this.status >= 500 && this.status < 600;
  }
  
  /**
   * Check if error is a network error
   * @returns {boolean}
   */
  isNetworkError() {
    return this.status === 0;
  }
}

/**
 * Common filter parameter sets for different API endpoints
 */
export const COMMON_FILTERS = {
  PAGINATION: ['limit', 'offset'],
  STAFF: ['role', 'department_id', 'porter_type', 'limit', 'offset'],
  DEPARTMENTS: ['building_id', 'is_frequent', 'limit', 'offset'],
  TASK_TYPES: ['include_items', 'limit', 'offset'],
  TASK_ITEMS: ['task_type_id', 'is_regular', 'limit', 'offset'],
  SUPPORT_SERVICES: ['is_active', 'limit', 'offset'],
  ABSENCES: ['porter_id', 'absence_type', 'start_date', 'end_date', 'limit', 'offset'],
  SHIFTS: ['is_active', 'shift_type', 'supervisor_id', 'shift_date', 'limit', 'offset'],
  TASKS: ['shift_id', 'status', 'porter_id', 'task_item_id', 'limit', 'offset']
};

/**
 * Default pagination values
 */
export const DEFAULT_PAGINATION = {
  limit: '100',
  offset: '0'
};
