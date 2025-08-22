import { z } from 'zod';
import { buildings } from '@hospital-tasks/database';
import { CreateBuildingRequest, UpdateBuildingRequest } from '@hospital-tasks/shared';
import { createCRUDRoutes } from '../utils/crud-factory.js';

// Building-specific schemas
const BuildingInsertSchema = CreateBuildingRequest.extend({
  id: z.string().uuid().optional(),
  createdAt: z.date().optional(),
  updatedAt: z.date().optional(),
});

const BuildingUpdateSchema = UpdateBuildingRequest;

const BuildingSelectSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  address: z.string().nullable(),
  sortOrder: z.number().int(),
  porterServiced: z.boolean(),
  abbreviation: z.string().nullable(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

// Create CRUD routes
export const buildingRoutes = createCRUDRoutes({
  table: buildings,
  entityName: 'Building',
  insertSchema: BuildingInsertSchema,
  updateSchema: BuildingUpdateSchema,
  selectSchema: BuildingSelectSchema,
  searchFields: ['name', 'address'],
  defaultOrderBy: { field: 'sortOrder', direction: 'asc' },
  maxLimit: 200,
});
