import { Router, Request, Response } from 'express';
import { prisma } from '../server';

const router = Router();

// GET /api/task-types - Get all task types with optional task items
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      include_items = 'false',
      limit = '100',
      offset = '0' 
    } = req.query;

    const includeItems = include_items === 'true';

    const taskTypes = await prisma.taskType.findMany({
      include: includeItems ? {
        task_items: {
          orderBy: { name: 'asc' }
        }
      } : undefined,
      orderBy: { name: 'asc' },
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });
    
    res.json(taskTypes);
  } catch (error) {
    console.error('Error fetching task types:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch task types'
    });
  }
});

// GET /api/task-types/:id - Get specific task type
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { include_items = 'true' } = req.query;

    const includeItems = include_items === 'true';

    const taskType = await prisma.taskType.findUnique({
      where: { id },
      include: includeItems ? {
        task_items: {
          orderBy: { name: 'asc' }
        }
      } : undefined
    });

    if (!taskType) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task type not found'
      });
      return;
    }

    res.json(taskType);
  } catch (error) {
    console.error('Error fetching task type:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch task type'
    });
  }
});

// POST /api/task-types - Create new task type
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      name,
      description
    } = req.body;

    // Validate required fields
    if (!name) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'name is required'
      });
      return;
    }

    const taskType = await prisma.taskType.create({
      data: {
        name,
        description: description || null
      }
    });

    res.status(201).json(taskType);
  } catch (error) {
    console.error('Error creating task type:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create task type'
    });
  }
});

// PUT /api/task-types/:id - Update task type
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    const taskType = await prisma.taskType.update({
      where: { id },
      data: updateData
    });

    res.json(taskType);
  } catch (error: any) {
    console.error('Error updating task type:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task type not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update task type'
    });
  }
});

// DELETE /api/task-types/:id - Delete task type
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.taskType.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting task type:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task type not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete task type'
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

// POST /api/task-types/:id/items - Create new task item for a task type
router.post('/:id/items', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: task_type_id } = req.params;
    const {
      name,
      description,
      is_regular = false
    } = req.body;

    // Validate required fields
    if (!name) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'name is required'
      });
      return;
    }

    // Verify task type exists
    const taskType = await prisma.taskType.findUnique({
      where: { id: task_type_id }
    });

    if (!taskType) {
      res.status(404).json({
        error: 'Not Found',
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

export default router;
