import {
  mysqlTable,
  varchar,
  text,
  boolean,
  int,
  timestamp,
  time,
  date,
  mysqlEnum,
  index,
  primaryKey,
} from 'drizzle-orm/mysql-core';
import { relations } from 'drizzle-orm';

// ============================================================================
// CORE TABLES
// ============================================================================

export const staff = mysqlTable('staff', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  firstName: varchar('first_name', { length: 255 }).notNull(),
  lastName: varchar('last_name', { length: 255 }).notNull(),
  role: mysqlEnum('role', ['supervisor', 'porter']).notNull(),
  departmentId: varchar('department_id', { length: 36 }),
  porterType: mysqlEnum('porter_type', ['shift', 'relief']).default('shift'),
  availabilityPattern: varchar('availability_pattern', { length: 100 }),
  contractedHoursStart: time('contracted_hours_start'),
  contractedHoursEnd: time('contracted_hours_end'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  departmentIdx: index('idx_staff_department').on(table.departmentId),
  roleIdx: index('idx_staff_role').on(table.role),
}));

export const buildings = mysqlTable('buildings', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: varchar('name', { length: 255 }).notNull(),
  address: text('address'),
  sortOrder: int('sort_order').default(0),
  porterServiced: boolean('porter_serviced').default(true),
  abbreviation: varchar('abbreviation', { length: 10 }),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  sortOrderIdx: index('idx_buildings_sort_order').on(table.sortOrder),
}));

export const departments = mysqlTable('departments', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  buildingId: varchar('building_id', { length: 36 }).notNull(),
  name: varchar('name', { length: 255 }).notNull(),
  isFrequent: boolean('is_frequent').default(false),
  sortOrder: int('sort_order').default(0),
  color: varchar('color', { length: 7 }).default('#CCCCCC'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  buildingIdx: index('idx_departments_building').on(table.buildingId),
  sortOrderIdx: index('idx_departments_sort_order').on(table.sortOrder),
}));

export const taskTypes = mysqlTable('task_types', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: varchar('name', { length: 255 }).notNull(),
  description: text('description'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
});

export const taskItems = mysqlTable('task_items', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  taskTypeId: varchar('task_type_id', { length: 36 }).notNull(),
  name: varchar('name', { length: 255 }).notNull(),
  description: text('description'),
  isRegular: boolean('is_regular').default(false),
  portersRequired: int('porters_required').default(1),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  taskTypeIdx: index('idx_task_items_task_type').on(table.taskTypeId),
  isRegularIdx: index('idx_task_items_is_regular').on(table.isRegular),
}));

export const supportServices = mysqlTable('support_services', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  name: varchar('name', { length: 255 }).notNull(),
  description: text('description'),
  isActive: boolean('is_active').default(true),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  isActiveIdx: index('idx_support_services_is_active').on(table.isActive),
}));

export const shifts = mysqlTable('shifts', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  shiftType: mysqlEnum('shift_type', ['day', 'night']).notNull(),
  shiftDate: date('shift_date').notNull(),
  isActive: boolean('is_active').default(false),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  shiftDateIdx: index('idx_shifts_shift_date').on(table.shiftDate),
  isActiveIdx: index('idx_shifts_is_active').on(table.isActive),
  shiftTypeIdx: index('idx_shifts_shift_type').on(table.shiftType),
}));

// ============================================================================
// ASSIGNMENT TABLES
// ============================================================================

export const areaCoverAssignments = mysqlTable('area_cover_assignments', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  shiftId: varchar('shift_id', { length: 36 }).notNull(),
  departmentId: varchar('department_id', { length: 36 }).notNull(),
  startTime: time('start_time').notNull(),
  endTime: time('end_time').notNull(),
  color: varchar('color', { length: 7 }).default('#4285F4'),
  minimumPorters: int('minimum_porters').default(1),
  minimumPortersMon: int('minimum_porters_mon').default(1),
  minimumPortersTue: int('minimum_porters_tue').default(1),
  minimumPortersWed: int('minimum_porters_wed').default(1),
  minimumPortersThu: int('minimum_porters_thu').default(1),
  minimumPortersFri: int('minimum_porters_fri').default(1),
  minimumPortersSat: int('minimum_porters_sat').default(1),
  minimumPortersSun: int('minimum_porters_sun').default(1),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  shiftIdx: index('idx_area_cover_shift').on(table.shiftId),
  departmentIdx: index('idx_area_cover_department').on(table.departmentId),
}));

