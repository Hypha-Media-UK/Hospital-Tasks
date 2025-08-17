import { Router, Request, Response } from 'express';
import { prisma } from '../server';
import { formatObjectTimeFields, formatTimeForDB } from '../middleware/errorHandler';

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
    
    // Transform the response to include supervisor alias
    const transformedShifts = shifts.map(shift => ({
      ...shift,
      supervisor: shift.staff
    }));
    
    res.json(transformedShifts);
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

    // Transform the response to include supervisor alias
    const transformedShift = {
      ...shift,
      supervisor: shift.staff
    };

    res.json(transformedShift);
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

    // Transform the response to include supervisor alias
    const transformedShift = {
      ...shift,
      supervisor: shift.staff
    };

    res.status(201).json(transformedShift);
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

    // Transform the response to include supervisor alias
    const transformedShift = {
      ...shift,
      supervisor: shift.staff
    };

    res.json(transformedShift);
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

    // Transform the response to include supervisor alias
    const transformedShift = {
      ...shift,
      supervisor: shift.staff
    };

    res.json(transformedShift);
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

// GET /api/shifts/:id/area-cover - Get area cover assignments for a specific shift
router.get('/:id/area-cover', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const assignments = await prisma.shift_area_cover_assignments.findMany({
      where: { shift_id: id },
      include: {
        departments: {
          include: {
            buildings: true
          }
        },
        shift_area_cover_porter_assignments: {
          include: {
            staff: true
          }
        }
      },
      orderBy: { departments: { name: 'asc' } }
    });

    // Transform the data to match expected format
    const transformedAssignments = assignments.map(assignment => ({
      id: assignment.id,
      shift_id: assignment.shift_id,
      department_id: assignment.department_id,
      start_time: assignment.start_time 
        ? assignment.start_time.toISOString().substring(11, 16) 
        : null,
      end_time: assignment.end_time 
        ? assignment.end_time.toISOString().substring(11, 16) 
        : null,
      color: assignment.color,
      minimum_porters: assignment.minimum_porters,
      created_at: assignment.created_at,
      updated_at: assignment.updated_at,
      department: {
        id: assignment.departments.id,
        name: assignment.departments.name,
        building_id: assignment.departments.building_id,
        color: assignment.departments.color,
        building: {
          id: assignment.departments.buildings.id,
          name: assignment.departments.buildings.name
        }
      },
      porter_assignments: assignment.shift_area_cover_porter_assignments.map(pa => ({
        id: pa.id,
        shift_area_cover_assignment_id: pa.shift_area_cover_assignment_id,
        porter_id: pa.porter_id,
        start_time: pa.start_time 
          ? pa.start_time.toISOString().substring(11, 16) 
          : null,
        end_time: pa.end_time 
          ? pa.end_time.toISOString().substring(11, 16) 
          : null,
        porter: {
          id: pa.staff.id,
          first_name: pa.staff.first_name,
          last_name: pa.staff.last_name,
          role: pa.staff.role
        }
      }))
    }));

    res.json(transformedAssignments);
  } catch (error) {
    console.error('Error fetching shift area cover assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch shift area cover assignments'
    });
  }
});

