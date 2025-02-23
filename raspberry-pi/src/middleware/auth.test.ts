import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { authenticateToken } from './auth';

describe('Authentication Middleware', () => {
  const JWT_SECRET = 'test-secret';
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;
  let nextFunction: NextFunction;

  beforeEach(() => {
    process.env.JWT_SECRET = JWT_SECRET;
    mockRequest = {};
    mockResponse = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    nextFunction = jest.fn();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should reject requests without token', () => {
    mockRequest.headers = {};

    authenticateToken(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    expect(mockResponse.status).toHaveBeenCalledWith(401);
    expect(mockResponse.json).toHaveBeenCalledWith({
      error: 'Authentication required',
    });
    expect(nextFunction).not.toHaveBeenCalled();
  });

  it('should reject requests with invalid token format', () => {
    mockRequest.headers = {
      authorization: 'invalid-token',
    };

    authenticateToken(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    expect(mockResponse.status).toHaveBeenCalledWith(403);
    expect(mockResponse.json).toHaveBeenCalledWith({
      error: 'Invalid token',
    });
    expect(nextFunction).not.toHaveBeenCalled();
  });

  it('should reject requests with invalid token', () => {
    mockRequest.headers = {
      authorization: 'Bearer invalid-token',
    };

    authenticateToken(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    expect(mockResponse.status).toHaveBeenCalledWith(403);
    expect(mockResponse.json).toHaveBeenCalledWith({
      error: 'Invalid token',
    });
    expect(nextFunction).not.toHaveBeenCalled();
  });

  it('should reject requests from non-parent users', () => {
    const kidToken = jwt.sign({ role: 'kid' }, JWT_SECRET);
    mockRequest.headers = {
      authorization: `Bearer ${kidToken}`,
    };

    authenticateToken(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    expect(mockResponse.status).toHaveBeenCalledWith(403);
    expect(mockResponse.json).toHaveBeenCalledWith({
      error: 'Only parents can control network access',
    });
    expect(nextFunction).not.toHaveBeenCalled();
  });

  it('should allow requests from parent users', () => {
    const parentToken = jwt.sign({ role: 'parent' }, JWT_SECRET);
    mockRequest.headers = {
      authorization: `Bearer ${parentToken}`,
    };

    authenticateToken(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    expect(nextFunction).toHaveBeenCalled();
    expect(mockResponse.status).not.toHaveBeenCalled();
    expect(mockResponse.json).not.toHaveBeenCalled();
  });

  it('should handle missing JWT_SECRET', () => {
    delete process.env.JWT_SECRET;
    const parentToken = jwt.sign({ role: 'parent' }, JWT_SECRET);
    mockRequest.headers = {
      authorization: `Bearer ${parentToken}`,
    };

    authenticateToken(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    expect(mockResponse.status).toHaveBeenCalledWith(403);
    expect(mockResponse.json).toHaveBeenCalledWith({
      error: 'Invalid token',
    });
    expect(nextFunction).not.toHaveBeenCalled();
  });
}); 