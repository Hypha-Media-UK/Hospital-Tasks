import { z } from 'zod';
import { taskItems } from '@hospital-tasks/database';
import { CreateTaskItemRequest, UpdateTaskItemRequest } from '@hospital-tasks/shared';
import { createCRUDRoutes } from '../utils/crud-factory.js';

// TaskItem-specific schemas
const TaskItemInsertSchema = CreateTaskItemRequest.extend({
  id: z.string().uuid().optional(),
  createdAt: z.date().optional(),
  updatedAt: z.date().optional(),
});

const TaskItemUpdateSchema = UpdateTaskItemRequest;

const TaskItemSelectSchema = z.object({
  id: z.string().uuid(),
  taskTypeId: z.string().uuid(),
  name: z.string(),
  description: z.string().nullable(),
  isRegular: z.boolean(),
  portersRequired: z.number().int(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

// Create CRUD routes
export const taskItemRoutes = createCRUDRoutes({
  table: taskItems,
  entityName: 'Task item',
  insertSchema: TaskItemInsertSchema,
  updateSchema: TaskItemUpdateSchema,
  selectSchema: TaskItemSelectSchema,
  searchFields: ['name', 'description'],
  defaultOrderBy: { field: 'name', direction: 'asc' },
  maxLimit: 1000,
});
