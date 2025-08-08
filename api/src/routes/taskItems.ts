import { Router, Request, Response } from 'express';
import { prisma } from '../server';

const router = Router();

// GET /api/task-items - Get all task items with optional filtering
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      task_type_id,
      is_regular,
      limit = '100',
      offset = '0' 
    } = req.query;

    const where: any = {};
    
    if (task_type_id) {
      where.task_type_id = task_type_id as string;
    }
    
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

// GET /api/task-items/:id - Get specific task item
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const taskItem = await prisma.taskItem.findUnique({
      where: { id },
      include: {
        task_types: true
      }
    });

    if (!taskItem) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task item not found'
      });
      return;
    }

    res.json(taskItem);
  } catch (error) {
    console.error('Error fetching task item:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch task item'
    });
  }
});

// POST /api/task-items - Create new task item
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      task_type_id,
      name,
      description,
      is_regular = false
    } = req.body;

    // Validate required fields
    if (!task_type_id || !name) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'task_type_id and name are required'
      });
      return;
    }

    // Verify task type exists
    const taskType = await prisma.taskType.findUnique({
      where: { id: task_type_id }
    });

    if (!taskType) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'Task type not found'
      });
      return;
    }

    const taskItem = await prisma.taskItem.create({
      data: {
        task_type_id,
        name,
        description: description || null,
        is_regular
      },
      include: {
        task_types: true
      }
    });

    res.status(201).json(taskItem);
  } catch (error) {
    console.error('Error creating task item:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create task item'
    });
  }
});

// PUT /api/task-items/:id - Update task item
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    // If task_type_id is being updated, verify it exists
    if (updateData.task_type_id) {
      const taskType = await prisma.taskType.findUnique({
        where: { id: updateData.task_type_id }
      });

      if (!taskType) {
        res.status(400).json({
          error: 'Bad Request',
          message: 'Task type not found'
        });
        return;
      }
    }

    const taskItem = await prisma.taskItem.update({
      where: { id },
      data: updateData,
      include: {
        task_types: true
      }
    });

    res.json(taskItem);
  } catch (error: any) {
    console.error('Error updating task item:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task item not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update task item'
    });
  }
});

// DELETE /api/task-items/:id - Delete task item
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.taskItem.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting task item:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task item not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete task item'
    });
  }
});

// GET /api/task-items/:id/assignments - Get department assignments for a task item
router.get('/:id/assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    // Verify task item exists
    const taskItem = await prisma.taskItem.findUnique({
      where: { id }
    });

    if (!taskItem) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task item not found'
      });
      return;
    }

    const assignments = await prisma.task_item_department_assignments.findMany({
      where: { task_item_id: id },
      include: {
        departments: {
          include: {
            buildings: true
          }
        }
      }
    });
    
    res.json(assignments);
  } catch (error) {
    console.error('Error fetching task item assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch task item assignments'
    });
  }
});

// PUT /api/task-items/:id/assignments - Update department assignments for a task item
router.put('/:id/assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { assignments } = req.body;

    // Validate request body
    if (!Array.isArray(assignments)) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'assignments must be an array'
      });
      return;
    }

    // Verify task item exists
    const taskItem = await prisma.taskItem.findUnique({
      where: { id }
    });

    if (!taskItem) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task item not found'
      });
      return;
    }

    // Use transaction to update assignments
    const result = await prisma.$transaction(async (tx) => {
      // Delete existing assignments
      await tx.task_item_department_assignments.deleteMany({
        where: { task_item_id: id }
      });

      // Create new assignments if any
      if (assignments.length > 0) {
        await tx.task_item_department_assignments.createMany({
          data: assignments.map((assignment: any) => ({
            task_item_id: id,
            department_id: assignment.department_id,
            is_origin: assignment.is_origin || false,
            is_destination: assignment.is_destination || false
          }))
        });
      }

      // Return updated assignments
      return await tx.task_item_department_assignments.findMany({
        where: { task_item_id: id },
        include: {
          departments: {
            include: {
              buildings: true
            }
          }
        }
      });
    });

    res.json(result);
  } catch (error) {
    console.error('Error updating task item assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update task item assignments'
    });
  }
});

export default router;
