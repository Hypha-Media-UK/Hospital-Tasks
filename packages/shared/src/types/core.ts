import { z } from 'zod';

// ============================================================================
// ENUMS
// ============================================================================

export const StaffRole = z.enum(['supervisor', 'porter']);
export type StaffRole = z.infer<typeof StaffRole>;

export const PorterType = z.enum(['shift', 'relief']);
export type PorterType = z.infer<typeof PorterType>;

export const ShiftType = z.enum(['day', 'night']);
export type ShiftType = z.infer<typeof ShiftType>;

export const TaskStatus = z.enum(['pending', 'allocated', 'in_progress', 'completed', 'cancelled']);
export type TaskStatus = z.infer<typeof TaskStatus>;

export const AbsenceType = z.enum(['sick', 'holiday', 'training', 'other']);
export type AbsenceType = z.infer<typeof AbsenceType>;

// ============================================================================
// BASE SCHEMAS
// ============================================================================

export const BaseEntity = z.object({
  id: z.string().uuid(),
  created_at: z.date(),
  updated_at: z.date(),
});

export const TimeRange = z.object({
  start_time: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/), // HH:MM format
  end_time: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/),
});

// ============================================================================
// CORE ENTITIES
// ============================================================================

export const Staff = BaseEntity.extend({
  first_name: z.string().min(1).max(255),
  last_name: z.string().min(1).max(255),
  role: StaffRole,
  department_id: z.string().uuid().optional(),
  porter_type: PorterType.optional(),
  availability_pattern: z.string().max(100).optional(),
  contracted_hours_start: z.string().optional(),
  contracted_hours_end: z.string().optional(),
});

export const Building = BaseEntity.extend({
  name: z.string().min(1).max(255),
  address: z.string().optional(),
  sort_order: z.number().int().default(0),
  porter_serviced: z.boolean().default(true),
  abbreviation: z.string().max(10).optional(),
});

export const Department = BaseEntity.extend({
  building_id: z.string().uuid(),
  name: z.string().min(1).max(255),
  is_frequent: z.boolean().default(false),
  sort_order: z.number().int().default(0),
  color: z.string().regex(/^#[0-9A-F]{6}$/i).default('#CCCCCC'),
});

export const TaskType = BaseEntity.extend({
  name: z.string().min(1).max(255),
  description: z.string().optional(),
});

export const TaskItem = BaseEntity.extend({
  task_type_id: z.string().uuid(),
  name: z.string().min(1).max(255),
  description: z.string().optional(),
  is_regular: z.boolean().default(false),
  porters_required: z.number().int().min(1).default(1),
});

export const SupportService = BaseEntity.extend({
  name: z.string().min(1).max(255),
  description: z.string().optional(),
  is_active: z.boolean().default(true),
});

export const Shift = BaseEntity.extend({
  shift_type: ShiftType,
  shift_date: z.date(),
  is_active: z.boolean().default(false),
});

// ============================================================================
// ASSIGNMENT ENTITIES
// ============================================================================

export const AreaCoverAssignment = BaseEntity.extend({
  shift_id: z.string().uuid(),
  department_id: z.string().uuid(),
  ...TimeRange.shape,
  color: z.string().regex(/^#[0-9A-F]{6}$/i).default('#4285F4'),
  minimum_porters: z.number().int().min(0).default(1),
  minimum_porters_mon: z.number().int().min(0).default(1),
  minimum_porters_tue: z.number().int().min(0).default(1),
  minimum_porters_wed: z.number().int().min(0).default(1),
  minimum_porters_thu: z.number().int().min(0).default(1),
  minimum_porters_fri: z.number().int().min(0).default(1),
  minimum_porters_sat: z.number().int().min(0).default(1),
  minimum_porters_sun: z.number().int().min(0).default(1),
});

export const SupportServiceAssignment = BaseEntity.extend({
  shift_id: z.string().uuid(),
  service_id: z.string().uuid(),
  ...TimeRange.shape,
  color: z.string().regex(/^#[0-9A-F]{6}$/i).default('#4285F4'),
  minimum_porters: z.number().int().min(0).default(1),
  minimum_porters_mon: z.number().int().min(0).default(1),
  minimum_porters_tue: z.number().int().min(0).default(1),
  minimum_porters_wed: z.number().int().min(0).default(1),
  minimum_porters_thu: z.number().int().min(0).default(1),
  minimum_porters_fri: z.number().int().min(0).default(1),
  minimum_porters_sat: z.number().int().min(0).default(1),
  minimum_porters_sun: z.number().int().min(0).default(1),
});

export const PorterAssignment = BaseEntity.extend({
  porter_id: z.string().uuid(),
  ...TimeRange.shape,
  agreed_absence: z.boolean().default(false),
});

export const AreaCoverPorterAssignment = PorterAssignment.extend({
  area_cover_assignment_id: z.string().uuid(),
});

export const SupportServicePorterAssignment = PorterAssignment.extend({
  support_service_assignment_id: z.string().uuid(),
});

export const Task = BaseEntity.extend({
  shift_id: z.string().uuid(),
  task_item_id: z.string().uuid(),
  porter_id: z.string().uuid().optional(),
  origin_department_id: z.string().uuid().optional(),
  destination_department_id: z.string().uuid().optional(),
  status: TaskStatus.default('pending'),
  time_received: z.date().optional(),
  time_allocated: z.date().optional(),
  time_completed: z.date().optional(),
});

// ============================================================================
// TYPE EXPORTS
// ============================================================================

export type Staff = z.infer<typeof Staff>;
export type Building = z.infer<typeof Building>;
export type Department = z.infer<typeof Department>;
export type TaskType = z.infer<typeof TaskType>;
export type TaskItem = z.infer<typeof TaskItem>;
export type SupportService = z.infer<typeof SupportService>;
export type Shift = z.infer<typeof Shift>;
export type AreaCoverAssignment = z.infer<typeof AreaCoverAssignment>;
export type SupportServiceAssignment = z.infer<typeof SupportServiceAssignment>;
export type PorterAssignment = z.infer<typeof PorterAssignment>;
export type AreaCoverPorterAssignment = z.infer<typeof AreaCoverPorterAssignment>;
export type SupportServicePorterAssignment = z.infer<typeof SupportServicePorterAssignment>;
export type Task = z.infer<typeof Task>;
