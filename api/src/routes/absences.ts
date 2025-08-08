import { Router, Request, Response } from 'express';
import { prisma } from '../server';

const router = Router();

// GET /api/absences - Get all porter absences with optional filtering
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      porter_id,
      absence_type,
      start_date,
      end_date,
      limit = '100',
      offset = '0' 
    } = req.query;

    const where: any = {};
    
    if (porter_id) {
      where.porter_id = porter_id as string;
    }
    
    if (absence_type) {
      where.absence_type = absence_type as string;
    }
    
    // Date range filtering
    if (start_date || end_date) {
      where.AND = [];
      
      if (start_date) {
        where.AND.push({
          end_date: {
            gte: new Date(start_date as string)
          }
        });
      }
      
      if (end_date) {
        where.AND.push({
          start_date: {
            lte: new Date(end_date as string)
          }
        });
      }
    }

    const absences = await prisma.porter_absences.findMany({
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
        { start_date: 'desc' },
        { created_at: 'desc' }
      ],
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });
    
    res.json(absences);
  } catch (error) {
    console.error('Error fetching porter absences:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch porter absences'
    });
  }
});

// GET /api/absences/:id - Get specific porter absence
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const absence = await prisma.porter_absences.findUnique({
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

    if (!absence) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Porter absence not found'
      });
      return;
    }

    res.json(absence);
  } catch (error) {
    console.error('Error fetching porter absence:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch porter absence'
    });
  }
});

// POST /api/absences - Create new porter absence
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      porter_id,
      absence_type,
      start_date,
      end_date,
      notes
    } = req.body;

    // Validate required fields
    if (!porter_id || !absence_type || !start_date || !end_date) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'porter_id, absence_type, start_date, and end_date are required'
      });
      return;
    }

    // Verify porter exists
    const porter = await prisma.staff.findUnique({
      where: { id: porter_id }
    });

    if (!porter) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'Porter not found'
      });
      return;
    }

    // Validate date range
    const startDate = new Date(start_date);
    const endDate = new Date(end_date);

    if (startDate > endDate) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'Start date must be before or equal to end date'
      });
      return;
    }

    const absence = await prisma.porter_absences.create({
      data: {
        porter_id,
        absence_type,
        start_date: startDate,
        end_date: endDate,
        notes: notes || null
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

    res.status(201).json(absence);
  } catch (error) {
    console.error('Error creating porter absence:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create porter absence'
    });
  }
});

// PUT /api/absences/:id - Update porter absence
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    // Convert date strings to Date objects if provided
    if (updateData.start_date) {
      updateData.start_date = new Date(updateData.start_date);
    }
    if (updateData.end_date) {
      updateData.end_date = new Date(updateData.end_date);
    }

    // Validate date range if both dates are provided
    if (updateData.start_date && updateData.end_date) {
      if (updateData.start_date > updateData.end_date) {
        res.status(400).json({
          error: 'Bad Request',
          message: 'Start date must be before or equal to end date'
        });
        return;
      }
    }

    // If porter_id is being updated, verify it exists
    if (updateData.porter_id) {
      const porter = await prisma.staff.findUnique({
        where: { id: updateData.porter_id }
      });

      if (!porter) {
        res.status(400).json({
          error: 'Bad Request',
          message: 'Porter not found'
        });
        return;
      }
    }

    const absence = await prisma.porter_absences.update({
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

    res.json(absence);
  } catch (error: any) {
    console.error('Error updating porter absence:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Porter absence not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update porter absence'
    });
  }
});

// DELETE /api/absences/:id - Delete porter absence
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.porter_absences.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting porter absence:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Porter absence not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete porter absence'
    });
  }
});

// GET /api/absences/porter/:porterId - Get absences for a specific porter
router.get('/porter/:porterId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { porterId } = req.params;
    const { 
      start_date,
      end_date,
      limit = '100',
      offset = '0' 
    } = req.query;

    const where: any = { porter_id: porterId };
    
    // Date range filtering
    if (start_date || end_date) {
      where.AND = [];
      
      if (start_date) {
        where.AND.push({
          end_date: {
            gte: new Date(start_date as string)
          }
        });
      }
      
      if (end_date) {
        where.AND.push({
          start_date: {
            lte: new Date(end_date as string)
          }
        });
      }
    }

    const absences = await prisma.porter_absences.findMany({
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
        { start_date: 'desc' },
        { created_at: 'desc' }
      ],
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });
    
    res.json(absences);
  } catch (error) {
    console.error('Error fetching porter absences:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch porter absences'
    });
  }
});

export default router;
