import { z } from 'zod';
import { supportServices } from '@hospital-tasks/database';
import { CreateSupportServiceRequest, UpdateSupportServiceRequest } from '@hospital-tasks/shared';
import { createCRUDRoutes } from '../utils/crud-factory.js';

// SupportService-specific schemas
const SupportServiceInsertSchema = CreateSupportServiceRequest.extend({
  id: z.string().uuid().optional(),
  createdAt: z.date().optional(),
  updatedAt: z.date().optional(),
});

const SupportServiceUpdateSchema = UpdateSupportServiceRequest;

const SupportServiceSelectSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  isActive: z.boolean(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

// Create CRUD routes
export const supportServiceRoutes = createCRUDRoutes({
  table: supportServices,
  entityName: 'Support service',
  insertSchema: SupportServiceInsertSchema,
  updateSchema: SupportServiceUpdateSchema,
  selectSchema: SupportServiceSelectSchema,
  searchFields: ['name', 'description'],
  defaultOrderBy: { field: 'name', direction: 'asc' },
  maxLimit: 200,
});
