// API Service Layer - Replaces Supabase client
// Smart environment detection with fallback
const getApiBaseUrl = () => {
  // First priority: Environment variable (for production)
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL;
  }
  
  // Second priority: Smart detection based on current URL
  const currentOrigin = window.location.origin;
  
  if (currentOrigin.includes('ddev.site')) {
    // DDEV environment - API should be on same origin with /api path
    return `${currentOrigin}/api`;
  } else if (currentOrigin.includes('localhost:5173')) {
    // Local development
    return 'http://localhost:3000/api';
  } else {
    // Production fallback - assume API is on same origin with /api path
    return `${currentOrigin}/api`;
  }
};

const API_BASE_URL = getApiBaseUrl();

class ApiError extends Error {
  constructor(message, status, data) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.data = data;
  }
}

// Generic API request handler
async function apiRequest(endpoint, options = {}) {
  const url = `${API_BASE_URL}${endpoint}`;
  
  const config = {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    },
    ...options
  };

  try {
    const response = await fetch(url, config);
    
    // Handle non-JSON responses (like 204 No Content)
    if (response.status === 204) {
      return null;
    }
    
    const data = await response.json();
    
    if (!response.ok) {
      throw new ApiError(
        data.message || 'API request failed',
        response.status,
        data
      );
    }
    
    return data;
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    
    // Network or other errors
    throw new ApiError('Network error or server unavailable', 0, null);
  }
}

// Staff API
export const staffApi = {
  // Get all staff with optional filtering
  async getAll(filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.role) params.append('role', filters.role);
    if (filters.department_id) params.append('department_id', filters.department_id);
    if (filters.porter_type) params.append('porter_type', filters.porter_type);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/staff${query}`);
  },

  // Get staff by ID
  async getById(id) {
    return apiRequest(`/staff/${id}`);
  },

  // Create new staff member
  async create(staffData) {
    return apiRequest('/staff', {
      method: 'POST',
      body: JSON.stringify(staffData)
    });
  },

  // Update staff member
  async update(id, updates) {
    return apiRequest(`/staff/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  // Delete staff member
  async delete(id) {
    return apiRequest(`/staff/${id}`, {
      method: 'DELETE'
    });
  }
};

