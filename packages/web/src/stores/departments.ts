import { createEntityStore } from './createEntityStore';
import { useDepartmentsApi } from '../composables/useApi';
import type { Department, CreateDepartmentRequest, UpdateDepartmentRequest } from '@hospital-tasks/shared';

// Create departments store using the DRY factory
export const useDepartmentsStore = createEntityStore<Department, CreateDepartmentRequest, UpdateDepartmentRequest>({
  name: 'departments',
  apiComposable: useDepartmentsApi,
});