// POST /api/shifts/:id/area-cover/initialize - Copy default area cover assignments to this shift
router.post('/:id/area-cover/initialize', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: shiftId } = req.params;

    // Get the shift to determine its type
    const shift = await prisma.shifts.findUnique({
      where: { id: shiftId }
    });

    if (!shift) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Shift not found'
      });
      return;
    }

    // Get default area cover assignments for this shift type
    const defaultAssignments = await prisma.default_area_cover_assignments.findMany({
      where: { shift_type: shift.shift_type },
      include: {
        default_area_cover_porter_assignments: {
          include: {
            staff: true
          }
        }
      }
    });

    if (defaultAssignments.length === 0) {
      res.json({ message: 'No default assignments found for this shift type', assignments: [] });
      return;
    }

    // Copy default assignments to shift-specific assignments
    const createdAssignments = [];
    
    for (const defaultAssignment of defaultAssignments) {
      // Create shift area cover assignment
      const shiftAssignment = await prisma.shift_area_cover_assignments.create({
        data: {
          shift_id: shiftId,
          department_id: defaultAssignment.department_id,
          start_time: defaultAssignment.start_time,
          end_time: defaultAssignment.end_time,
          color: defaultAssignment.color,
          minimum_porters: defaultAssignment.minimum_porters,
          minimum_porters_mon: defaultAssignment.minimum_porters_mon,
          minimum_porters_tue: defaultAssignment.minimum_porters_tue,
          minimum_porters_wed: defaultAssignment.minimum_porters_wed,
          minimum_porters_thu: defaultAssignment.minimum_porters_thu,
          minimum_porters_fri: defaultAssignment.minimum_porters_fri,
          minimum_porters_sat: defaultAssignment.minimum_porters_sat,
          minimum_porters_sun: defaultAssignment.minimum_porters_sun
        },
        include: {
          departments: {
            include: {
              buildings: true
            }
          }
        }
      });

      // Copy porter assignments if they exist
      for (const defaultPorterAssignment of defaultAssignment.default_area_cover_porter_assignments) {
        await prisma.shift_area_cover_porter_assignments.create({
          data: {
            shift_area_cover_assignment_id: shiftAssignment.id,
            porter_id: defaultPorterAssignment.porter_id,
            start_time: defaultPorterAssignment.start_time,
            end_time: defaultPorterAssignment.end_time
          }
        });
      }

      createdAssignments.push(shiftAssignment);
    }

    res.status(201).json({ 
      message: `Initialized ${createdAssignments.length} area cover assignments for shift`,
      assignments: createdAssignments
    });
  } catch (error) {
    console.error('Error initializing shift area cover assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to initialize shift area cover assignments'
    });
  }
});

// GET /api/shifts/:id/support-services - Get support service assignments for a specific shift
router.get('/:id/support-services', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const assignments = await prisma.shift_support_service_assignments.findMany({
      where: { shift_id: id },
      include: {
        support_services: true,
        shift_support_service_porter_assignments: {
          include: {
            staff: true
          }
        }
      },
      orderBy: { support_services: { name: 'asc' } }
    });

    // Transform the data to match expected format
    const transformedAssignments = assignments.map(assignment => ({
      id: assignment.id,
      shift_id: assignment.shift_id,
      service_id: assignment.service_id,
      start_time: assignment.start_time 
        ? assignment.start_time.toISOString().substring(11, 16) 
        : null,
      end_time: assignment.end_time 
        ? assignment.end_time.toISOString().substring(11, 16) 
        : null,
      color: assignment.color,
      minimum_porters: assignment.minimum_porters,
      created_at: assignment.created_at,
      updated_at: assignment.updated_at,
      service: {
        id: assignment.support_services.id,
        name: assignment.support_services.name,
        description: assignment.support_services.description,
        is_active: assignment.support_services.is_active
      },
      porter_assignments: assignment.shift_support_service_porter_assignments.map(pa => ({
        id: pa.id,
        shift_support_service_assignment_id: pa.shift_support_service_assignment_id,
        porter_id: pa.porter_id,
        start_time: pa.start_time 
          ? pa.start_time.toISOString().substring(11, 16) 
          : null,
        end_time: pa.end_time 
          ? pa.end_time.toISOString().substring(11, 16) 
          : null,
        porter: {
          id: pa.staff.id,
          first_name: pa.staff.first_name,
          last_name: pa.staff.last_name,
          role: pa.staff.role
        }
      }))
    }));

    res.json(transformedAssignments);
  } catch (error) {
    console.error('Error fetching shift support service assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch shift support service assignments'
    });
  }
});