export const supportServiceAssignments = mysqlTable('support_service_assignments', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  shiftId: varchar('shift_id', { length: 36 }).notNull(),
  serviceId: varchar('service_id', { length: 36 }).notNull(),
  startTime: time('start_time').notNull(),
  endTime: time('end_time').notNull(),
  color: varchar('color', { length: 7 }).default('#4285F4'),
  minimumPorters: int('minimum_porters').default(1),
  minimumPortersMon: int('minimum_porters_mon').default(1),
  minimumPortersTue: int('minimum_porters_tue').default(1),
  minimumPortersWed: int('minimum_porters_wed').default(1),
  minimumPortersThu: int('minimum_porters_thu').default(1),
  minimumPortersFri: int('minimum_porters_fri').default(1),
  minimumPortersSat: int('minimum_porters_sat').default(1),
  minimumPortersSun: int('minimum_porters_sun').default(1),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  shiftIdx: index('idx_support_service_shift').on(table.shiftId),
  serviceIdx: index('idx_support_service_service').on(table.serviceId),
}));

export const areaCoverPorterAssignments = mysqlTable('area_cover_porter_assignments', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  areaCoverAssignmentId: varchar('area_cover_assignment_id', { length: 36 }).notNull(),
  porterId: varchar('porter_id', { length: 36 }).notNull(),
  startTime: time('start_time').notNull(),
  endTime: time('end_time').notNull(),
  agreedAbsence: boolean('agreed_absence').default(false),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  assignmentIdx: index('idx_area_cover_porter_assignment').on(table.areaCoverAssignmentId),
  porterIdx: index('idx_area_cover_porter_porter').on(table.porterId),
}));

export const supportServicePorterAssignments = mysqlTable('support_service_porter_assignments', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  supportServiceAssignmentId: varchar('support_service_assignment_id', { length: 36 }).notNull(),
  porterId: varchar('porter_id', { length: 36 }).notNull(),
  startTime: time('start_time').notNull(),
  endTime: time('end_time').notNull(),
  agreedAbsence: boolean('agreed_absence').default(false),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  assignmentIdx: index('idx_support_service_porter_assignment').on(table.supportServiceAssignmentId),
  porterIdx: index('idx_support_service_porter_porter').on(table.porterId),
}));

export const tasks = mysqlTable('tasks', {
  id: varchar('id', { length: 36 }).primaryKey().$defaultFn(() => crypto.randomUUID()),
  shiftId: varchar('shift_id', { length: 36 }).notNull(),
  taskItemId: varchar('task_item_id', { length: 36 }).notNull(),
  porterId: varchar('porter_id', { length: 36 }),
  originDepartmentId: varchar('origin_department_id', { length: 36 }),
  destinationDepartmentId: varchar('destination_department_id', { length: 36 }),
  status: mysqlEnum('status', ['pending', 'allocated', 'in_progress', 'completed', 'cancelled']).default('pending'),
  timeReceived: timestamp('time_received'),
  timeAllocated: timestamp('time_allocated'),
  timeCompleted: timestamp('time_completed'),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow().onUpdateNow(),
}, (table) => ({
  shiftIdx: index('idx_tasks_shift').on(table.shiftId),
  porterIdx: index('idx_tasks_porter').on(table.porterId),
  statusIdx: index('idx_tasks_status').on(table.status),
  taskItemIdx: index('idx_tasks_task_item').on(table.taskItemId),
}));

// ============================================================================
// RELATIONS
// ============================================================================

