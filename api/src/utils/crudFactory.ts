/**
 * Generic CRUD Factory for API Routes
 * Eliminates duplication across entity routes (staff, buildings, departments, etc.)
 */

import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { asyncHandler, ApiError, validateRequired, sendSuccess, sendCreated } from '../middleware/errorHandler';

const prisma = new PrismaClient();

export interface CRUDConfig {
  // Database model name (e.g., 'staff', 'buildings', 'departments')
  model: string;
  
  // Human-readable entity name for error messages
  entityName: string;
  
  // Required fields for creation
  requiredFields?: string[];
  
  // Optional fields that can be updated
  optionalFields?: string[];
  
  // Prisma include options for relationships
  include?: any;
  
  // Default ordering
  orderBy?: any;
  
  // Custom validation function
  customValidation?: (data: any) => { isValid: boolean; errors: string[] };
  
  // Custom data transformation before save
  transformData?: (data: any) => any;
  
  // Custom response formatting
  formatResponse?: (data: any) => any;
  
  // Pagination settings
  pagination?: {
    defaultLimit: number;
    maxLimit: number;
  };
  
  // Search configuration
  search?: {
    fields: string[]; // Fields to search in
  };
  
  // Soft delete support
  softDelete?: boolean;
}

/**
 * Create a complete CRUD router for an entity
 */
export function createCRUDRouter(config: CRUDConfig): Router {
  const router = Router();
  const model = (prisma as any)[config.model];
  
  if (!model) {
    throw new Error(`Invalid model name: ${config.model}`);
  }

  // GET / - List all entities with pagination, search, and filtering
  router.get('/', asyncHandler(async (req: Request, res: Response) => {
    const {
      limit = config.pagination?.defaultLimit || 100,
      offset = 0,
      search = '',
      ...filters
    } = req.query;

    const parsedLimit = Math.min(
      parseInt(limit as string) || config.pagination?.defaultLimit || 100,
      config.pagination?.maxLimit || 1000
    );
    const parsedOffset = parseInt(offset as string) || 0;

    // Build where clause
    const where: any = {};
    
    // Add search functionality
    if (search && config.search?.fields) {
      where.OR = config.search.fields.map(field => ({
        [field]: {
          contains: search
        }
      }));
    }
    
    // Add filters
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== '') {
        where[key] = value;
      }
    });
    
    // Add soft delete filter
    if (config.softDelete) {
      where.deleted_at = null;
    }

    const [entities, total] = await Promise.all([
      model.findMany({
        where,
        include: config.include,
        orderBy: config.orderBy || { created_at: 'desc' },
        take: parsedLimit,
        skip: parsedOffset
      }),
      model.count({ where })
    ]);

    const formattedEntities = config.formatResponse 
      ? entities.map(config.formatResponse)
      : entities;

    res.json({
      data: formattedEntities,
      pagination: {
        total,
        limit: parsedLimit,
        offset: parsedOffset,
        hasMore: parsedOffset + parsedLimit < total
      }
    });
  }));

  // GET /:id - Get single entity
  router.get('/:id', asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;
    
    const where: any = { id };
    if (config.softDelete) {
      where.deleted_at = null;
    }

    const entity = await model.findFirst({
      where,
      include: config.include
    });

    if (!entity) {
      throw ApiError.notFound(`${config.entityName} not found`);
    }

    const formattedEntity = config.formatResponse 
      ? config.formatResponse(entity)
      : entity;

    res.json(formattedEntity);
  }));

  // POST / - Create new entity
  router.post('/', asyncHandler(async (req: Request, res: Response) => {
    let data = { ...req.body };
    
    // Validate required fields
    if (config.requiredFields) {
      validateRequired(data, config.requiredFields);
    }
    
    // Custom validation
    if (config.customValidation) {
      const validation = config.customValidation(data);
      if (!validation.isValid) {
        throw ApiError.badRequest(validation.errors.join(', '));
      }
    }
    
    // Transform data if needed
    if (config.transformData) {
      data = config.transformData(data);
    }
    
    // Remove id if present
    delete data.id;

    const entity = await model.create({
      data,
      include: config.include
    });

    const formattedEntity = config.formatResponse 
      ? config.formatResponse(entity)
      : entity;

    sendCreated(res, formattedEntity);
  }));

  // PUT /:id - Update entity
  router.put('/:id', asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;
    let updateData = { ...req.body };
    
    // Remove id from update data
    delete updateData.id;
    
    // Custom validation
    if (config.customValidation) {
      const validation = config.customValidation(updateData);
      if (!validation.isValid) {
        throw ApiError.badRequest(validation.errors.join(', '));
      }
    }
    
    // Transform data if needed
    if (config.transformData) {
      updateData = config.transformData(updateData);
    }
    
    // Filter to only allowed fields
    if (config.optionalFields) {
      const allowedFields = [...(config.requiredFields || []), ...config.optionalFields];
      updateData = Object.fromEntries(
        Object.entries(updateData).filter(([key]) => allowedFields.includes(key))
      );
    }

    const entity = await model.update({
      where: { id },
      data: updateData,
      include: config.include
    });

    const formattedEntity = config.formatResponse 
      ? config.formatResponse(entity)
      : entity;

    res.json(formattedEntity);
  }));

  // DELETE /:id - Delete entity
  router.delete('/:id', asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;

    if (config.softDelete) {
      // Soft delete
      await model.update({
        where: { id },
        data: { deleted_at: new Date() }
      });
    } else {
      // Hard delete
      await model.delete({
        where: { id }
      });
    }

    res.status(204).send();
  }));

  return router;
}

/**
 * Pre-configured CRUD configs for common entities
 */
export const CRUD_CONFIGS = {
  STAFF: {
    model: 'staff',
    entityName: 'Staff member',
    requiredFields: ['first_name', 'last_name', 'role'],
    optionalFields: ['email', 'phone', 'availability_pattern', 'contracted_hours_start', 'contracted_hours_end'],
    orderBy: { first_name: 'asc' },
    search: { fields: ['first_name', 'last_name', 'email'] },
    pagination: { defaultLimit: 50, maxLimit: 200 }
  } as CRUDConfig,

  BUILDINGS: {
    model: 'buildings',
    entityName: 'Building',
    requiredFields: ['name'],
    optionalFields: ['description'],
    include: { departments: true },
    orderBy: { name: 'asc' },
    search: { fields: ['name', 'description'] }
  } as CRUDConfig,

  DEPARTMENTS: {
    model: 'departments',
    entityName: 'Department',
    requiredFields: ['name', 'building_id'],
    optionalFields: ['description'],
    include: { buildings: true },
    orderBy: { name: 'asc' },
    search: { fields: ['name', 'description'] }
  } as CRUDConfig,

  TASK_TYPES: {
    model: 'taskType',
    entityName: 'Task type',
    requiredFields: ['name'],
    optionalFields: ['description'],
    include: { task_items: true },
    orderBy: { name: 'asc' },
    search: { fields: ['name', 'description'] }
  } as CRUDConfig,

  SUPPORT_SERVICES: {
    model: 'support_services',
    entityName: 'Support service',
    requiredFields: ['name'],
    optionalFields: ['description'],
    orderBy: { name: 'asc' },
    search: { fields: ['name', 'description'] }
  } as CRUDConfig
};

/**
 * Helper function to create a router with pre-configured settings
 */
export function createEntityRouter(configKey: keyof typeof CRUD_CONFIGS): Router {
  return createCRUDRouter(CRUD_CONFIGS[configKey]);
}