// POST /api/shifts/:id/support-services/initialize - Copy default support service assignments to this shift
router.post('/:id/support-services/initialize', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: shiftId } = req.params;

    // Get the shift to determine its type
    const shift = await prisma.shifts.findUnique({
      where: { id: shiftId }
    });

    if (!shift) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Shift not found'
      });
      return;
    }

    // Get default support service assignments for this shift type
    const defaultAssignments = await prisma.default_service_cover_assignments.findMany({
      where: { shift_type: shift.shift_type },
      include: {
        default_service_cover_porter_assignments: {
          include: {
            staff: true
          }
        }
      }
    });

    if (defaultAssignments.length === 0) {
      res.json({ message: 'No default support service assignments found for this shift type', assignments: [] });
      return;
    }

    // Copy default assignments to shift-specific assignments
    const createdAssignments = [];
    
    for (const defaultAssignment of defaultAssignments) {
      // Create shift support service assignment
      const shiftAssignment = await prisma.shift_support_service_assignments.create({
        data: {
          shift_id: shiftId,
          service_id: defaultAssignment.service_id,
          start_time: defaultAssignment.start_time,
          end_time: defaultAssignment.end_time,
          color: defaultAssignment.color,
          minimum_porters: defaultAssignment.minimum_porters,
          minimum_porters_mon: defaultAssignment.minimum_porters_mon,
          minimum_porters_tue: defaultAssignment.minimum_porters_tue,
          minimum_porters_wed: defaultAssignment.minimum_porters_wed,
          minimum_porters_thu: defaultAssignment.minimum_porters_thu,
          minimum_porters_fri: defaultAssignment.minimum_porters_fri,
          minimum_porters_sat: defaultAssignment.minimum_porters_sat,
          minimum_porters_sun: defaultAssignment.minimum_porters_sun
        },
        include: {
          support_services: true
        }
      });

      // Copy porter assignments if they exist
      for (const defaultPorterAssignment of defaultAssignment.default_service_cover_porter_assignments) {
        await prisma.shift_support_service_porter_assignments.create({
          data: {
            shift_support_service_assignment_id: shiftAssignment.id,
            porter_id: defaultPorterAssignment.porter_id,
            start_time: defaultPorterAssignment.start_time,
            end_time: defaultPorterAssignment.end_time
          }
        });
      }

      createdAssignments.push(shiftAssignment);
    }

    res.status(201).json({ 
      message: `Initialized ${createdAssignments.length} support service assignments for shift`,
      assignments: createdAssignments
    });
  } catch (error) {
    console.error('Error initializing shift support service assignments:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to initialize shift support service assignments'
    });
  }
});

// GET /api/shifts/:id/porter-pool - Get porters assigned to this shift
router.get('/:id/porter-pool', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const porterPool = await prisma.shift_porter_pool.findMany({
      where: { shift_id: id },
      include: {
        staff: true
      },
      orderBy: { staff: { last_name: 'asc' } }
    });

    // Transform the data to match expected format
    const transformedPorters = porterPool.map(entry => ({
      id: entry.id,
      shift_id: entry.shift_id,
      porter_id: entry.porter_id,
      created_at: entry.created_at,
      porter: {
        id: entry.staff.id,
        first_name: entry.staff.first_name,
        last_name: entry.staff.last_name,
        role: entry.staff.role,
        porter_type: entry.staff.porter_type,
        contracted_hours_start: entry.staff.contracted_hours_start,
        contracted_hours_end: entry.staff.contracted_hours_end
      }
    }));

    res.json(transformedPorters);
  } catch (error) {
    console.error('Error fetching shift porter pool:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch shift porter pool'
    });
  }
});

