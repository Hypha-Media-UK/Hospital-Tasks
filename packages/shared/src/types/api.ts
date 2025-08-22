import { z } from 'zod';

// ============================================================================
// GENERIC API TYPES
// ============================================================================

export const PaginationParams = z.object({
  limit: z.number().int().min(1).max(1000).default(100),
  offset: z.number().int().min(0).default(0),
});

export const SearchParams = z.object({
  search: z.string().optional(),
});

export const PaginationMeta = z.object({
  total: z.number().int(),
  limit: z.number().int(),
  offset: z.number().int(),
  hasMore: z.boolean(),
});

export const PaginatedResponse = <T extends z.ZodTypeAny>(dataSchema: T) =>
  z.object({
    data: z.array(dataSchema),
    pagination: PaginationMeta,
  });

export const ApiError = z.object({
  error: z.string(),
  message: z.string(),
  details: z.unknown().optional(),
});

// ============================================================================
// CRUD OPERATION TYPES
// ============================================================================

export const CreateRequest = <T extends z.ZodTypeAny>(schema: T) =>
  schema.omit({ id: true, created_at: true, updated_at: true });

export const UpdateRequest = <T extends z.ZodTypeAny>(schema: T) =>
  schema.omit({ id: true, created_at: true, updated_at: true }).partial();

export const ListParams = PaginationParams.merge(SearchParams);

// ============================================================================
// ENTITY-SPECIFIC API TYPES
// ============================================================================

// Staff API Types
export const CreateStaffRequest = CreateRequest(z.object({
  first_name: z.string().min(1).max(255),
  last_name: z.string().min(1).max(255),
  role: z.enum(['supervisor', 'porter']),
  department_id: z.string().uuid().optional(),
  porter_type: z.enum(['shift', 'relief']).optional(),
  availability_pattern: z.string().max(100).optional(),
  contracted_hours_start: z.string().optional(),
  contracted_hours_end: z.string().optional(),
}));

export const UpdateStaffRequest = UpdateRequest(CreateStaffRequest);

// Building API Types
export const CreateBuildingRequest = CreateRequest(z.object({
  name: z.string().min(1).max(255),
  address: z.string().optional(),
  sort_order: z.number().int().default(0),
  porter_serviced: z.boolean().default(true),
  abbreviation: z.string().max(10).optional(),
}));

export const UpdateBuildingRequest = UpdateRequest(CreateBuildingRequest);

// Department API Types
export const CreateDepartmentRequest = CreateRequest(z.object({
  building_id: z.string().uuid(),
  name: z.string().min(1).max(255),
  is_frequent: z.boolean().default(false),
  sort_order: z.number().int().default(0),
  color: z.string().regex(/^#[0-9A-F]{6}$/i).default('#CCCCCC'),
}));

export const UpdateDepartmentRequest = UpdateRequest(CreateDepartmentRequest);

// Task Type API Types
export const CreateTaskTypeRequest = CreateRequest(z.object({
  name: z.string().min(1).max(255),
  description: z.string().optional(),
}));

export const UpdateTaskTypeRequest = UpdateRequest(CreateTaskTypeRequest);

// Task Item API Types
export const CreateTaskItemRequest = CreateRequest(z.object({
  task_type_id: z.string().uuid(),
  name: z.string().min(1).max(255),
  description: z.string().optional(),
  is_regular: z.boolean().default(false),
  porters_required: z.number().int().min(1).default(1),
}));

export const UpdateTaskItemRequest = UpdateRequest(CreateTaskItemRequest);

// Support Service API Types
export const CreateSupportServiceRequest = CreateRequest(z.object({
  name: z.string().min(1).max(255),
  description: z.string().optional(),
  is_active: z.boolean().default(true),
}));

export const UpdateSupportServiceRequest = UpdateRequest(CreateSupportServiceRequest);

// Porter Assignment API Types
export const CreatePorterAssignmentRequest = z.object({
  porter_id: z.string().uuid(),
  start_time: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/),
  end_time: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/),
  agreed_absence: z.boolean().default(false),
});

export const UpdatePorterAssignmentRequest = CreatePorterAssignmentRequest.partial();

// ============================================================================
// TYPE EXPORTS
// ============================================================================

export type PaginationParams = z.infer<typeof PaginationParams>;
export type SearchParams = z.infer<typeof SearchParams>;
export type PaginationMeta = z.infer<typeof PaginationMeta>;
export type ApiError = z.infer<typeof ApiError>;
export type ListParams = z.infer<typeof ListParams>;

export type CreateStaffRequest = z.infer<typeof CreateStaffRequest>;
export type UpdateStaffRequest = z.infer<typeof UpdateStaffRequest>;
export type CreateBuildingRequest = z.infer<typeof CreateBuildingRequest>;
export type UpdateBuildingRequest = z.infer<typeof UpdateBuildingRequest>;
export type CreateDepartmentRequest = z.infer<typeof CreateDepartmentRequest>;
export type UpdateDepartmentRequest = z.infer<typeof UpdateDepartmentRequest>;
export type CreateTaskTypeRequest = z.infer<typeof CreateTaskTypeRequest>;
export type UpdateTaskTypeRequest = z.infer<typeof UpdateTaskTypeRequest>;
export type CreateTaskItemRequest = z.infer<typeof CreateTaskItemRequest>;
export type UpdateTaskItemRequest = z.infer<typeof UpdateTaskItemRequest>;
export type CreateSupportServiceRequest = z.infer<typeof CreateSupportServiceRequest>;
export type UpdateSupportServiceRequest = z.infer<typeof UpdateSupportServiceRequest>;
export type CreatePorterAssignmentRequest = z.infer<typeof CreatePorterAssignmentRequest>;
export type UpdatePorterAssignmentRequest = z.infer<typeof UpdatePorterAssignmentRequest>;
