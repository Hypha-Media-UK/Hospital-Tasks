/**
 * Shared utilities for porter assignment operations
 * Provides DRY functionality for both area cover and support service assignments
 */

import { Request, Response } from 'express';
import { prisma } from '../server';
import { parseTimePair } from './timeUtils';

export interface PorterAssignmentConfig {
  // Database table names
  assignmentTable: string;
  porterAssignmentTable: string;
  
  // Foreign key field names
  assignmentIdField: string;
  
  // Include relationships for queries
  assignmentInclude?: any;
  porterAssignmentInclude?: any;
  
  // Assignment type for error messages
  assignmentType: string;
}

export const AREA_COVER_CONFIG: PorterAssignmentConfig = {
  assignmentTable: 'shift_area_cover_assignments',
  porterAssignmentTable: 'shift_area_cover_porter_assignments',
  assignmentIdField: 'shift_area_cover_assignment_id',
  assignmentInclude: {
    departments: {
      include: {
        buildings: true
      }
    }
  },
  porterAssignmentInclude: {
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
  },
  assignmentType: 'area cover'
};

export const SUPPORT_SERVICE_CONFIG: PorterAssignmentConfig = {
  assignmentTable: 'shift_support_service_assignments',
  porterAssignmentTable: 'shift_support_service_porter_assignments',
  assignmentIdField: 'shift_support_service_assignment_id',
  assignmentInclude: {
    support_services: true
  },
  porterAssignmentInclude: {
    staff: true,
    shift_support_service_assignments: {
      include: {
        support_services: true
      }
    }
  },
  assignmentType: 'support service'
};

/**
 * Generic function to create a porter assignment
 */
export async function createPorterAssignment(
  config: PorterAssignmentConfig,
  shiftId: string,
  assignmentId: string,
  porterData: { porter_id: string; start_time: string; end_time: string }
) {
  const { porter_id, start_time, end_time } = porterData;

  // Validate required fields
  if (!porter_id || !start_time || !end_time) {
    throw new Error('porter_id, start_time, and end_time are required');
  }

  // Parse and validate time strings
  const timeResult = parseTimePair(start_time, end_time);
  if (!timeResult.isValid) {
    throw new Error(timeResult.error || 'Invalid time format');
  }

  // Verify the assignment exists and belongs to this shift
  const assignment = await (prisma as any)[config.assignmentTable].findFirst({
    where: {
      id: assignmentId,
      shift_id: shiftId
    }
  });

  if (!assignment) {
    throw new Error(`${config.assignmentType} assignment not found`);
  }

  // Verify porter exists
  const porter = await prisma.staff.findUnique({
    where: { id: porter_id }
  });

  if (!porter) {
    throw new Error('Porter not found');
  }

  // Create the porter assignment
  const porterAssignment = await (prisma as any)[config.porterAssignmentTable].create({
    data: {
      [config.assignmentIdField]: assignmentId,
      porter_id,
      start_time: timeResult.startDateTime,
      end_time: timeResult.endDateTime
    },
    include: config.porterAssignmentInclude
  });

  // Format the response to match expected frontend structure
  return {
    id: porterAssignment.id,
    [config.assignmentIdField]: porterAssignment[config.assignmentIdField],
    porter_id: porterAssignment.porter_id,
    start_time: start_time,
    end_time: end_time,
    created_at: porterAssignment.created_at,
    updated_at: porterAssignment.updated_at,
    porter: {
      id: porterAssignment.staff.id,
      first_name: porterAssignment.staff.first_name,
      last_name: porterAssignment.staff.last_name,
      role: porterAssignment.staff.role
    }
  };
}

/**
 * Generic function to update a porter assignment
 */
