import { createEntityStore } from './createEntityStore';
import { useStaffApi } from '../composables/useApi';
import type { Staff, CreateStaffRequest, UpdateStaffRequest } from '@hospital-tasks/shared';

// Create staff store using the DRY factory
export const useStaffStore = createEntityStore<Staff, CreateStaffRequest, UpdateStaffRequest>({
  name: 'staff',
  apiComposable: useStaffApi,
});
