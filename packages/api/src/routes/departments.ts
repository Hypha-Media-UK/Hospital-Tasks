import { z } from 'zod';
import { departments } from '@hospital-tasks/database';
import { CreateDepartmentRequest, UpdateDepartmentRequest } from '@hospital-tasks/shared';
import { createCRUDRoutes } from '../utils/crud-factory.js';

// Department-specific schemas
const DepartmentInsertSchema = CreateDepartmentRequest.extend({
  id: z.string().uuid().optional(),
  createdAt: z.date().optional(),
  updatedAt: z.date().optional(),
});

const DepartmentUpdateSchema = UpdateDepartmentRequest;

const DepartmentSelectSchema = z.object({
  id: z.string().uuid(),
  buildingId: z.string().uuid(),
  name: z.string(),
  isFrequent: z.boolean(),
  sortOrder: z.number().int(),
  color: z.string(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

// Create CRUD routes
export const departmentRoutes = createCRUDRoutes({
  table: departments,
  entityName: 'Department',
  insertSchema: DepartmentInsertSchema,
  updateSchema: DepartmentUpdateSchema,
  selectSchema: DepartmentSelectSchema,
  searchFields: ['name'],
  defaultOrderBy: { field: 'sortOrder', direction: 'asc' },
  maxLimit: 500,
});