// POST /api/shifts/:id/porter-pool - Add porter to shift pool
router.post('/:id/porter-pool', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: shiftId } = req.params;
    const { porter_id } = req.body;

    if (!porter_id) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'porter_id is required'
      });
      return;
    }

    // Check if porter is already in the pool
    const existingEntry = await prisma.shift_porter_pool.findFirst({
      where: {
        shift_id: shiftId,
        porter_id: porter_id
      }
    });

    if (existingEntry) {
      res.status(409).json({
        error: 'Conflict',
        message: 'Porter is already in the shift pool'
      });
      return;
    }

    const poolEntry = await prisma.shift_porter_pool.create({
      data: {
        shift_id: shiftId,
        porter_id: porter_id
      },
      include: {
        staff: true
      }
    });

    // Transform the response
    const transformedEntry = {
      id: poolEntry.id,
      shift_id: poolEntry.shift_id,
      porter_id: poolEntry.porter_id,
      created_at: poolEntry.created_at,
      porter: {
        id: poolEntry.staff.id,
        first_name: poolEntry.staff.first_name,
        last_name: poolEntry.staff.last_name,
        role: poolEntry.staff.role,
        porter_type: poolEntry.staff.porter_type,
        contracted_hours_start: poolEntry.staff.contracted_hours_start,
        contracted_hours_end: poolEntry.staff.contracted_hours_end
      }
    };

    res.status(201).json(transformedEntry);
  } catch (error) {
    console.error('Error adding porter to shift pool:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to add porter to shift pool'
    });
  }
});

// DELETE /api/shifts/:id/porter-pool/:porterId - Remove porter from shift pool
router.delete('/:id/porter-pool/:porterId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: shiftId, porterId } = req.params;

    await prisma.shift_porter_pool.deleteMany({
      where: {
        shift_id: shiftId,
        porter_id: porterId
      }
    });

    res.status(204).send();
  } catch (error) {
    console.error('Error removing porter from shift pool:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to remove porter from shift pool'
    });
  }
});

// POST /api/shifts/:id/area-cover/:areaCoverId/porter-assignments - Add porter to area cover assignment
router.post('/:id/area-cover/:areaCoverId/porter-assignments', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: shiftId, areaCoverId } = req.params;
    const { porter_id, start_time, end_time } = req.body;

    if (!porter_id || !start_time || !end_time) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'porter_id, start_time, and end_time are required'
      });
      return;
    }

    // Verify the area cover assignment exists and belongs to this shift
    const areaCoverAssignment = await prisma.shift_area_cover_assignments.findFirst({
      where: {
        id: areaCoverId,
        shift_id: shiftId
      }
    });

    if (!areaCoverAssignment) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Area cover assignment not found for this shift'
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

    // Parse time strings to create proper datetime objects
    let startDateTime: Date | null = null;
    let endDateTime: Date | null = null;

    if (start_time) {
      // Handle both HH:MM and HH:MM:SS formats
      if (start_time.match(/^\d{2}:\d{2}$/)) {
        startDateTime = new Date(`1970-01-01T${start_time}:00.000Z`);
      } else if (start_time.match(/^\d{2}:\d{2}:\d{2}$/)) {
        startDateTime = new Date(`1970-01-01T${start_time}.000Z`);
      }
    }

    if (end_time) {
      // Handle both HH:MM and HH:MM:SS formats
      if (end_time.match(/^\d{2}:\d{2}$/)) {
        endDateTime = new Date(`1970-01-01T${end_time}:00.000Z`);
      } else if (end_time.match(/^\d{2}:\d{2}:\d{2}$/)) {
        endDateTime = new Date(`1970-01-01T${end_time}.000Z`);
      }
    }

    console.log('Creating porter assignment with times:', {
      start_time,
      end_time,
      startDateTime,
      endDateTime,
      startDateTimeType: typeof startDateTime,
      endDateTimeType: typeof endDateTime
    });

    const porterAssignment = await prisma.shift_area_cover_porter_assignments.create({
      data: {
        shift_area_cover_assignment_id: areaCoverId,
        porter_id: porter_id,
        start_time: startDateTime,
        end_time: endDateTime
      },
      include: {
        staff: true,
        shift_area_cover_assignments: {
          include: {
            departments: {
              include: {
                buildings: true
              }
            }
          }
        }
      }
    });

    // Transform the response to match expected format
    const transformedAssignment = {
      id: porterAssignment.id,
      shift_area_cover_assignment_id: porterAssignment.shift_area_cover_assignment_id,
      porter_id: porterAssignment.porter_id,
      start_time: porterAssignment.start_time 
        ? porterAssignment.start_time.toISOString().substring(11, 16) 
        : null,
      end_time: porterAssignment.end_time 
        ? porterAssignment.end_time.toISOString().substring(11, 16) 
        : null,
      porter: {
        id: porterAssignment.staff.id,
        first_name: porterAssignment.staff.first_name,
        last_name: porterAssignment.staff.last_name,
        role: porterAssignment.staff.role
      },
      shift_area_cover_assignment: {
        id: porterAssignment.shift_area_cover_assignments.id,
        department_id: porterAssignment.shift_area_cover_assignments.department_id,
        start_time: porterAssignment.shift_area_cover_assignments.start_time 
          ? porterAssignment.shift_area_cover_assignments.start_time.toISOString().substring(11, 16) 
          : null,
        end_time: porterAssignment.shift_area_cover_assignments.end_time 
          ? porterAssignment.shift_area_cover_assignments.end_time.toISOString().substring(11, 16) 
          : null,
        color: porterAssignment.shift_area_cover_assignments.color,
        minimum_porters: porterAssignment.shift_area_cover_assignments.minimum_porters,
        department: {
          id: porterAssignment.shift_area_cover_assignments.departments.id,
          name: porterAssignment.shift_area_cover_assignments.departments.name,
          building_id: porterAssignment.shift_area_cover_assignments.departments.building_id,
          color: porterAssignment.shift_area_cover_assignments.departments.color,
          building: {
            id: porterAssignment.shift_area_cover_assignments.departments.buildings.id,
            name: porterAssignment.shift_area_cover_assignments.departments.buildings.name
          }
        }
      }
    };

    res.status(201).json(transformedAssignment);
  } catch (error) {
    console.error('Error adding porter to area cover assignment:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to add porter to area cover assignment'
    });
  }
});

