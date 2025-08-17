import { Router, Request, Response } from 'express';
import { prisma } from '../server';
import { formatObjectTimeFields, formatTimeForDB } from '../middleware/errorHandler';

const router = Router();

// GET /api/support-services - Get all support services
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      is_active,
      limit = '100',
      offset = '0' 
    } = req.query;

    const where: any = {};
    
    if (is_active !== undefined) {
      where.is_active = is_active === 'true';
    }

    const supportServices = await prisma.supportService.findMany({
      where,
      orderBy: { name: 'asc' },
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });
    
    res.json(supportServices);
  } catch (error) {
    console.error('Error fetching support services:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch support services'
    });
  }
});

// GET /api/support-services/default-assignments - Get all default service cover assignments
router.get('/default-assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { shift_type } = req.query;

    const where: any = {};
    
    if (shift_type) {
      where.shift_type = shift_type as string;
    }

    const assignments = await prisma.default_service_cover_assignments.findMany({
      where,
      include: {
        support_services: true,
        default_service_cover_porter_assignments: {
          include: {
            staff: true
          }
        }
      },
      orderBy: [
        { shift_type: 'asc' },
        { support_services: { name: 'asc' } }
      ]
    });
    
    // Format time fields properly
    const formattedAssignments = assignments.map(assignment => ({
      ...assignment,
      start_time: assignment.start_time 
        ? assignment.start_time.toISOString().substring(11, 16) 
        : null,
      end_time: assignment.end_time 
        ? assignment.end_time.toISOString().substring(11, 16) 
        : null,
      default_service_cover_porter_assignments: assignment.default_service_cover_porter_assignments.map(porterAssignment => ({
        ...porterAssignment,
        start_time: porterAssignment.start_time 
          ? porterAssignment.start_time.toISOString().substring(11, 16) 
          : null,
        end_time: porterAssignment.end_time 
          ? porterAssignment.end_time.toISOString().substring(11, 16) 
          : null
      }))
    }));
    
    res.json(formattedAssignments);
  } catch (error) {
    console.error('Error fetching default service cover assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch default service cover assignments'
    });
  }
});

// GET /api/support-services/:id - Get specific support service
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const supportService = await prisma.supportService.findUnique({
      where: { id }
    });

    if (!supportService) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Support service not found'
      });
      return;
    }

    res.json(supportService);
  } catch (error) {
    console.error('Error fetching support service:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch support service'
    });
  }
});

// POST /api/support-services - Create new support service
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      name,
      description,
      is_active = true
    } = req.body;

    // Validate required fields
    if (!name) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'name is required'
      });
      return;
    }

    const supportService = await prisma.supportService.create({
      data: {
        name,
        description: description || null,
        is_active
      }
    });

    res.status(201).json(supportService);
  } catch (error) {
    console.error('Error creating support service:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create support service'
    });
  }
});

// PUT /api/support-services/:id - Update support service
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    const supportService = await prisma.supportService.update({
      where: { id },
      data: updateData
    });

    res.json(supportService);
  } catch (error: any) {
    console.error('Error updating support service:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Support service not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update support service'
    });
  }
});

// PUT /api/support-services/:id/toggle-active - Toggle active status
router.put('/:id/toggle-active', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    // Get current support service
    const currentService = await prisma.supportService.findUnique({
      where: { id }
    });

    if (!currentService) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Support service not found'
      });
      return;
    }

    const supportService = await prisma.supportService.update({
      where: { id },
      data: { is_active: !currentService.is_active }
    });

    res.json(supportService);
  } catch (error) {
    console.error('Error toggling support service active status:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to toggle active status'
    });
  }
});

// DELETE /api/support-services/:id - Delete support service
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.supportService.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting support service:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Support service not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete support service'
    });
  }
});

// GET /api/support-services/:id/assignments - Get service assignments
router.get('/:id/assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: service_id } = req.params;
    const { shift_type } = req.query;

    const where: any = { service_id };
    
    if (shift_type) {
      where.shift_type = shift_type as string;
    }

    const assignments = await prisma.support_service_assignments.findMany({
      where,
      include: {
        support_services: true,
        support_service_porter_assignments: {
          include: {
            staff: true
          }
        }
      },
      orderBy: { shift_type: 'asc' }
    });
    
    res.json(assignments);
  } catch (error) {
    console.error('Error fetching service assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch service assignments'
    });
  }
});

