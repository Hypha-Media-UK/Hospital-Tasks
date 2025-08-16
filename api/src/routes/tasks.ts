import { Router } from 'express';
import { prisma } from '../server';

const router = Router();

// Get all tasks with optional filtering
router.get('/', async (req, res) => {
  try {
    const {
      shift_id,
      status,
      porter_id,
      task_item_id,
      limit = '50',
      offset = '0'
    } = req.query;

    const where: any = {};
    
    if (shift_id) where.shift_id = shift_id as string;
    if (status) where.status = status as string;
    if (porter_id) where.porter_id = porter_id as string;
    if (task_item_id) where.task_item_id = task_item_id as string;

    const tasks = await prisma.shift_tasks.findMany({
      where,
      include: {
        task_items: {
          include: {
            task_types: true
          }
        },
        staff: {
          select: {
            id: true,
            first_name: true,
            last_name: true,
            role: true
          }
        },
        departments_shift_tasks_origin_department_idTodepartments: {
          include: {
            buildings: true
          }
        },
        departments_shift_tasks_destination_department_idTodepartments: {
          include: {
            buildings: true
          }
        },
        shifts: {
          select: {
            id: true,
            shift_type: true,
            shift_date: true,
            is_active: true
          }
        },
        shift_task_porter_assignments: {
          include: {
            staff: {
              select: {
                id: true,
                first_name: true,
                last_name: true,
                role: true
              }
            }
          }
        }
      },
      orderBy: {
        created_at: 'desc'
      },
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });

    return res.json(tasks);
  } catch (error) {
    console.error('Error fetching tasks:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch tasks'
    });
  }
});

// Get task by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const task = await prisma.shift_tasks.findUnique({
      where: { id },
      include: {
        task_items: {
          include: {
            task_types: true
          }
        },
        staff: {
          select: {
            id: true,
            first_name: true,
            last_name: true,
            role: true
          }
        },
        departments_shift_tasks_origin_department_idTodepartments: {
          include: {
            buildings: true
          }
        },
        departments_shift_tasks_destination_department_idTodepartments: {
          include: {
            buildings: true
          }
        },
        shifts: {
          select: {
            id: true,
            shift_type: true,
            shift_date: true,
            is_active: true
          }
        },
        shift_task_porter_assignments: {
          include: {
            staff: {
              select: {
                id: true,
                first_name: true,
                last_name: true,
                role: true
              }
            }
          }
        }
      }
    });

    if (!task) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Task not found'
      });
    }

    return res.json(task);
  } catch (error) {
    console.error('Error fetching task:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch task'
    });
  }
});

