import { z } from 'zod';
import { taskTypes } from '@hospital-tasks/database';
import { CreateTaskTypeRequest, UpdateTaskTypeRequest } from '@hospital-tasks/shared';
import { createCRUDRoutes } from '../utils/crud-factory.js';

// TaskType-specific schemas
const TaskTypeInsertSchema = CreateTaskTypeRequest.extend({
  id: z.string().uuid().optional(),
  createdAt: z.date().optional(),
  updatedAt: z.date().optional(),
});

const TaskTypeUpdateSchema = UpdateTaskTypeRequest;

const TaskTypeSelectSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

// Create CRUD routes
export const taskTypeRoutes = createCRUDRoutes({
  table: taskTypes,
  entityName: 'Task type',
  insertSchema: TaskTypeInsertSchema,
  updateSchema: TaskTypeUpdateSchema,
  selectSchema: TaskTypeSelectSchema,
  searchFields: ['name', 'description'],
  defaultOrderBy: { field: 'name', direction: 'asc' },
  maxLimit: 200,
});
