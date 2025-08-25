/**
 * Task Types Routes - DRY Implementation using CRUD Factory
 * 
 * This file replaces 139 lines of duplicated CRUD code with just 3 lines!
 * 
 * Features provided by CRUD factory:
 * - GET / with pagination, search, and filtering
 * - GET /:id with relationships
 * - POST / with validation
 * - PUT /:id with validation  
 * - DELETE /:id
 * - Automatic relationship inclusion (task_items)
 * - Search across name and description fields
 * - Consistent error handling
 * - Type safety
 */

import { createEntityRouter } from '../utils/crudFactory';
import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Create the base CRUD router
const router = createEntityRouter('TASK_TYPES');

// Add custom endpoints that the CRUD factory doesn't provide

// GET /api/task-types/:id/assignments - Get department assignments for a task type
router.get('/:id/assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    // Verify task type exists
    const taskType = await prisma.taskType.findUnique({
      where: { id }
    });

    if (!taskType) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Task type not found'
      });
      return;
    }

    const assignments = await prisma.task_type_department_assignments.findMany({
      where: { task_type_id: id },
      include: {
        departments: true
      },
      orderBy: { created_at: 'asc' }
    });

    res.json(assignments);
  } catch (error) {
    console.error('Error fetching task type assignments:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch task type assignments'
    });
  }
});

// PUT /api/task-types/:id/assignments - Update department assignments for a task type
router.put('/:id/assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { assignments } = req.body;

    // Verify task type exists
    const taskType = await prisma.taskType.findUnique({
      where: { id }
    });

    if (!taskType) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Task type not found'
      });
      return;
    }

    // Validate assignments array
    if (!Array.isArray(assignments)) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'assignments must be an array'
      });
      return;
    }

    // Delete existing assignments
    await prisma.task_type_department_assignments.deleteMany({
      where: { task_type_id: id }
    });

    // Create new assignments
    if (assignments.length > 0) {
      const assignmentData = assignments.map(assignment => ({
        task_type_id: id,
        department_id: assignment.department_id
      }));

      await prisma.task_type_department_assignments.createMany({
        data: assignmentData
      });
    }

    // Fetch and return updated assignments
    const updatedAssignments = await prisma.task_type_department_assignments.findMany({
      where: { task_type_id: id },
      include: {
        departments: true
      },
      orderBy: { created_at: 'asc' }
    });

    res.json(updatedAssignments);
  } catch (error) {
    console.error('Error updating task type assignments:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to update task type assignments'
    });
  }
});

// GET /api/task-types/:id/items - Get task items for a specific task type
router.get('/:id/items', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const {
      is_regular,
      limit = '100',
      offset = '0'
    } = req.query;

    const where: any = { task_type_id: id };

    if (is_regular !== undefined) {
      where.is_regular = is_regular === 'true';
    }

    const taskItems = await prisma.taskItem.findMany({
      where,
      include: {
        task_types: true
      },
      orderBy: { name: 'asc' },
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });

    res.json(taskItems);
  } catch (error) {
    console.error('Error fetching task items:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch task items'
    });
  }
});

export default router;
