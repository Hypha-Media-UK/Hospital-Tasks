import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { eq, and, or, like, count, desc, asc } from 'drizzle-orm';
import { MySqlTable } from 'drizzle-orm/mysql-core';
import { z } from 'zod';
import { db } from '@hospital-tasks/database';
import { PaginationParams, SearchParams, PaginatedResponse } from '@hospital-tasks/shared';

// ============================================================================
// CRUD FACTORY TYPES
// ============================================================================

export interface CRUDConfig<
  TTable extends MySqlTable,
  TInsert extends Record<string, any>,
  TUpdate extends Record<string, any>,
  TSelect extends Record<string, any>
> {
  table: TTable;
  entityName: string;
  insertSchema: z.ZodSchema<TInsert>;
  updateSchema: z.ZodSchema<TUpdate>;
  selectSchema: z.ZodSchema<TSelect>;
  searchFields?: (keyof TSelect)[];
  defaultOrderBy?: { field: keyof TSelect; direction: 'asc' | 'desc' };
  relations?: Record<string, any>;
  maxLimit?: number;
}

// ============================================================================
// GENERIC CRUD FACTORY
// ============================================================================

export function createCRUDRoutes<
  TTable extends MySqlTable,
  TInsert extends Record<string, any>,
  TUpdate extends Record<string, any>,
  TSelect extends Record<string, any>
>(config: CRUDConfig<TTable, TInsert, TUpdate, TSelect>) {
  const app = new Hono();

  // GET / - List all entities with pagination and search
  app.get(
    '/',
    zValidator('query', PaginationParams.merge(SearchParams)),
    async (c) => {
      const { limit, offset, search } = c.req.valid('query');
      const maxLimit = config.maxLimit || 1000;
      const actualLimit = Math.min(limit, maxLimit);

      try {
        // Build where conditions
        const whereConditions = [];
        
        if (search && config.searchFields) {
          const searchConditions = config.searchFields.map(field => 
            like(config.table[field as string], `%${search}%`)
          );
          whereConditions.push(or(...searchConditions));
        }

        const whereClause = whereConditions.length > 0 ? and(...whereConditions) : undefined;

        // Build order by
        const orderBy = config.defaultOrderBy 
          ? config.defaultOrderBy.direction === 'desc'
            ? desc(config.table[config.defaultOrderBy.field as string])
            : asc(config.table[config.defaultOrderBy.field as string])
          : desc(config.table.createdAt);

        // Execute queries
        const [data, totalResult] = await Promise.all([
          db
            .select()
            .from(config.table)
            .where(whereClause)
            .orderBy(orderBy)
            .limit(actualLimit)
            .offset(offset),
          db
            .select({ count: count() })
            .from(config.table)
            .where(whereClause)
        ]);

        const total = totalResult[0]?.count || 0;

        return c.json({
          data,
          pagination: {
            total,
            limit: actualLimit,
            offset,
            hasMore: offset + actualLimit < total,
          },
        });
      } catch (error) {
        console.error(`Error fetching ${config.entityName}:`, error);
        return c.json(
          { error: 'Internal Server Error', message: `Failed to fetch ${config.entityName}` },
          500
        );
      }
    }
  );

  // GET /:id - Get single entity
  app.get('/:id', async (c) => {
    const id = c.req.param('id');

    try {
      const result = await db
        .select()
        .from(config.table)
        .where(eq(config.table.id, id))
        .limit(1);

      if (result.length === 0) {
        return c.json(
          { error: 'Not Found', message: `${config.entityName} not found` },
          404
        );
      }

      return c.json(result[0]);
    } catch (error) {
      console.error(`Error fetching ${config.entityName}:`, error);
      return c.json(
        { error: 'Internal Server Error', message: `Failed to fetch ${config.entityName}` },
        500
      );
    }
  });

  // POST / - Create new entity
  app.post(
    '/',
    zValidator('json', config.insertSchema),
    async (c) => {
      const data = c.req.valid('json');

      try {
        const result = await db
          .insert(config.table)
          .values(data);

        // Fetch the created entity
        const created = await db
          .select()
          .from(config.table)
          .where(eq(config.table.id, result.insertId))
          .limit(1);

        return c.json(created[0], 201);
      } catch (error) {
        console.error(`Error creating ${config.entityName}:`, error);
        
        // Handle unique constraint violations
        if (error instanceof Error && error.message.includes('Duplicate entry')) {
          return c.json(
            { error: 'Conflict', message: `${config.entityName} already exists` },
            409
          );
        }

        return c.json(
          { error: 'Internal Server Error', message: `Failed to create ${config.entityName}` },
          500
        );
      }
    }
  );

  // PUT /:id - Update entity
  app.put(
    '/:id',
    zValidator('json', config.updateSchema),
    async (c) => {
      const id = c.req.param('id');
      const data = c.req.valid('json');

      try {
        // Check if entity exists
        const existing = await db
          .select()
          .from(config.table)
          .where(eq(config.table.id, id))
          .limit(1);

        if (existing.length === 0) {
          return c.json(
            { error: 'Not Found', message: `${config.entityName} not found` },
            404
          );
        }

        // Update entity
        await db
          .update(config.table)
          .set(data)
          .where(eq(config.table.id, id));

        // Fetch updated entity
        const updated = await db
          .select()
          .from(config.table)
          .where(eq(config.table.id, id))
          .limit(1);

        return c.json(updated[0]);
      } catch (error) {
        console.error(`Error updating ${config.entityName}:`, error);
        return c.json(
          { error: 'Internal Server Error', message: `Failed to update ${config.entityName}` },
          500
        );
      }
    }
  );

  // DELETE /:id - Delete entity
  app.delete('/:id', async (c) => {
    const id = c.req.param('id');

    try {
      // Check if entity exists
      const existing = await db
        .select()
        .from(config.table)
        .where(eq(config.table.id, id))
        .limit(1);

      if (existing.length === 0) {
        return c.json(
          { error: 'Not Found', message: `${config.entityName} not found` },
          404
        );
      }

      // Delete entity
      await db
        .delete(config.table)
        .where(eq(config.table.id, id));

      return c.body(null, 204);
    } catch (error) {
      console.error(`Error deleting ${config.entityName}:`, error);
      return c.json(
        { error: 'Internal Server Error', message: `Failed to delete ${config.entityName}` },
        500
      );
    }
  });

  return app;
}