// PUT /api/shifts/:id/area-cover/porter-assignments/:assignmentId - Update porter assignment
router.put('/:id/area-cover/porter-assignments/:assignmentId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: shiftId, assignmentId } = req.params;
    const { porter_id, start_time, end_time } = req.body;

    if (!start_time || !end_time) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'start_time and end_time are required'
      });
      return;
    }

    // Verify the assignment exists and belongs to this shift
    const existingAssignment = await prisma.shift_area_cover_porter_assignments.findFirst({
      where: {
        id: assignmentId,
        shift_area_cover_assignments: {
          shift_id: shiftId
        }
      }
    });

    if (!existingAssignment) {
      res.status(404).json({
        error: 'Not Found',
        message: 'Porter assignment not found for this shift'
      });
      return;
    }

    // Verify porter exists if porter_id is provided
    if (porter_id) {
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
    }

    // Parse time strings to create proper datetime objects
    const updateData: any = {
      start_time: formatTimeForDB(start_time),
      end_time: formatTimeForDB(end_time)
    };

    if (porter_id) {
      updateData.porter_id = porter_id;
    }

    const updatedAssignment = await prisma.shift_area_cover_porter_assignments.update({
      where: { id: assignmentId },
      data: updateData,
      include: {
        staff: true,
        shift_area_cover_assignments: {
          include: {
            departments: {
              include: {
                buildings: true
              }
            }
          }
        }
      }
    });

    res.json(updatedAssignment);
  } catch (error: any) {
    console.error('Error updating porter assignment:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Porter assignment not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update porter assignment'
    });
  }
});

// DELETE /api/shifts/:id/area-cover/porter-assignments/:assignmentId - Remove porter from area cover assignment
router.delete('/:id/area-cover/porter-assignments/:assignmentId', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: shiftId, assignmentId } = req.params;

    await prisma.shift_area_cover_porter_assignments.delete({
      where: { id: assignmentId }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error removing porter from area cover assignment:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Porter assignment not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to remove porter from area cover assignment'
    });
  }
});

export default router;
