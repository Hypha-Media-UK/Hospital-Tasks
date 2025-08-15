import { Router } from 'express';
import { PrismaClient } from '@prisma/client';

const router = Router();
const prisma = new PrismaClient();

// GET /api/area-cover/assignments - Get all default area cover assignments
router.get('/assignments', async (req, res) => {
  try {
    const { shift_type } = req.query;
    
    const whereClause = shift_type ? { shift_type: shift_type as string } : {};
    
    const assignments = await prisma.default_area_cover_assignments.findMany({
      where: whereClause,
      include: {
        departments: {
          include: {
            buildings: true
          }
        }
      },
      orderBy: [
        { shift_type: 'asc' },
        { departments: { name: 'asc' } }
      ]
    });

    // Transform the data to match the expected format
    const transformedAssignments = assignments.map(assignment => ({
      id: assignment.id,
      department_id: assignment.department_id,
      shift_type: assignment.shift_type,
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
      }
    }));

    return res.json(transformedAssignments);
  } catch (error) {
    console.error('Error fetching area cover assignments:', error);
    return res.status(500).json({ error: 'Failed to fetch area cover assignments' });
  }
});

// POST /api/area-cover/assignments - Create a new default area cover assignment
router.post('/assignments', async (req, res) => {
  try {
    const {
      department_id,
      shift_type,
      start_time,
      end_time,
      color = '#4285F4',
      minimum_porters = 1
    } = req.body;

    if (!department_id || !shift_type || !start_time || !end_time) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const assignment = await prisma.default_area_cover_assignments.create({
      data: {
        department_id,
        shift_type,
        start_time,
        end_time,
        color,
        minimum_porters,
        minimum_porters_mon: minimum_porters,
        minimum_porters_tue: minimum_porters,
        minimum_porters_wed: minimum_porters,
        minimum_porters_thu: minimum_porters,
        minimum_porters_fri: minimum_porters,
        minimum_porters_sat: minimum_porters,
        minimum_porters_sun: minimum_porters
      },
      include: {
        departments: {
          include: {
            buildings: true
          }
        }
      }
    });

    // Transform the response
    const transformedAssignment = {
      id: assignment.id,
      department_id: assignment.department_id,
      shift_type: assignment.shift_type,
      start_time: assignment.start_time,
      end_time: assignment.end_time,
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
      }
    };

    return res.status(201).json(transformedAssignment);
  } catch (error) {
    console.error('Error creating area cover assignment:', error);
    return res.status(500).json({ error: 'Failed to create area cover assignment' });
  }
});

// PUT /api/area-cover/assignments/:id - Update a default area cover assignment
router.put('/assignments/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      start_time,
      end_time,
      color,
      minimum_porters
    } = req.body;

    const updateData: any = {};
    if (start_time !== undefined) updateData.start_time = new Date(`1970-01-01T${start_time}`);
    if (end_time !== undefined) updateData.end_time = new Date(`1970-01-01T${end_time}`);
    if (color !== undefined) updateData.color = color;
    if (minimum_porters !== undefined) {
      updateData.minimum_porters = minimum_porters;
      updateData.minimum_porters_mon = minimum_porters;
      updateData.minimum_porters_tue = minimum_porters;
      updateData.minimum_porters_wed = minimum_porters;
      updateData.minimum_porters_thu = minimum_porters;
      updateData.minimum_porters_fri = minimum_porters;
      updateData.minimum_porters_sat = minimum_porters;
      updateData.minimum_porters_sun = minimum_porters;
    }

    const assignment = await prisma.default_area_cover_assignments.update({
      where: { id },
      data: updateData,
      include: {
        departments: {
          include: {
            buildings: true
          }
        }
      }
    });

    // Transform the response
    const transformedAssignment = {
      id: assignment.id,
      department_id: assignment.department_id,
      shift_type: assignment.shift_type,
      start_time: assignment.start_time,
      end_time: assignment.end_time,
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
      }
    };

    return res.json(transformedAssignment);
  } catch (error) {
    console.error('Error updating area cover assignment:', error);
    return res.status(500).json({ error: 'Failed to update area cover assignment' });
  }
});

// DELETE /api/area-cover/assignments/:id - Delete a default area cover assignment
router.delete('/assignments/:id', async (req, res) => {
  try {
    const { id } = req.params;

    await prisma.default_area_cover_assignments.delete({
      where: { id }
    });

    return res.status(204).send();
  } catch (error) {
    console.error('Error deleting area cover assignment:', error);
    return res.status(500).json({ error: 'Failed to delete area cover assignment' });
  }
});

