import { Router, Request, Response } from 'express';
import { prisma } from '../server';
import { asyncHandler, ApiError, validateRequired, getPaginationParams, sendSuccess, sendCreated, formatObjectTimeFields, formatTimeForDB } from '../middleware/errorHandler';

// Helper function to format staff time fields for response
const formatStaffTimeFields = (staff: any) => formatObjectTimeFields(staff, ['contracted_hours_start', 'contracted_hours_end']);

const router = Router();

// GET /api/staff - Get all staff with optional filtering
router.get('/', asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { role, department_id, porter_type } = req.query;
  const { limit, offset } = getPaginationParams(req.query);

  const where: any = {};

  if (role) where.role = role as string;
  if (department_id) where.department_id = department_id as string;
  if (porter_type) where.porter_type = porter_type as string;

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
    take: limit,
    skip: offset
  });

  // Format time fields properly
  const formattedStaff = staff.map(formatStaffTimeFields);

  sendSuccess(res, formattedStaff);
}));

// GET /api/staff/:id - Get specific staff member
router.get('/:id', asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { id } = req.params;

  const staff = await prisma.staff.findUnique({
    where: { id },
    include: {
      departments: {
        include: {
          buildings: true
        }
      }
    }
  });

  if (!staff) {
    throw ApiError.notFound('Staff member not found');
  }

  sendSuccess(res, formatStaffTimeFields(staff));
}));

// POST /api/staff - Create new staff member
router.post('/', asyncHandler(async (req: Request, res: Response): Promise<void> => {
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
  validateRequired(['first_name', 'last_name', 'role'], req.body);

  // Validate role
  const validRoles = ['supervisor', 'porter'];
  if (!validRoles.includes(role)) {
    throw ApiError.badRequest(`Invalid role. Must be one of: ${validRoles.join(', ')}`);
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
      contracted_hours_start: formatTimeForDB(contracted_hours_start),
      contracted_hours_end: formatTimeForDB(contracted_hours_end)
    },
    include: {
      departments: {
        include: {
          buildings: true
        }
      }
    }
  });

  sendCreated(res, formatStaffTimeFields(staff), 'Staff member created successfully');
}));

// PUT /api/staff/:id - Update staff member
router.put('/:id', asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { id } = req.params;
  const updateData = { ...req.body };

  // Remove id from update data if present
  delete updateData.id;



  // Format time fields if they exist
  if (updateData.contracted_hours_start) {
    updateData.contracted_hours_start = formatTimeForDB(updateData.contracted_hours_start);
  }
  if (updateData.contracted_hours_end) {
    updateData.contracted_hours_end = formatTimeForDB(updateData.contracted_hours_end);
  }

  const staff = await prisma.staff.update({
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

  sendSuccess(res, formatStaffTimeFields(staff), 'Staff member updated successfully');
}));

// DELETE /api/staff/:id - Delete staff member
router.delete('/:id', asyncHandler(async (req: Request, res: Response): Promise<void> => {
  const { id } = req.params;

  await prisma.staff.delete({
    where: { id }
  });

  res.status(204).send();
}));

export default router;
