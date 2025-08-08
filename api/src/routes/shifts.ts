import { Router, Request, Response } from 'express';
import { prisma } from '../server';

const router = Router();

// GET /api/shifts - Get all shifts with optional filtering
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      is_active,
      shift_type,
      supervisor_id,
      shift_date,
      limit = '100',
      offset = '0' 
    } = req.query;

    const where: any = {};
    
    if (is_active !== undefined) {
      where.is_active = is_active === 'true';
    }
    
    if (shift_type) {
      where.shift_type = shift_type as string;
    }
    
    if (supervisor_id) {
      where.supervisor_id = supervisor_id as string;
    }
    
    if (shift_date) {
      where.shift_date = new Date(shift_date as string);
    }

    const shifts = await prisma.shifts.findMany({
      where,
      include: {
        staff: {
          select: {
            id: true,
            first_name: true,
            last_name: true,
            role: true
          }
        }
      },
      orderBy: [
        { shift_date: 'desc' },
        { start_time: 'desc' }
      ],
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });
    
    res.json(shifts);
  } catch (error) {
    console.error('Error fetching shifts:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch shifts'
    });
  }
});

// GET /api/shifts/:id - Get specific shift
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const shift = await prisma.shifts.findUnique({
      where: { id },
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
    });

    if (!shift) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Shift not found'
      });
      return;
    }

    res.json(shift);
  } catch (error) {
    console.error('Error fetching shift:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch shift'
    });
  }
});

// POST /api/shifts - Create new shift
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      supervisor_id,
      shift_type,
      shift_date,
      start_time,
      end_time,
      is_active = true
    } = req.body;

    // Validate required fields
    if (!supervisor_id || !shift_type || !shift_date) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'supervisor_id, shift_type, and shift_date are required'
      });
      return;
    }

    // Verify supervisor exists
    const supervisor = await prisma.staff.findUnique({
      where: { id: supervisor_id }
    });

    if (!supervisor) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'Supervisor not found'
      });
      return;
    }

    // Parse dates
    const shiftDate = new Date(shift_date);
    const shiftStartTime = start_time ? new Date(start_time) : new Date();
    const shiftEndTime = end_time ? new Date(end_time) : null;

    const shift = await prisma.shifts.create({
      data: {
        supervisor_id,
        shift_type,
        shift_date: shiftDate,
        start_time: shiftStartTime,
        end_time: shiftEndTime,
        is_active
      },
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
    });

    res.status(201).json(shift);
  } catch (error) {
    console.error('Error creating shift:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create shift'
    });
  }
});

// PUT /api/shifts/:id - Update shift
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    // Convert date strings to Date objects if provided
    if (updateData.shift_date) {
      updateData.shift_date = new Date(updateData.shift_date);
    }
    if (updateData.start_time) {
      updateData.start_time = new Date(updateData.start_time);
    }
    if (updateData.end_time) {
      updateData.end_time = new Date(updateData.end_time);
    }

    const shift = await prisma.shifts.update({
      where: { id },
      data: updateData,
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
    });

    res.json(shift);
  } catch (error: any) {
    console.error('Error updating shift:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Shift not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update shift'
    });
  }
});

// DELETE /api/shifts/:id - Delete shift
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.shifts.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting shift:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Shift not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete shift'
    });
  }
});

// PUT /api/shifts/:id/end - End a shift
router.put('/:id/end', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const shift = await prisma.shifts.update({
      where: { id },
      data: {
        end_time: new Date(),
        is_active: false
      },
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
    });

    res.json(shift);
  } catch (error: any) {
    console.error('Error ending shift:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Shift not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to end shift'
    });
  }
});

export default router;
