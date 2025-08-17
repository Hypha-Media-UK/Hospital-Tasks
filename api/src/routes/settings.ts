import { Router, Request, Response } from 'express';
import { prisma } from '../server';

const router = Router();

// Note: General app settings endpoints removed as timezone functionality has been eliminated
// Times are now automatically handled by browser timezone detection

// GET /api/settings/shift-defaults - Get shift defaults
router.get('/shift-defaults', async (req: Request, res: Response): Promise<void> => {
  try {
    const shiftDefaults = await prisma.shift_defaults.findMany({
      orderBy: { shift_type: 'asc' }
    });
    
    res.json(shiftDefaults);
  } catch (error) {
    console.error('Error fetching shift defaults:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch shift defaults'
    });
  }
});

// PUT /api/settings/shift-defaults/:id - Update shift default
router.put('/shift-defaults/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    // Convert time strings to Date objects if provided
    // Use UTC to avoid timezone conversion issues for TIME fields
    if (updateData.start_time && typeof updateData.start_time === 'string') {
      // Ensure the time string is in HH:MM:SS format
      const timeStr = updateData.start_time.includes(':') ? updateData.start_time : `${updateData.start_time}:00`;
      updateData.start_time = new Date(`1970-01-01T${timeStr}Z`);
    }
    if (updateData.end_time && typeof updateData.end_time === 'string') {
      // Ensure the time string is in HH:MM:SS format
      const timeStr = updateData.end_time.includes(':') ? updateData.end_time : `${updateData.end_time}:00`;
      updateData.end_time = new Date(`1970-01-01T${timeStr}Z`);
    }

    const shiftDefault = await prisma.shift_defaults.update({
      where: { id },
      data: updateData
    });

    res.json(shiftDefault);
  } catch (error: any) {
    console.error('Error updating shift default:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Shift default not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update shift default'
    });
  }
});

// POST /api/settings/shift-defaults - Create new shift default
router.post('/shift-defaults', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      shift_type,
      start_time,
      end_time,
      color
    } = req.body;

    // Validate required fields
    if (!shift_type || !start_time || !end_time || !color) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'shift_type, start_time, end_time, and color are required'
      });
      return;
    }

    const shiftDefault = await prisma.shift_defaults.create({
      data: {
        shift_type,
        start_time: new Date(`1970-01-01T${start_time}`),
        end_time: new Date(`1970-01-01T${end_time}`),
        color
      }
    });

    res.status(201).json(shiftDefault);
  } catch (error) {
    console.error('Error creating shift default:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create shift default'
    });
  }
});

// DELETE /api/settings/shift-defaults/:id - Delete shift default
router.delete('/shift-defaults/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.shift_defaults.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting shift default:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Shift default not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete shift default'
    });
  }
});

export default router;