// GET /api/area-cover/assignments/:id/porter-assignments - Get porter assignments for an area cover assignment
router.get('/assignments/:id/porter-assignments', async (req, res) => {
  try {
    const { id } = req.params;

    const porterAssignments = await prisma.default_area_cover_porter_assignments.findMany({
      where: { default_area_cover_assignment_id: id },
      include: {
        staff: true
      },
      orderBy: { start_time: 'asc' }
    });

    // Transform the data to match expected format
    const transformedAssignments = porterAssignments.map(assignment => ({
      id: assignment.id,
      default_area_cover_assignment_id: assignment.default_area_cover_assignment_id,
      porter_id: assignment.porter_id,
      start_time: assignment.start_time 
        ? assignment.start_time.toISOString().substring(11, 16) 
        : null,
      end_time: assignment.end_time 
        ? assignment.end_time.toISOString().substring(11, 16) 
        : null,
      created_at: assignment.created_at,
      updated_at: assignment.updated_at,
      porter: {
        id: assignment.staff.id,
        first_name: assignment.staff.first_name,
        last_name: assignment.staff.last_name,
        role: assignment.staff.role
      }
    }));

    return res.json(transformedAssignments);
  } catch (error) {
    console.error('Error fetching area cover porter assignments:', error);
    return res.status(500).json({ error: 'Failed to fetch porter assignments' });
  }
});

// POST /api/area-cover/assignments/:id/porter-assignments - Create a porter assignment for an area cover assignment
router.post('/assignments/:id/porter-assignments', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      porter_id,
      start_time,
      end_time
    } = req.body;

    if (!porter_id || !start_time || !end_time) {
      return res.status(400).json({ error: 'Missing required fields: porter_id, start_time, end_time' });
    }

    const porterAssignment = await prisma.default_area_cover_porter_assignments.create({
      data: {
        default_area_cover_assignment_id: id,
        porter_id,
        start_time: new Date(`1970-01-01T${start_time}`),
        end_time: new Date(`1970-01-01T${end_time}`)
      },
      include: {
        staff: true
      }
    });

    // Transform the response
    const transformedAssignment = {
      id: porterAssignment.id,
      default_area_cover_assignment_id: porterAssignment.default_area_cover_assignment_id,
      porter_id: porterAssignment.porter_id,
      start_time: porterAssignment.start_time,
      end_time: porterAssignment.end_time,
      created_at: porterAssignment.created_at,
      updated_at: porterAssignment.updated_at,
      porter: {
        id: porterAssignment.staff.id,
        first_name: porterAssignment.staff.first_name,
        last_name: porterAssignment.staff.last_name,
        role: porterAssignment.staff.role
      }
    };

    return res.status(201).json(transformedAssignment);
  } catch (error) {
    console.error('Error creating area cover porter assignment:', error);
    return res.status(500).json({ error: 'Failed to create porter assignment' });
  }
});

// PUT /api/area-cover/porter-assignments/:id - Update a porter assignment
router.put('/porter-assignments/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      start_time,
      end_time
    } = req.body;

    const updateData: any = {};
    if (start_time !== undefined) updateData.start_time = new Date(`1970-01-01T${start_time}`);
    if (end_time !== undefined) updateData.end_time = new Date(`1970-01-01T${end_time}`);

    const porterAssignment = await prisma.default_area_cover_porter_assignments.update({
      where: { id },
      data: updateData,
      include: {
        staff: true
      }
    });

    // Transform the response
    const transformedAssignment = {
      id: porterAssignment.id,
      default_area_cover_assignment_id: porterAssignment.default_area_cover_assignment_id,
      porter_id: porterAssignment.porter_id,
      start_time: porterAssignment.start_time,
      end_time: porterAssignment.end_time,
      created_at: porterAssignment.created_at,
      updated_at: porterAssignment.updated_at,
      porter: {
        id: porterAssignment.staff.id,
        first_name: porterAssignment.staff.first_name,
        last_name: porterAssignment.staff.last_name,
        role: porterAssignment.staff.role
      }
    };

    return res.json(transformedAssignment);
  } catch (error) {
    console.error('Error updating area cover porter assignment:', error);
    return res.status(500).json({ error: 'Failed to update porter assignment' });
  }
});

// DELETE /api/area-cover/porter-assignments/:id - Delete a porter assignment
router.delete('/porter-assignments/:id', async (req, res) => {
  try {
    const { id } = req.params;

    await prisma.default_area_cover_porter_assignments.delete({
      where: { id }
    });

    return res.status(204).send();
  } catch (error) {
    console.error('Error deleting area cover porter assignment:', error);
    return res.status(500).json({ error: 'Failed to delete porter assignment' });
  }
});

export default router;