// Create new task
router.post('/', async (req, res) => {
  try {
    const {
      shift_id,
      task_item_id,
      porter_id,
      porter_assignments = [], // Array of porter IDs for multiple porter assignments
      origin_department_id,
      destination_department_id,
      status = 'pending',
      time_received,
      time_allocated,
      time_completed
    } = req.body;

    // Validate required fields
    if (!shift_id) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'shift_id is required'
      });
    }

    if (!task_item_id) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'task_item_id is required'
      });
    }

    // Verify shift exists and is active
    const shift = await prisma.shifts.findUnique({
      where: { id: shift_id },
      select: { id: true, is_active: true }
    });

    if (!shift) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Shift not found'
      });
    }

    if (!shift.is_active) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Cannot add tasks to inactive shift'
      });
    }

    // Verify task item exists
    const taskItem = await prisma.taskItem.findUnique({
      where: { id: task_item_id },
      select: { id: true }
    });

    if (!taskItem) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Task item not found'
      });
    }

    // Verify porter exists if provided
    if (porter_id) {
      const porter = await prisma.staff.findUnique({
        where: { id: porter_id },
        select: { id: true, role: true }
      });

      if (!porter) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Porter not found'
        });
      }

      if (porter.role !== 'porter' && porter.role !== 'supervisor') {
        return res.status(400).json({
          error: 'Bad Request',
          message: 'Assigned staff member must be a porter or supervisor'
        });
      }
    }

    // Verify task item exists if provided
    if (task_item_id) {
      const taskItem = await prisma.taskItem.findUnique({
        where: { id: task_item_id },
        select: { id: true }
      });

      if (!taskItem) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Task item not found'
        });
      }
    }

    // Verify departments exist if provided
    if (origin_department_id) {
      const originDept = await prisma.department.findUnique({
        where: { id: origin_department_id },
        select: { id: true }
      });

      if (!originDept) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Origin department not found'
        });
      }
    }

    if (destination_department_id) {
      const destDept = await prisma.department.findUnique({
        where: { id: destination_department_id },
        select: { id: true }
      });

      if (!destDept) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Destination department not found'
        });
      }
    }

    // Verify porter assignments if provided
    if (porter_assignments && porter_assignments.length > 0) {
      for (const porterId of porter_assignments) {
        if (porterId) { // Skip empty porter assignments
          const porter = await prisma.staff.findUnique({
            where: { id: porterId },
            select: { id: true, role: true }
          });

          if (!porter) {
            return res.status(404).json({
              error: 'Not Found',
              message: `Porter with ID ${porterId} not found`
            });
          }

          if (porter.role !== 'porter' && porter.role !== 'supervisor') {
            return res.status(400).json({
              error: 'Bad Request',
              message: `Staff member ${porterId} must be a porter or supervisor`
            });
          }
        }
      }
    }

    // Create the task
    const taskData: any = {
      shift_id,
      task_item_id,
      status,
      created_at: new Date(),
      updated_at: new Date()
    };

    if (porter_id) taskData.porter_id = porter_id;
    if (origin_department_id) taskData.origin_department_id = origin_department_id;
    if (destination_department_id) taskData.destination_department_id = destination_department_id;
    if (time_received) taskData.time_received = time_received;
    if (time_allocated) taskData.time_allocated = time_allocated;
    if (time_completed) taskData.time_completed = time_completed;

    const newTask = await prisma.shift_tasks.create({
      data: taskData,
      include: {
        task_items: {
          include: {
            task_types: true
          }
        },
        staff: {
          select: {
            id: true,
            first_name: true,
            last_name: true,
            role: true
          }
        },
        departments_shift_tasks_origin_department_idTodepartments: {
          include: {
            buildings: true
          }
        },
        departments_shift_tasks_destination_department_idTodepartments: {
          include: {
            buildings: true
          }
        },
        shifts: {
          select: {
            id: true,
            shift_type: true,
            shift_date: true,
            is_active: true
          }
        }
      }
    });

    // Create porter assignments if provided
    if (porter_assignments && porter_assignments.length > 0) {
      const porterAssignmentPromises = porter_assignments
        .filter((porterId: string) => porterId) // Filter out empty assignments
        .map((porterId: string) => 
          prisma.shift_task_porter_assignments.create({
            data: {
              shift_task_id: newTask.id,
              porter_id: porterId,
              created_at: new Date()
            }
          })
        );

      await Promise.all(porterAssignmentPromises);
    }

    return res.status(201).json(newTask);
  } catch (error) {
    console.error('Error creating task:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to create task'
    });
  }
});

