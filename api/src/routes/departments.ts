import { Router, Request, Response } from 'express';
import { prisma } from '../server';

const router = Router();

// GET /api/departments - Get all departments with optional filtering
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      building_id,
      is_frequent,
      limit = '100',
      offset = '0' 
    } = req.query;

    const where: any = {};
    
    if (building_id) {
      where.building_id = building_id as string;
    }
    
    if (is_frequent !== undefined) {
      where.is_frequent = is_frequent === 'true';
    }

    const departments = await prisma.department.findMany({
      where,
      include: {
        buildings: true
      },
      orderBy: [
        { sort_order: 'asc' },
        { name: 'asc' }
      ],
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });
    
    res.json(departments);
  } catch (error) {
    console.error('Error fetching departments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch departments'
    });
  }
});

// GET /api/departments/:id - Get specific department
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const department = await prisma.department.findUnique({
      where: { id },
      include: {
        buildings: true
      }
    });

    if (!department) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Department not found'
      });
      return;
    }

    res.json(department);
  } catch (error) {
    console.error('Error fetching department:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch department'
    });
  }
});

// POST /api/departments - Create new department
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      building_id,
      name,
      is_frequent = false,
      sort_order = 0,
      color = '#CCCCCC'
    } = req.body;

    // Validate required fields
    if (!building_id || !name) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'building_id and name are required'
      });
      return;
    }

    // Verify building exists
    const building = await prisma.building.findUnique({
      where: { id: building_id }
    });

    if (!building) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'Building not found'
      });
      return;
    }

    const department = await prisma.department.create({
      data: {
        building_id,
        name,
        is_frequent,
        sort_order,
        color
      },
      include: {
        buildings: true
      }
    });

    res.status(201).json(department);
  } catch (error) {
    console.error('Error creating department:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create department'
    });
  }
});

// PUT /api/departments/:id - Update department
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    // If building_id is being updated, verify it exists
    if (updateData.building_id) {
      const building = await prisma.building.findUnique({
        where: { id: updateData.building_id }
      });

      if (!building) {
        res.status(400).json({
          error: 'Bad Request',
          message: 'Building not found'
        });
        return;
      }
    }

    const department = await prisma.department.update({
      where: { id },
      data: updateData,
      include: {
        buildings: true
      }
    });

    res.json(department);
  } catch (error: any) {
    console.error('Error updating department:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Department not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update department'
    });
  }
});

// PUT /api/departments/:id/toggle-frequent - Toggle frequent status
router.put('/:id/toggle-frequent', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    // Get current department
    const currentDept = await prisma.department.findUnique({
      where: { id }
    });

    if (!currentDept) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Department not found'
      });
      return;
    }

    const department = await prisma.department.update({
      where: { id },
      data: { is_frequent: !currentDept.is_frequent },
      include: {
        buildings: true
      }
    });

    res.json(department);
  } catch (error) {
    console.error('Error toggling department frequent status:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to toggle frequent status'
    });
  }
});

// DELETE /api/departments/:id - Delete department
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.department.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting department:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Department not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete department'
    });
  }
});

// GET /api/departments/:id/task-assignments - Get task assignments for a department
router.get('/:id/task-assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const taskAssignments = await prisma.department_task_assignments.findMany({
      where: { department_id: id },
      include: {
        task_types: true,
        task_items: true
      }
    });

    res.json(taskAssignments);
  } catch (error) {
    console.error('Error fetching department task assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch department task assignments'
    });
  }
});

// GET /api/departments/task-assignments - Get all department task assignments
router.get('/task-assignments/all', async (req: Request, res: Response): Promise<void> => {
  try {
    const taskAssignments = await prisma.department_task_assignments.findMany({
      include: {
        departments: true,
        task_types: true,
        task_items: true
      },
      orderBy: [
        { departments: { name: 'asc' } }
      ]
    });

    res.json(taskAssignments);
  } catch (error) {
    console.error('Error fetching all department task assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch department task assignments'
    });
  }
});

// POST /api/departments/:id/task-assignments - Create task assignment for a department
router.post('/:id/task-assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: department_id } = req.params;
    const { task_type_id, task_item_id } = req.body;

    if (!task_type_id || !task_item_id) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'task_type_id and task_item_id are required'
      });
      return;
    }

    // Verify department exists
    const department = await prisma.department.findUnique({
      where: { id: department_id }
    });

    if (!department) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Department not found'
      });
      return;
    }

    // Verify task type and item exist
    const taskType = await prisma.taskType.findUnique({
      where: { id: task_type_id }
    });

    const taskItem = await prisma.taskItem.findUnique({
      where: { id: task_item_id }
    });

    if (!taskType || !taskItem) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'Task type or task item not found'
      });
      return;
    }

    const taskAssignment = await prisma.department_task_assignments.create({
      data: {
        department_id,
        task_type_id,
        task_item_id
      },
      include: {
        departments: true,
        task_types: true,
        task_items: true
      }
    });

    res.status(201).json(taskAssignment);
  } catch (error) {
    console.error('Error creating department task assignment:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create department task assignment'
    });
  }
});

// PUT /api/departments/task-assignments/:id - Update department task assignment
router.put('/task-assignments/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { task_type_id, task_item_id } = req.body;

    const updateData: any = {};
    if (task_type_id) updateData.task_type_id = task_type_id;
    if (task_item_id) updateData.task_item_id = task_item_id;

    const taskAssignment = await prisma.department_task_assignments.update({
      where: { id },
      data: updateData,
      include: {
        departments: true,
        task_types: true,
        task_items: true
      }
    });

    res.json(taskAssignment);
  } catch (error: any) {
    console.error('Error updating department task assignment:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Department task assignment not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update department task assignment'
    });
  }
});

// DELETE /api/departments/task-assignments/:id - Delete department task assignment
router.delete('/task-assignments/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.department_task_assignments.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting department task assignment:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Department task assignment not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete department task assignment'
    });
  }
});

export default router;