export const staffRelations = relations(staff, ({ one, many }) => ({
  department: one(departments, {
    fields: [staff.departmentId],
    references: [departments.id],
  }),
  areaCoverPorterAssignments: many(areaCoverPorterAssignments),
  supportServicePorterAssignments: many(supportServicePorterAssignments),
  tasks: many(tasks),
}));

export const buildingsRelations = relations(buildings, ({ many }) => ({
  departments: many(departments),
}));

export const departmentsRelations = relations(departments, ({ one, many }) => ({
  building: one(buildings, {
    fields: [departments.buildingId],
    references: [buildings.id],
  }),
  staff: many(staff),
  areaCoverAssignments: many(areaCoverAssignments),
  tasksAsOrigin: many(tasks, { relationName: 'originDepartment' }),
  tasksAsDestination: many(tasks, { relationName: 'destinationDepartment' }),
}));

export const taskTypesRelations = relations(taskTypes, ({ many }) => ({
  taskItems: many(taskItems),
}));

export const taskItemsRelations = relations(taskItems, ({ one, many }) => ({
  taskType: one(taskTypes, {
    fields: [taskItems.taskTypeId],
    references: [taskTypes.id],
  }),
  tasks: many(tasks),
}));

export const supportServicesRelations = relations(supportServices, ({ many }) => ({
  supportServiceAssignments: many(supportServiceAssignments),
}));

export const shiftsRelations = relations(shifts, ({ many }) => ({
  areaCoverAssignments: many(areaCoverAssignments),
  supportServiceAssignments: many(supportServiceAssignments),
  tasks: many(tasks),
}));

export const areaCoverAssignmentsRelations = relations(areaCoverAssignments, ({ one, many }) => ({
  shift: one(shifts, {
    fields: [areaCoverAssignments.shiftId],
    references: [shifts.id],
  }),
  department: one(departments, {
    fields: [areaCoverAssignments.departmentId],
    references: [departments.id],
  }),
  porterAssignments: many(areaCoverPorterAssignments),
}));

export const supportServiceAssignmentsRelations = relations(supportServiceAssignments, ({ one, many }) => ({
  shift: one(shifts, {
    fields: [supportServiceAssignments.shiftId],
    references: [shifts.id],
  }),
  supportService: one(supportServices, {
    fields: [supportServiceAssignments.serviceId],
    references: [supportServices.id],
  }),
  porterAssignments: many(supportServicePorterAssignments),
}));

export const areaCoverPorterAssignmentsRelations = relations(areaCoverPorterAssignments, ({ one }) => ({
  areaCoverAssignment: one(areaCoverAssignments, {
    fields: [areaCoverPorterAssignments.areaCoverAssignmentId],
    references: [areaCoverAssignments.id],
  }),
  porter: one(staff, {
    fields: [areaCoverPorterAssignments.porterId],
    references: [staff.id],
  }),
}));

export const supportServicePorterAssignmentsRelations = relations(supportServicePorterAssignments, ({ one }) => ({
  supportServiceAssignment: one(supportServiceAssignments, {
    fields: [supportServicePorterAssignments.supportServiceAssignmentId],
    references: [supportServiceAssignments.id],
  }),
  porter: one(staff, {
    fields: [supportServicePorterAssignments.porterId],
    references: [staff.id],
  }),
}));

export const tasksRelations = relations(tasks, ({ one }) => ({
  shift: one(shifts, {
    fields: [tasks.shiftId],
    references: [shifts.id],
  }),
  taskItem: one(taskItems, {
    fields: [tasks.taskItemId],
    references: [taskItems.id],
  }),
  porter: one(staff, {
    fields: [tasks.porterId],
    references: [staff.id],
  }),
  originDepartment: one(departments, {
    fields: [tasks.originDepartmentId],
    references: [departments.id],
    relationName: 'originDepartment',
  }),
  destinationDepartment: one(departments, {
    fields: [tasks.destinationDepartmentId],
    references: [departments.id],
    relationName: 'destinationDepartment',
  }),
}));
