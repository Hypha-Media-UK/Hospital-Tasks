import { Request, Response, NextFunction } from 'express';
import {
  ApiError,
  asyncHandler,
  errorHandler,
  notFoundHandler,
  validateRequired,
  getPaginationParams,
  sendSuccess,
  sendCreated,
  sendNoContent
} from '../../middleware/errorHandler';

// Mock Express objects
const mockRequest = (overrides = {}) => ({
  url: '/test',
  method: 'GET',
  originalUrl: '/test',
  ...overrides
} as Request);

const mockResponse = () => {
  const res = {} as Response;
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  return res;
};

const mockNext = jest.fn() as NextFunction;

describe('errorHandler middleware', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Mock console methods to avoid noise in tests
    jest.spyOn(console, 'error').mockImplementation();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('ApiError', () => {
    it('should create ApiError with message and status', () => {
      const error = new ApiError('Test error', 404, { extra: 'data' });
      expect(error.message).toBe('Test error');
      expect(error.status).toBe(404);
      expect(error.data).toEqual({ extra: 'data' });
      expect(error.name).toBe('ApiError');
    });

    it('should have static helper methods', () => {
      expect(ApiError.badRequest().status).toBe(400);
      expect(ApiError.unauthorized().status).toBe(401);
      expect(ApiError.forbidden().status).toBe(403);
      expect(ApiError.notFound().status).toBe(404);
      expect(ApiError.conflict().status).toBe(409);
      expect(ApiError.internal().status).toBe(500);
    });
  });

  describe('asyncHandler', () => {
    it('should handle successful async operations', async () => {
      const mockHandler = jest.fn().mockResolvedValue('success');
      const wrappedHandler = asyncHandler(mockHandler);

      const req = mockRequest();
      const res = mockResponse();

      await wrappedHandler(req, res, mockNext);

      expect(mockHandler).toHaveBeenCalledWith(req, res, mockNext);
      expect(mockNext).not.toHaveBeenCalled();
    });

    it('should catch and pass errors to next', async () => {
      const error = new Error('Test error');
      const mockHandler = jest.fn().mockRejectedValue(error);
      const wrappedHandler = asyncHandler(mockHandler);

      const req = mockRequest();
      const res = mockResponse();

      await wrappedHandler(req, res, mockNext);

      expect(mockNext).toHaveBeenCalledWith(error);
    });
  });

  describe('errorHandler', () => {
    it('should handle ApiError instances', () => {
      const error = new ApiError('Test error', 404);
      const req = mockRequest();
      const res = mockResponse();

      errorHandler(error, req, res, mockNext);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Test error'
      });
    });

    it('should handle Prisma P2002 error (unique constraint)', () => {
      const error = { code: 'P2002', message: 'Unique constraint failed' };
      const req = mockRequest();
      const res = mockResponse();

      errorHandler(error, req, res, mockNext);

      expect(res.status).toHaveBeenCalledWith(409);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Unique constraint violation',
        message: 'A record with this data already exists'
      });
    });

    it('should handle Prisma P2025 error (record not found)', () => {
      const error = { code: 'P2025', message: 'Record not found' };
      const req = mockRequest();
      const res = mockResponse();

      errorHandler(error, req, res, mockNext);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Record not found',
        message: 'The requested record does not exist'
      });
    });

    it('should handle validation errors', () => {
      const error = { name: 'ValidationError', message: 'Invalid data' };
      const req = mockRequest();
      const res = mockResponse();

      errorHandler(error, req, res, mockNext);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Validation Error',
        message: 'Invalid data'
      });
    });

    it('should handle generic errors', () => {
      const error = new Error('Generic error');
      const req = mockRequest();
      const res = mockResponse();

      errorHandler(error, req, res, mockNext);

      expect(res.status).toHaveBeenCalledWith(500);
    });
  });

  describe('notFoundHandler', () => {
    it('should return 404 for unmatched routes', () => {
      const req = mockRequest({ originalUrl: '/nonexistent' });
      const res = mockResponse();

      notFoundHandler(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Not Found',
        message: 'Route /nonexistent not found'
      });
    });
  });

  describe('validateRequired', () => {
    it('should pass validation for valid data', () => {
      const data = { name: 'John', email: 'john@example.com' };
      expect(() => validateRequired(['name', 'email'], data)).not.toThrow();
    });

    it('should throw ApiError for missing fields', () => {
      const data = { name: 'John' };
      expect(() => validateRequired(['name', 'email'], data)).toThrow(ApiError);
    });
  });

  describe('getPaginationParams', () => {
    it('should return default pagination', () => {
      const result = getPaginationParams({});
      expect(result).toEqual({ limit: 100, offset: 0 });
    });

    it('should parse query parameters', () => {
      const query = { limit: '50', offset: '10' };
      const result = getPaginationParams(query);
      expect(result).toEqual({ limit: 50, offset: 10 });
    });

    it('should enforce maximum limit', () => {
      const query = { limit: '2000' };
      const result = getPaginationParams(query);
      expect(result.limit).toBe(1000); // Max limit
    });

    it('should enforce minimum offset', () => {
      const query = { offset: '-10' };
      const result = getPaginationParams(query);
      expect(result.offset).toBe(0); // Min offset
    });
  });

  describe('response helpers', () => {
    describe('sendSuccess', () => {
      it('should send success response', () => {
        const res = mockResponse();
        const data = { id: 1, name: 'Test' };

        sendSuccess(res, data, 'Success message');

        expect(res.status).toHaveBeenCalledWith(200);
        expect(res.json).toHaveBeenCalledWith({
          success: true,
          message: 'Success message',
          data
        });
      });

      it('should send success response without message', () => {
        const res = mockResponse();
        const data = { id: 1, name: 'Test' };

        sendSuccess(res, data);

        expect(res.json).toHaveBeenCalledWith({
          success: true,
          data
        });
      });
    });

    describe('sendCreated', () => {
      it('should send created response', () => {
        const res = mockResponse();
        const data = { id: 1, name: 'Test' };

        sendCreated(res, data);

        expect(res.status).toHaveBeenCalledWith(201);
        expect(res.json).toHaveBeenCalledWith({
          success: true,
          message: 'Resource created successfully',
          data
        });
      });
    });

    describe('sendNoContent', () => {
      it('should send no content response', () => {
        const res = mockResponse();

        sendNoContent(res);

        expect(res.status).toHaveBeenCalledWith(204);
        expect(res.send).toHaveBeenCalled();
      });
    });
  });
});
