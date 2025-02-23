import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { z } from 'zod';

// Response helper
export const createResponse = (
  statusCode: number,
  body: Record<string, any> | string,
  headers: Record<string, string> = {}
): APIGatewayProxyResult => {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Credentials': true,
      ...headers,
    },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  };
};

// Error response helper
export const createErrorResponse = (
  statusCode: number,
  message: string,
  code: string = 'ERROR',
  details?: any
): APIGatewayProxyResult => {
  return createResponse(statusCode, {
    error: {
      code,
      message,
      details,
    },
  });
};

// JWT verification
export const verifyToken = async (
  event: APIGatewayProxyEvent,
  userPoolId: string,
  clientId: string
): Promise<{ userId: string; email: string; role: string } | null> => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return null;
    }

    const verifier = CognitoJwtVerifier.create({
      userPoolId,
      tokenUse: 'access',
      clientId,
    });

    const payload = await verifier.verify(token);
    const email = payload.email;
    const role = payload['custom:role'];

    if (typeof email !== 'string' || typeof role !== 'string') {
      console.error('Missing or invalid claims in token');
      return null;
    }

    return {
      userId: payload.sub,
      email,
      role,
    };
  } catch (error) {
    console.error('Token verification failed:', error);
    return null;
  }
};

// Request validation helper
export const validateRequest = <T>(
  schema: z.ZodType<T>,
  data: unknown
): { success: true; data: T } | { success: false; error: string } => {
  try {
    const validData = schema.parse(data);
    return { success: true, data: validData };
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { success: false, error: error.errors[0].message };
    }
    return { success: false, error: 'Invalid request data' };
  }
};

// Common request schemas
export const taskSchema = z.object({
  title: z.string().min(1).max(100),
  description: z.string().max(500),
  dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  kidId: z.string().uuid(),
});

export const deviceSchema = z.object({
  kidId: z.string().uuid(),
  macAddress: z.string().regex(/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/),
  deviceName: z.string().min(1).max(50),
  deviceType: z.enum(['ps4', 'tablet', 'other']),
});

// Helper functions
export const generateId = (): string => {
  return Date.now().toString(36) + Math.random().toString(36).substring(2);
};

export const isValidMacAddress = (mac: string): boolean => {
  return /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/.test(mac);
};

export const normalizeEmail = (email: string): string => {
  return email.toLowerCase().trim();
};

// Error types
export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export class AuthorizationError extends Error {
  constructor(message: string = 'Unauthorized') {
    super(message);
    this.name = 'AuthorizationError';
  }
}

export class NotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NotFoundError';
  }
}

// Constants
export const MAX_PHOTO_SIZE = 5 * 1024 * 1024; // 5MB
export const ALLOWED_PHOTO_TYPES = ['image/jpeg', 'image/png'];
export const MAX_TASKS_PER_KID = 10;
export const MAX_DEVICES_PER_KID = 5;

// Date helpers
export const isValidDate = (dateString: string): boolean => {
  const date = new Date(dateString);
  return date instanceof Date && !isNaN(date.getTime());
};

export const formatDate = (date: Date): string => {
  return date.toISOString().split('T')[0];
};

export const getCurrentDate = (): string => {
  return formatDate(new Date());
};

// Photo helpers
export const generatePhotoKey = (taskId: string, userId: string): string => {
  return `tasks/${taskId}/${userId}/${Date.now()}.jpg`;
};

export const isValidPhotoType = (contentType: string): boolean => {
  return ALLOWED_PHOTO_TYPES.includes(contentType);
};

// Task status helpers
export type TaskStatus = 'pending' | 'completed' | 'approved' | 'rejected';

export const isValidTaskStatus = (status: string): status is TaskStatus => {
  return ['pending', 'completed', 'approved', 'rejected'].includes(status);
};

export const canUpdateTaskStatus = (
  currentStatus: TaskStatus,
  newStatus: TaskStatus,
  userRole: string
): boolean => {
  if (userRole === 'kid') {
    return currentStatus === 'pending' && newStatus === 'completed';
  }
  if (userRole === 'parent') {
    return (
      currentStatus === 'completed' &&
      (newStatus === 'approved' || newStatus === 'rejected')
    );
  }
  return false;
}; 