// Buildings API
export const buildingsApi = {
  async getAll() {
    return apiRequest('/buildings');
  },

  async getById(id) {
    return apiRequest(`/buildings/${id}`);
  },

  async create(buildingData) {
    return apiRequest('/buildings', {
      method: 'POST',
      body: JSON.stringify(buildingData)
    });
  },

  async update(id, updates) {
    return apiRequest(`/buildings/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async delete(id) {
    return apiRequest(`/buildings/${id}`, {
      method: 'DELETE'
    });
  }
};

// Departments API
export const departmentsApi = {
  async getAll(filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.building_id) params.append('building_id', filters.building_id);
    if (filters.is_frequent !== undefined) params.append('is_frequent', filters.is_frequent);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/departments${query}`);
  },

  async getById(id) {
    return apiRequest(`/departments/${id}`);
  },

  async create(departmentData) {
    return apiRequest('/departments', {
      method: 'POST',
      body: JSON.stringify(departmentData)
    });
  },

  async update(id, updates) {
    return apiRequest(`/departments/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async toggleFrequent(id) {
    return apiRequest(`/departments/${id}/toggle-frequent`, {
      method: 'PUT'
    });
  },

  async delete(id) {
    return apiRequest(`/departments/${id}`, {
      method: 'DELETE'
    });
  }
};

// Task Types API
export const taskTypesApi = {
  async getAll(includeItems = false) {
    const query = includeItems ? '?include_items=true' : '';
    return apiRequest(`/task-types${query}`);
  },

  async getById(id, includeItems = true) {
    const query = includeItems ? '?include_items=true' : '?include_items=false';
    return apiRequest(`/task-types/${id}${query}`);
  },

  async create(taskTypeData) {
    return apiRequest('/task-types', {
      method: 'POST',
      body: JSON.stringify(taskTypeData)
    });
  },

  async update(id, updates) {
    return apiRequest(`/task-types/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async delete(id) {
    return apiRequest(`/task-types/${id}`, {
      method: 'DELETE'
    });
  },

  // Task items for a specific task type
  async getItems(taskTypeId, filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.is_regular !== undefined) params.append('is_regular', filters.is_regular);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/task-types/${taskTypeId}/items${query}`);
  },

  async createItem(taskTypeId, itemData) {
    return apiRequest(`/task-types/${taskTypeId}/items`, {
      method: 'POST',
      body: JSON.stringify(itemData)
    });
  },

  // Task type department assignments
  async getAssignments(taskTypeId) {
    return apiRequest(`/task-types/${taskTypeId}/assignments`);
  },

  async updateAssignments(taskTypeId, assignments) {
    return apiRequest(`/task-types/${taskTypeId}/assignments`, {
      method: 'PUT',
      body: JSON.stringify({ assignments })
    });
  }
};

// Task Items API
export const taskItemsApi = {
  async getAll(filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.task_type_id) params.append('task_type_id', filters.task_type_id);
    if (filters.is_regular !== undefined) params.append('is_regular', filters.is_regular);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/task-items${query}`);
  },

  async getById(id) {
    return apiRequest(`/task-items/${id}`);
  },

  async create(itemData) {
    return apiRequest('/task-items', {
      method: 'POST',
      body: JSON.stringify(itemData)
    });
  },

  async update(id, updates) {
    return apiRequest(`/task-items/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async delete(id) {
    return apiRequest(`/task-items/${id}`, {
      method: 'DELETE'
    });
  },

  // Task item department assignments
  async getAssignments(id) {
    return apiRequest(`/task-items/${id}/assignments`);
  },

  async updateAssignments(id, assignments) {
    return apiRequest(`/task-items/${id}/assignments`, {
      method: 'PUT',
      body: JSON.stringify({ assignments })
    });
  }
};

// Area Cover API
export const areaCoverApi = {
  // Get all area cover assignments
  async getAll(filters = {}) {
    const params = new URLSearchParams();
    if (filters.shift_type) params.append('shift_type', filters.shift_type);
    
    const url = params.toString() ? `/area-cover/assignments?${params}` : '/area-cover/assignments';
    const response = await apiRequest(url);
    return response;
  },

  // Get area cover assignment by ID
  async getById(id) {
    const response = await apiRequest(`/area-cover/assignments/${id}`);
    return response;
  },

  // Create new area cover assignment
  async create(assignmentData) {
    const response = await apiRequest('/area-cover/assignments', {
      method: 'POST',
      body: JSON.stringify(assignmentData)
    });
    return response;
  },

  // Update area cover assignment
  async update(id, updates) {
    const response = await apiRequest(`/area-cover/assignments/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
    return response;
  },

  // Delete area cover assignment
  async delete(id) {
    const response = await apiRequest(`/area-cover/assignments/${id}`, {
      method: 'DELETE'
    });
    return response;
  }
};

// Support Services API
export const supportServicesApi = {
  async getAll(filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.is_active !== undefined) params.append('is_active', filters.is_active);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/support-services${query}`);
  },

  async getById(id) {
    return apiRequest(`/support-services/${id}`);
  },

  async create(serviceData) {
    return apiRequest('/support-services', {
      method: 'POST',
      body: JSON.stringify(serviceData)
    });
  },

  async update(id, updates) {
    return apiRequest(`/support-services/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async toggleActive(id) {
    return apiRequest(`/support-services/${id}/toggle-active`, {
      method: 'PUT'
    });
  },

  async delete(id) {
    return apiRequest(`/support-services/${id}`, {
      method: 'DELETE'
    });
  },

  async getAssignments(serviceId, shiftType = null) {
    const query = shiftType ? `?shift_type=${shiftType}` : '';
    return apiRequest(`/support-services/${serviceId}/assignments${query}`);
  },

  async createAssignment(serviceId, assignmentData) {
    return apiRequest(`/support-services/${serviceId}/assignments`, {
      method: 'POST',
      body: JSON.stringify(assignmentData)
    });
  },

  // Default service cover assignments
  async getDefaultAssignments(shiftType = null) {
    const query = shiftType ? `?shift_type=${shiftType}` : '';
    return apiRequest(`/support-services/default-assignments${query}`);
  },

  async createDefaultAssignment(assignmentData) {
    return apiRequest('/support-services/default-assignments', {
      method: 'POST',
      body: JSON.stringify(assignmentData)
    });
  },

  async updateDefaultAssignment(id, updates) {
    return apiRequest(`/support-services/default-assignments/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async deleteDefaultAssignment(id) {
    return apiRequest(`/support-services/default-assignments/${id}`, {
      method: 'DELETE'
    });
  }
};

// Settings API
export const settingsApi = {
  async get() {
    return apiRequest('/settings');
  },

  async update(settings) {
    return apiRequest('/settings', {
      method: 'PUT',
      body: JSON.stringify(settings)
    });
  },

  async getShiftDefaults() {
    return apiRequest('/settings/shift-defaults');
  },

  async updateShiftDefault(id, updates) {
    return apiRequest(`/settings/shift-defaults/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async createShiftDefault(shiftDefaultData) {
    return apiRequest('/settings/shift-defaults', {
      method: 'POST',
      body: JSON.stringify(shiftDefaultData)
    });
  },

  async deleteShiftDefault(id) {
    return apiRequest(`/settings/shift-defaults/${id}`, {
      method: 'DELETE'
    });
  }
};

// Absences API
export const absencesApi = {
  async getAll(filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.porter_id) params.append('porter_id', filters.porter_id);
    if (filters.absence_type) params.append('absence_type', filters.absence_type);
    if (filters.start_date) params.append('start_date', filters.start_date);
    if (filters.end_date) params.append('end_date', filters.end_date);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/absences${query}`);
  },

  async getById(id) {
    return apiRequest(`/absences/${id}`);
  },

  async getByPorter(porterId, filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.start_date) params.append('start_date', filters.start_date);
    if (filters.end_date) params.append('end_date', filters.end_date);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/absences/porter/${porterId}${query}`);
  },

  async create(absenceData) {
    return apiRequest('/absences', {
      method: 'POST',
      body: JSON.stringify(absenceData)
    });
  },

  async update(id, updates) {
    return apiRequest(`/absences/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async delete(id) {
    return apiRequest(`/absences/${id}`, {
      method: 'DELETE'
    });
  }
};

// Shifts API
export const shiftsApi = {
  async getAll(filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.is_active !== undefined) params.append('is_active', filters.is_active);
    if (filters.shift_type) params.append('shift_type', filters.shift_type);
    if (filters.supervisor_id) params.append('supervisor_id', filters.supervisor_id);
    if (filters.shift_date) params.append('shift_date', filters.shift_date);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/shifts${query}`);
  },

  async getById(id) {
    return apiRequest(`/shifts/${id}`);
  },

  async create(shiftData) {
    return apiRequest('/shifts', {
      method: 'POST',
      body: JSON.stringify(shiftData)
    });
  },

  async update(id, updates) {
    return apiRequest(`/shifts/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async delete(id) {
    return apiRequest(`/shifts/${id}`, {
      method: 'DELETE'
    });
  },

  async endShift(id) {
    return apiRequest(`/shifts/${id}/end`, {
      method: 'PUT'
    });
  },

  // Shift area cover endpoints
  async getAreaCover(id) {
    return apiRequest(`/shifts/${id}/area-cover`);
  },

  async initializeAreaCover(id) {
    return apiRequest(`/shifts/${id}/area-cover/initialize`, {
      method: 'POST'
    });
  },

  // Shift support services endpoints
  async getSupportServices(id) {
    return apiRequest(`/shifts/${id}/support-services`);
  },

  async initializeSupportServices(id) {
    return apiRequest(`/shifts/${id}/support-services/initialize`, {
      method: 'POST'
    });
  },

  // Shift porter pool endpoints
  async getPorterPool(id) {
    return apiRequest(`/shifts/${id}/porter-pool`);
  },

  async addPorterToPool(id, porterId) {
    return apiRequest(`/shifts/${id}/porter-pool`, {
      method: 'POST',
      body: JSON.stringify({ porter_id: porterId })
    });
  },

  async removePorterFromPool(id, porterId) {
    return apiRequest(`/shifts/${id}/porter-pool/${porterId}`, {
      method: 'DELETE'
    });
  },

  // Area cover porter assignment endpoints
  async addAreaCoverPorter(shiftId, areaCoverId, porterData) {
    return apiRequest(`/shifts/${shiftId}/area-cover/${areaCoverId}/porter-assignments`, {
      method: 'POST',
      body: JSON.stringify(porterData)
    });
  },

  async updateAreaCoverPorter(shiftId, assignmentId, updates) {
    return apiRequest(`/shifts/${shiftId}/area-cover/porter-assignments/${assignmentId}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async removeAreaCoverPorter(shiftId, assignmentId) {
    return apiRequest(`/shifts/${shiftId}/area-cover/porter-assignments/${assignmentId}`, {
      method: 'DELETE'
    });
  },

  // Support service porter assignment endpoints
  async addSupportServicePorter(shiftId, serviceId, porterData) {
    return apiRequest(`/shifts/${shiftId}/support-services/${serviceId}/porter-assignments`, {
      method: 'POST',
      body: JSON.stringify(porterData)
    });
  },

  async updateSupportServicePorter(shiftId, assignmentId, updates) {
    return apiRequest(`/shifts/${shiftId}/support-services/porter-assignments/${assignmentId}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async removeSupportServicePorter(shiftId, assignmentId) {
    return apiRequest(`/shifts/${shiftId}/support-services/porter-assignments/${assignmentId}`, {
      method: 'DELETE'
    });
  }
};

// Tasks API
export const tasksApi = {
  async getAll(filters = {}) {
    const params = new URLSearchParams();
    
    if (filters.shift_id) params.append('shift_id', filters.shift_id);
    if (filters.status) params.append('status', filters.status);
    if (filters.porter_id) params.append('porter_id', filters.porter_id);
    if (filters.task_item_id) params.append('task_item_id', filters.task_item_id);
    if (filters.limit) params.append('limit', filters.limit);
    if (filters.offset) params.append('offset', filters.offset);
    
    const query = params.toString() ? `?${params.toString()}` : '';
    return apiRequest(`/tasks${query}`);
  },

  async getById(id) {
    return apiRequest(`/tasks/${id}`);
  },

  async getByShiftId(shiftId) {
    return apiRequest(`/tasks?shift_id=${shiftId}`);
  },

  async create(taskData) {
    return apiRequest('/tasks', {
      method: 'POST',
      body: JSON.stringify(taskData)
    });
  },

  async update(id, updates) {
    return apiRequest(`/tasks/${id}`, {
      method: 'PUT',
      body: JSON.stringify(updates)
    });
  },

  async delete(id) {
    return apiRequest(`/tasks/${id}`, {
      method: 'DELETE'
    });
  }
};


// Export the API error class and apiRequest function for error handling
export { ApiError, apiRequest };

// Default export for backward compatibility
export default {
  staffApi,
  buildingsApi,
  departmentsApi,
  taskTypesApi,
  taskItemsApi,
  supportServicesApi,
  settingsApi,
  ApiError
};
