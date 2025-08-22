import { z } from 'zod';
import { staff } from '@hospital-tasks/database';
import { CreateStaffRequest, UpdateStaffRequest } from '@hospital-tasks/shared';
import { createCRUDRoutes } from '../utils/crud-factory.js';

// Staff-specific schemas for database operations
const StaffInsertSchema = CreateStaffRequest.extend({
  id: z.string().uuid().optional(),
  createdAt: z.date().optional(),
  updatedAt: z.date().optional(),
});

const StaffUpdateSchema = UpdateStaffRequest;

const StaffSelectSchema = z.object({
  id: z.string().uuid(),
  firstName: z.string(),
  lastName: z.string(),
  role: z.enum(['supervisor', 'porter']),
  departmentId: z.string().uuid().nullable(),
  porterType: z.enum(['shift', 'relief']).nullable(),
  availabilityPattern: z.string().nullable(),
  contractedHoursStart: z.string().nullable(),
  contractedHoursEnd: z.string().nullable(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

// Create CRUD routes with configuration
export const staffRoutes = createCRUDRoutes({
  table: staff,
  entityName: 'Staff member',
  insertSchema: StaffInsertSchema,
  updateSchema: StaffUpdateSchema,
  selectSchema: StaffSelectSchema,
  searchFields: ['firstName', 'lastName'],
  defaultOrderBy: { field: 'lastName', direction: 'asc' },
  maxLimit: 500,
});