export async function updatePorterAssignment(
  config: PorterAssignmentConfig,
  shiftId: string,
  assignmentId: string,
  updates: { porter_id?: string; start_time?: string; end_time?: string }
) {
  const { porter_id, start_time, end_time } = updates;

  if (!start_time || !end_time) {
    throw new Error('start_time and end_time are required');
  }

  // Parse and validate time strings
  const timeResult = parseTimePair(start_time, end_time);
  if (!timeResult.isValid) {
    throw new Error(timeResult.error || 'Invalid time format');
  }

  // Verify the assignment exists and belongs to this shift
  const existingAssignment = await (prisma as any)[config.porterAssignmentTable].findFirst({
    where: {
      id: assignmentId,
      [config.assignmentIdField]: {
        in: await getAssignmentIdsForShift(config, shiftId)
      }
    }
  });

  if (!existingAssignment) {
    throw new Error(`${config.assignmentType} porter assignment not found`);
  }

  // Update the assignment
  const updateData: any = {
    start_time: timeResult.startDateTime,
    end_time: timeResult.endDateTime
  };

  if (porter_id) {
    updateData.porter_id = porter_id;
  }

  const assignment = await (prisma as any)[config.porterAssignmentTable].update({
    where: { id: assignmentId },
    data: updateData,
    include: config.porterAssignmentInclude
  });

  // Format the response to match expected frontend structure
  return {
    id: assignment.id,
    [config.assignmentIdField]: assignment[config.assignmentIdField],
    porter_id: assignment.porter_id,
    start_time: start_time,
    end_time: end_time,
    created_at: assignment.created_at,
    updated_at: assignment.updated_at,
    porter: {
      id: assignment.staff.id,
      first_name: assignment.staff.first_name,
      last_name: assignment.staff.last_name,
      role: assignment.staff.role
    }
  };
}

/**
 * Generic function to delete a porter assignment
 */
export async function deletePorterAssignment(
  config: PorterAssignmentConfig,
  shiftId: string,
  assignmentId: string
) {
  // Verify the assignment exists and belongs to this shift
  const existingAssignment = await (prisma as any)[config.porterAssignmentTable].findFirst({
    where: {
      id: assignmentId,
      [config.assignmentIdField]: {
        in: await getAssignmentIdsForShift(config, shiftId)
      }
    }
  });

  if (!existingAssignment) {
    throw new Error(`${config.assignmentType} porter assignment not found`);
  }

  await (prisma as any)[config.porterAssignmentTable].delete({
    where: { id: assignmentId }
  });

  return true;
}

/**
 * Helper function to get assignment IDs for a shift
 */
async function getAssignmentIdsForShift(config: PorterAssignmentConfig, shiftId: string): Promise<string[]> {
  const assignments = await (prisma as any)[config.assignmentTable].findMany({
    where: { shift_id: shiftId },
    select: { id: true }
  });
  
  return assignments.map((a: any) => a.id);
}

/**
 * Express middleware wrapper for porter assignment operations
 */
export function createPorterAssignmentHandler(config: PorterAssignmentConfig) {
  return {
    create: async (req: Request, res: Response): Promise<void> => {
      try {
        const { id: shiftId, [config.assignmentType === 'area cover' ? 'areaCoverId' : 'serviceId']: assignmentId } = req.params;
        const porterData = req.body;

        const result = await createPorterAssignment(config, shiftId, assignmentId, porterData);
        res.status(201).json(result);
      } catch (error: any) {
        console.error(`Error creating ${config.assignmentType} porter assignment:`, error);
        
        if (error.code === 'P2002') {
          res.status(409).json({
            error: 'Conflict',
            message: `Porter is already assigned to this ${config.assignmentType}`
          });
          return;
        }

        res.status(500).json({
          error: 'Internal Server Error',
          message: `Failed to create ${config.assignmentType} porter assignment`
        });
      }
    },

    update: async (req: Request, res: Response): Promise<void> => {
      try {
        const { id: shiftId, assignmentId } = req.params;
        const updates = req.body;

        const result = await updatePorterAssignment(config, shiftId, assignmentId, updates);
        res.json(result);
      } catch (error: any) {
        console.error(`Error updating ${config.assignmentType} porter assignment:`, error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: `Failed to update ${config.assignmentType} porter assignment`
        });
      }
    },

    delete: async (req: Request, res: Response): Promise<void> => {
      try {
        const { id: shiftId, assignmentId } = req.params;

        await deletePorterAssignment(config, shiftId, assignmentId);
        res.status(204).send();
      } catch (error: any) {
        console.error(`Error deleting ${config.assignmentType} porter assignment:`, error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: `Failed to delete ${config.assignmentType} porter assignment`
        });
      }
    }
  };
}