// POST /api/support-services/:id/assignments - Create service assignment
router.post('/:id/assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: service_id } = req.params;
    const {
      shift_type,
      start_time = '08:00:00',
      end_time = '16:00:00',
      color = '#4285F4'
    } = req.body;

    // Validate required fields
    if (!shift_type) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'shift_type is required'
      });
      return;
    }

    // Verify support service exists
    const supportService = await prisma.supportService.findUnique({
      where: { id: service_id }
    });

    if (!supportService) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Support service not found'
      });
      return;
    }

    const assignment = await prisma.support_service_assignments.create({
      data: {
        service_id,
        shift_type,
        start_time: formatTimeForDB(start_time),
        end_time: formatTimeForDB(end_time),
        color
      },
      include: {
        support_services: true
      }
    });

    const formattedAssignment = formatObjectTimeFields(assignment, ['start_time', 'end_time']);
    res.status(201).json(formattedAssignment);
  } catch (error) {
    console.error('Error creating service assignment:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create service assignment'
    });
  }
});

// POST /api/support-services/default-assignments - Create default service cover assignment
router.post('/default-assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      service_id,
      shift_type,
      start_time = '08:00:00',
      end_time = '16:00:00',
      color = '#4285F4',
      minimum_porters = 1,
      minimum_porters_mon = 1,
      minimum_porters_tue = 1,
      minimum_porters_wed = 1,
      minimum_porters_thu = 1,
      minimum_porters_fri = 1,
      minimum_porters_sat = 1,
      minimum_porters_sun = 1
    } = req.body;

    // Validate required fields
    if (!service_id || !shift_type) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'service_id and shift_type are required'
      });
      return;
    }



    // Verify support service exists
    const supportService = await prisma.supportService.findUnique({
      where: { id: service_id }
    });

    if (!supportService) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Support service not found'
      });
      return;
    }

    const assignment = await prisma.default_service_cover_assignments.create({
      data: {
        service_id,
        shift_type,
        start_time: formatTimeForDB(start_time),
        end_time: formatTimeForDB(end_time),
        color,
        minimum_porters,
        minimum_porters_mon,
        minimum_porters_tue,
        minimum_porters_wed,
        minimum_porters_thu,
        minimum_porters_fri,
        minimum_porters_sat,
        minimum_porters_sun
      },
      include: {
        support_services: true,
        default_service_cover_porter_assignments: {
          include: {
            staff: true
          }
        }
      }
    });

    const formattedAssignment = formatObjectTimeFields(assignment, ['start_time', 'end_time']);
    res.status(201).json(formattedAssignment);
  } catch (error: any) {
    console.error('Error creating default service cover assignment:', error);
    
    if (error.code === 'P2002') {
      res.status(409).json({
        error: 'Conflict',
        message: 'Default assignment for this service and shift type already exists'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create default service cover assignment'
    });
  }
});

// PUT /api/support-services/default-assignments/:id - Update default service cover assignment
router.put('/default-assignments/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;



    // Convert time strings to Date objects if provided
    if (updateData.start_time) {
      updateData.start_time = formatTimeForDB(updateData.start_time);
    }
    if (updateData.end_time) {
      updateData.end_time = formatTimeForDB(updateData.end_time);
    }

    const assignment = await prisma.default_service_cover_assignments.update({
      where: { id },
      data: updateData,
      include: {
        support_services: true,
        default_service_cover_porter_assignments: {
          include: {
            staff: true
          }
        }
      }
    });

    const formattedAssignment = formatObjectTimeFields(assignment, ['start_time', 'end_time']);
    res.json(formattedAssignment);
  } catch (error: any) {
    console.error('Error updating default service cover assignment:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Default service cover assignment not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update default service cover assignment'
    });
  }
});

// DELETE /api/support-services/default-assignments/:id - Delete default service cover assignment
router.delete('/default-assignments/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.default_service_cover_assignments.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting default service cover assignment:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Default service cover assignment not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete default service cover assignment'
    });
  }
});

export default router;
