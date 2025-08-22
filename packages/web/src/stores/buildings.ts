import { createEntityStore } from './createEntityStore';
import { useBuildingsApi } from '../composables/useApi';
import type { Building, CreateBuildingRequest, UpdateBuildingRequest } from '@hospital-tasks/shared';

// Create buildings store using the DRY factory
export const useBuildingsStore = createEntityStore<Building, CreateBuildingRequest, UpdateBuildingRequest>({
  name: 'buildings',
  apiComposable: useBuildingsApi,
});