// Update task
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      task_item_id,
      porter_id,
      origin_department_id,
      destination_department_id,
      status,
      time_received,
      time_allocated,
      time_completed
    } = req.body;

    console.log('=== TASK UPDATE DEBUG ===');
    console.log('Task ID:', id);
    console.log('Request body:', req.body);

    // Check if task exists
    const existingTask = await prisma.shift_tasks.findUnique({
      where: { id },
      select: { 
        id: true, 
        shift_id: true,
        origin_department_id: true,
        destination_department_id: true,
        porter_id: true,
        status: true
      }
    });

    if (!existingTask) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Task not found'
      });
    }

    console.log('Existing task before update:', existingTask);

    // Verify shift is still active if updating
    const shift = await prisma.shifts.findUnique({
      where: { id: existingTask.shift_id },
      select: { is_active: true }
    });

    if (!shift?.is_active) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Cannot update tasks for inactive shift'
      });
    }

    // Verify porter exists if provided
    if (porter_id) {
      const porter = await prisma.staff.findUnique({
        where: { id: porter_id },
        select: { id: true, role: true }
      });

      if (!porter) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Porter not found'
        });
      }

      if (porter.role !== 'porter' && porter.role !== 'supervisor') {
        return res.status(400).json({
          error: 'Bad Request',
          message: 'Assigned staff member must be a porter or supervisor'
        });
      }
    }

    // Verify departments exist if provided
    if (origin_department_id) {
      const originDept = await prisma.department.findUnique({
        where: { id: origin_department_id },
        select: { id: true }
      });

      if (!originDept) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Origin department not found'
        });
      }
    }

    if (destination_department_id) {
      const destDept = await prisma.department.findUnique({
        where: { id: destination_department_id },
        select: { id: true }
      });

      if (!destDept) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Destination department not found'
        });
      }
    }

    // Verify task item exists if provided
    if (task_item_id) {
      const taskItem = await prisma.taskItem.findUnique({
        where: { id: task_item_id },
        select: { id: true }
      });

      if (!taskItem) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Task item not found'
        });
      }
    }

    // Build update data
    const updateData: any = {
      updated_at: new Date()
    };

    if (task_item_id !== undefined) updateData.task_item_id = task_item_id;
    if (porter_id !== undefined) updateData.porter_id = porter_id;
    if (origin_department_id !== undefined) updateData.origin_department_id = origin_department_id;
    if (destination_department_id !== undefined) updateData.destination_department_id = destination_department_id;
    if (status !== undefined) updateData.status = status;
    if (time_received !== undefined) updateData.time_received = time_received;
    if (time_allocated !== undefined) updateData.time_allocated = time_allocated;
    if (time_completed !== undefined) updateData.time_completed = time_completed;

    console.log('Update data to be applied:', updateData);

    const updatedTask = await prisma.shift_tasks.update({
      where: { id },
      data: updateData,
      include: {
        task_items: {
          include: {
            task_types: true
          }
        },
        staff: {
          select: {
            id: true,
            first_name: true,
            last_name: true,
            role: true
          }
        },
        departments_shift_tasks_origin_department_idTodepartments: {
          include: {
            buildings: true
          }
        },
        departments_shift_tasks_destination_department_idTodepartments: {
          include: {
            buildings: true
          }
        },
        shifts: {
          select: {
            id: true,
            shift_type: true,
            shift_date: true,
            is_active: true
          }
        }
      }
    });

    console.log('Updated task returned from Prisma:', {
      id: updatedTask.id,
      origin_department_id: updatedTask.origin_department_id,
      destination_department_id: updatedTask.destination_department_id,
      porter_id: updatedTask.porter_id,
      status: updatedTask.status,
      updated_at: updatedTask.updated_at
    });

    // Let's also verify the task was actually updated in the database
    const verifyTask = await prisma.shift_tasks.findUnique({
      where: { id },
      select: {
        id: true,
        origin_department_id: true,
        destination_department_id: true,
        porter_id: true,
        status: true,
        updated_at: true
      }
    });

    console.log('Verification query result:', verifyTask);
    console.log('=== END TASK UPDATE DEBUG ===');

    return res.json(updatedTask);
  } catch (error) {
    console.error('Error updating task:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to update task'
    });
  }
});

// Delete task
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Check if task exists
    const existingTask = await prisma.shift_tasks.findUnique({
      where: { id },
      select: { id: true, shift_id: true }
    });

    if (!existingTask) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Task not found'
      });
    }

    // Verify shift is still active
    const shift = await prisma.shifts.findUnique({
      where: { id: existingTask.shift_id },
      select: { is_active: true }
    });

    if (!shift?.is_active) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Cannot delete tasks from inactive shift'
      });
    }

    await prisma.shift_tasks.delete({
      where: { id }
    });

    return res.status(204).send();
  } catch (error) {
    console.error('Error deleting task:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to delete task'
    });
  }
});

export default router;
