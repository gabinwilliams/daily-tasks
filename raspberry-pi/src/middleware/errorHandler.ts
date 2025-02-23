import { Request, Response, NextFunction } from 'express';

export class NetworkControlError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code: string = 'INTERNAL_ERROR'
  ) {
    super(message);
    this.name = 'NetworkControlError';
  }
}

export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  console.error('Error:', error);

  if (error instanceof NetworkControlError) {
    res.status(error.statusCode).json({
      error: {
        code: error.code,
        message: error.message,
      },
    });
    return;
  }

  // Handle specific error types
  if (error.name === 'JsonWebTokenError') {
    res.status(401).json({
      error: {
        code: 'INVALID_TOKEN',
        message: 'Invalid authentication token',
      },
    });
    return;
  }

  if (error.name === 'TokenExpiredError') {
    res.status(401).json({
      error: {
        code: 'TOKEN_EXPIRED',
        message: 'Authentication token has expired',
      },
    });
    return;
  }

  // Default error response
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
    },
  });
};

// Common error types
export const createValidationError = (message: string): NetworkControlError => {
  return new NetworkControlError(message, 400, 'VALIDATION_ERROR');
};

export const createAuthenticationError = (message: string): NetworkControlError => {
  return new NetworkControlError(message, 401, 'AUTHENTICATION_ERROR');
};

export const createAuthorizationError = (message: string): NetworkControlError => {
  return new NetworkControlError(message, 403, 'AUTHORIZATION_ERROR');
};

export const createNotFoundError = (message: string): NetworkControlError => {
  return new NetworkControlError(message, 404, 'NOT_FOUND');
};

export const createRateLimitError = (message: string): NetworkControlError => {
  return new NetworkControlError(message, 429, 'RATE_LIMIT_EXCEEDED');
}; 