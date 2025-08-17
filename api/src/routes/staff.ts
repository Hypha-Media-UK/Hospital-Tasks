import { Router, Request, Response } from 'express';
import { prisma } from '../server';
import { asyncHandler, ApiError, validateRequired, getPaginationParams, sendSuccess, sendCreated } from '../middleware/errorHandler';

const router = Router();

// GET /api/staff - Get all staff with optional filtering
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      role, 
      department_id,
      porter_type,
      limit = '100',
      offset = '0' 
    } = req.query;

    const where: any = {};
    
    if (role) {
      where.role = role as string;
    }
    
    if (department_id) {
      where.department_id = department_id as string;
    }
    
    if (porter_type) {
      where.porter_type = porter_type as string;
    }

    const staff = await prisma.staff.findMany({
      where,
      include: {
        departments: {
          include: {
            buildings: true
          }
        }
      },
      orderBy: [
        { last_name: 'asc' },
        { first_name: 'asc' }
      ],
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });
    
    // Format time fields properly
    const formattedStaff = staff.map(member => ({
      ...member,
      contracted_hours_start: member.contracted_hours_start 
        ? member.contracted_hours_start.toISOString().substring(11, 16) // Extract HH:MM
        : null,
      contracted_hours_end: member.contracted_hours_end 
        ? member.contracted_hours_end.toISOString().substring(11, 16) // Extract HH:MM
        : null
    }));
    
    res.json(formattedStaff);
  } catch (error) {
    console.error('Error fetching staff:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch staff'
    });
  }
});

// GET /api/staff/:id - Get specific staff member
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const staff = await prisma.staff.findUnique({
      where: { id }
    });

    if (!staff) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Staff member not found'
      });
      return;
    }

    res.json(staff);
  } catch (error) {
    console.error('Error fetching staff member:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch staff member'
    });
  }
});

// POST /api/staff - Create new staff member
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      first_name,
      last_name,
      role,
      department_id,
      porter_type,
      availability_pattern,
      contracted_hours_start,
      contracted_hours_end
    } = req.body;

    // Validate required fields
    if (!first_name || !last_name || !role) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'first_name, last_name, and role are required'
      });
      return;
    }

    // Validate role
    const validRoles = ['supervisor', 'porter'];
    if (!validRoles.includes(role)) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid role. Must be one of: ' + validRoles.join(', ')
      });
      return;
    }

    // Create staff member
    const staff = await prisma.staff.create({
      data: {
        first_name,
        last_name,
        role,
        department_id: department_id || null,
        porter_type: porter_type || 'shift',
        availability_pattern: availability_pattern || null,
        contracted_hours_start: contracted_hours_start || null,
        contracted_hours_end: contracted_hours_end || null
      }
    });

    res.status(201).json(staff);
  } catch (error) {
    console.error('Error creating staff member:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create staff member'
    });
  }
});

// PUT /api/staff/:id - Update staff member
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    const staff = await prisma.staff.update({
      where: { id },
      data: updateData
    });

    res.json(staff);
  } catch (error: any) {
    console.error('Error updating staff member:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Staff member not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update staff member'
    });
  }
});

// DELETE /api/staff/:id - Delete staff member
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.staff.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting staff member:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Staff member not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete staff member'
    });
  }
});

export default router;
