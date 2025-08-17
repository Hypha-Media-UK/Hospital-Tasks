import { Request, Response, NextFunction } from 'express';

/**
 * Standard API Error class
 */
export class ApiError extends Error {
  public status: number;
  public data?: any;

  constructor(message: string, status: number = 500, data?: any) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.data = data;
  }

  static badRequest(message: string = 'Bad Request', data?: any) {
    return new ApiError(message, 400, data);
  }

  static unauthorized(message: string = 'Unauthorized') {
    return new ApiError(message, 401);
  }

  static forbidden(message: string = 'Forbidden') {
    return new ApiError(message, 403);
  }

  static notFound(message: string = 'Not Found') {
    return new ApiError(message, 404);
  }

  static conflict(message: string = 'Conflict') {
    return new ApiError(message, 409);
  }

  static internal(message: string = 'Internal Server Error') {
    return new ApiError(message, 500);
  }
}

/**
 * Async error handler wrapper
 * Wraps async route handlers to catch errors and pass them to error middleware
 */
export const asyncHandler = (fn: Function) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * Global error handling middleware
 */
export const errorHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  console.error('Error occurred:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    timestamp: new Date().toISOString()
  });

  // Handle ApiError instances
  if (err instanceof ApiError) {
    res.status(err.status).json({
      error: err.message,
      ...(process.env.NODE_ENV === 'development' && { 
        stack: err.stack,
        data: err.data 
      })
    });
    return;
  }

  // Handle Prisma errors
  if (err.code) {
    switch (err.code) {
      case 'P2002':
        res.status(409).json({
          error: 'Unique constraint violation',
          message: 'A record with this data already exists'
        });
        return;
      case 'P2025':
        res.status(404).json({
          error: 'Record not found',
          message: 'The requested record does not exist'
        });
        return;
      case 'P2003':
        res.status(400).json({
          error: 'Foreign key constraint violation',
          message: 'Referenced record does not exist'
        });
        return;
      default:
        console.error('Unhandled Prisma error:', err.code, err.message);
    }
  }

  // Handle validation errors
  if (err.name === 'ValidationError') {
    res.status(400).json({
      error: 'Validation Error',
      message: err.message,
      ...(process.env.NODE_ENV === 'development' && { details: err.details })
    });
    return;
  }

  // Default error response
  res.status(500).json({
    error: process.env.NODE_ENV === 'development' ? err.message : 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
};

/**
 * 404 handler for unmatched routes
 */
export const notFoundHandler = (req: Request, res: Response): void => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`
  });
};

/**
 * Request validation helper
 */
export const validateRequired = (fields: string[], data: any): void => {
  const missing = fields.filter(field => !data[field]);
  if (missing.length > 0) {
    throw ApiError.badRequest(
      `Missing required fields: ${missing.join(', ')}`,
      { missingFields: missing }
    );
  }
};

/**
 * Pagination helper
 */
export const getPaginationParams = (query: any) => {
  const limit = Math.min(parseInt(query.limit as string) || 100, 1000); // Max 1000 items
  const offset = Math.max(parseInt(query.offset as string) || 0, 0);
  
  return { limit, offset };
};

/**
 * Success response helper
 */
export const sendSuccess = (res: Response, data: any, message?: string, status: number = 200) => {
  res.status(status).json({
    success: true,
    ...(message && { message }),
    data
  });
};

/**
 * Created response helper
 */
export const sendCreated = (res: Response, data: any, message?: string) => {
  sendSuccess(res, data, message || 'Resource created successfully', 201);
};

/**
 * No content response helper
 */
export const sendNoContent = (res: Response) => {
  res.status(204).send();
};

/**
 * Time formatting utilities for consistent API responses
 */
export const formatTimeField = (timeValue: any): string | null => {
  if (!timeValue) return null;
  if (timeValue instanceof Date) {
    return timeValue.toISOString().substring(11, 16); // Extract HH:MM
  }
  return timeValue;
};

export const formatTimeForDB = (timeStr: string | null): Date | null => {
  if (!timeStr) return null;
  // If it's already in HH:MM format, convert to full datetime
  if (typeof timeStr === 'string' && timeStr.match(/^\d{2}:\d{2}$/)) {
    return new Date(`1970-01-01T${timeStr}:00.000Z`);
  }
  return timeStr as any;
};

export const formatObjectTimeFields = (obj: any, timeFields: string[]): any => {
  if (!obj) return obj;
  const formatted = { ...obj };
  timeFields.forEach(field => {
    if (formatted[field]) {
      formatted[field] = formatTimeField(formatted[field]);
    }
  });
  return formatted;
};
