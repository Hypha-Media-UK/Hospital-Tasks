import { ref, computed } from 'vue';
import type { 
  PaginationParams, 
  PaginationMeta,
  ApiError 
} from '@hospital-tasks/shared';

// ============================================================================
// API COMPOSABLE - DRY HTTP CLIENT
// ============================================================================

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';

interface ApiResponse<T> {
  data: T;
  pagination?: PaginationMeta;
}

interface ApiRequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: any;
  params?: Record<string, string | number>;
}

export function useApi() {
  const loading = ref(false);
  const error = ref<string | null>(null);

  // Generic API request function
  async function request<T>(
    endpoint: string, 
    options: ApiRequestOptions = {}
  ): Promise<T> {
    loading.value = true;
    error.value = null;

    try {
      const { method = 'GET', body, params } = options;
      
      // Build URL with query parameters
      const url = new URL(`${API_BASE_URL}/api${endpoint}`);
      if (params) {
        Object.entries(params).forEach(([key, value]) => {
          url.searchParams.append(key, String(value));
        });
      }

      // Prepare request options
      const requestOptions: RequestInit = {
        method,
        headers: {
          'Content-Type': 'application/json',
        },
      };

      if (body && method !== 'GET') {
        requestOptions.body = JSON.stringify(body);
      }

      // Make request
      const response = await fetch(url.toString(), requestOptions);
      
      if (!response.ok) {
        const errorData: ApiError = await response.json();
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      // Handle 204 No Content
      if (response.status === 204) {
        return null as T;
      }

      return await response.json();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'An error occurred';
      error.value = message;
      throw new Error(message);
    } finally {
      loading.value = false;
    }
  }

  // CRUD operations
  const crud = {
    // Get all entities with pagination
    async getAll<T>(
      endpoint: string, 
      params?: PaginationParams & { search?: string }
    ): Promise<ApiResponse<T[]>> {
      return request<ApiResponse<T[]>>(endpoint, { params });
    },

    // Get single entity
    async getOne<T>(endpoint: string, id: string): Promise<T> {
      return request<T>(`${endpoint}/${id}`);
    },

    // Create entity
    async create<T, TCreate>(endpoint: string, data: TCreate): Promise<T> {
      return request<T>(endpoint, {
        method: 'POST',
        body: data,
      });
    },

    // Update entity
    async update<T, TUpdate>(
      endpoint: string, 
      id: string, 
      data: TUpdate
    ): Promise<T> {
      return request<T>(`${endpoint}/${id}`, {
        method: 'PUT',
        body: data,
      });
    },

    // Delete entity
    async delete(endpoint: string, id: string): Promise<void> {
      return request<void>(`${endpoint}/${id}`, {
        method: 'DELETE',
      });
    },
  };

  return {
    loading: computed(() => loading.value),
    error: computed(() => error.value),
    request,
    crud,
  };
}

// ============================================================================
// ENTITY-SPECIFIC COMPOSABLES
// ============================================================================

export function useStaffApi() {
  const api = useApi();
  
  return {
    ...api,
    getStaff: (params?: PaginationParams & { search?: string }) => 
      api.crud.getAll('/staff', params),
    getStaffMember: (id: string) => 
      api.crud.getOne('/staff', id),
    createStaff: (data: any) => 
      api.crud.create('/staff', data),
    updateStaff: (id: string, data: any) => 
      api.crud.update('/staff', id, data),
    deleteStaff: (id: string) => 
      api.crud.delete('/staff', id),
  };
}

export function useBuildingsApi() {
  const api = useApi();
  
  return {
    ...api,
    getBuildings: (params?: PaginationParams & { search?: string }) => 
      api.crud.getAll('/buildings', params),
    getBuilding: (id: string) => 
      api.crud.getOne('/buildings', id),
    createBuilding: (data: any) => 
      api.crud.create('/buildings', data),
    updateBuilding: (id: string, data: any) => 
      api.crud.update('/buildings', id, data),
    deleteBuilding: (id: string) => 
      api.crud.delete('/buildings', id),
  };
}

export function useDepartmentsApi() {
  const api = useApi();
  
  return {
    ...api,
    getDepartments: (params?: PaginationParams & { search?: string }) => 
      api.crud.getAll('/departments', params),
    getDepartment: (id: string) => 
      api.crud.getOne('/departments', id),
    createDepartment: (data: any) => 
      api.crud.create('/departments', data),
    updateDepartment: (id: string, data: any) => 
      api.crud.update('/departments', id, data),
    deleteDepartment: (id: string) => 
      api.crud.delete('/departments', id),
  };
}

export function useTaskTypesApi() {
  const api = useApi();
  
  return {
    ...api,
    getTaskTypes: (params?: PaginationParams & { search?: string }) => 
      api.crud.getAll('/task-types', params),
    getTaskType: (id: string) => 
      api.crud.getOne('/task-types', id),
    createTaskType: (data: any) => 
      api.crud.create('/task-types', data),
    updateTaskType: (id: string, data: any) => 
      api.crud.update('/task-types', id, data),
    deleteTaskType: (id: string) => 
      api.crud.delete('/task-types', id),
  };
}

export function useTaskItemsApi() {
  const api = useApi();
  
  return {
    ...api,
    getTaskItems: (params?: PaginationParams & { search?: string }) => 
      api.crud.getAll('/task-items', params),
    getTaskItem: (id: string) => 
      api.crud.getOne('/task-items', id),
    createTaskItem: (data: any) => 
      api.crud.create('/task-items', data),
    updateTaskItem: (id: string, data: any) => 
      api.crud.update('/task-items', id, data),
    deleteTaskItem: (id: string) => 
      api.crud.delete('/task-items', id),
  };
}

export function useSupportServicesApi() {
  const api = useApi();
  
  return {
    ...api,
    getSupportServices: (params?: PaginationParams & { search?: string }) => 
      api.crud.getAll('/support-services', params),
    getSupportService: (id: string) => 
      api.crud.getOne('/support-services', id),
    createSupportService: (data: any) => 
      api.crud.create('/support-services', data),
    updateSupportService: (id: string, data: any) => 
      api.crud.update('/support-services', id, data),
    deleteSupportService: (id: string) => 
      api.crud.delete('/support-services', id),
  };
}
