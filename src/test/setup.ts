import { DynamoDB } from '@aws-sdk/client-dynamodb';
import { S3Client } from '@aws-sdk/client-s3';
import { CognitoIdentityProviderClient } from '@aws-sdk/client-cognito-identity-provider';

// Mock AWS SDK clients
jest.mock('@aws-sdk/client-dynamodb');
jest.mock('@aws-sdk/client-s3');
jest.mock('@aws-sdk/client-cognito-identity-provider');

// Environment variables
process.env.USER_POOL_ID = 'test-user-pool-id';
process.env.CLIENT_ID = 'test-client-id';
process.env.USERS_TABLE = 'test-users-table';
process.env.TASKS_TABLE = 'test-tasks-table';
process.env.DEVICES_TABLE = 'test-devices-table';
process.env.PHOTOS_BUCKET = 'test-photos-bucket';

// Mock implementations
const mockDynamoDB = DynamoDB as jest.MockedClass<typeof DynamoDB>;
const mockS3 = S3Client as jest.MockedClass<typeof S3Client>;
const mockCognito = CognitoIdentityProviderClient as jest.MockedClass<typeof CognitoIdentityProviderClient>;

mockDynamoDB.prototype.send = jest.fn();
mockS3.prototype.send = jest.fn();
mockCognito.prototype.send = jest.fn();

// Global test setup
beforeEach(() => {
  jest.clearAllMocks();
});

// Helper functions for tests
export const createMockEvent = (
  method: string,
  path: string,
  body?: any,
  queryParams?: Record<string, string>,
  pathParams?: Record<string, string>
) => ({
  httpMethod: method,
  path,
  body: body ? JSON.stringify(body) : null,
  queryStringParameters: queryParams || null,
  pathParameters: pathParams || null,
  headers: {
    Authorization: 'Bearer test-token',
  },
  requestContext: {
    authorizer: {
      claims: {
        sub: 'test-user-id',
        email: 'test@example.com',
        'custom:role': 'parent',
      },
    },
  },
});

export const createMockUser = (role: 'parent' | 'kid' = 'parent') => ({
  userId: 'test-user-id',
  email: 'test@example.com',
  role,
});

export const createMockTask = (overrides: Partial<any> = {}) => ({
  taskId: 'test-task-id',
  kidId: 'test-kid-id',
  title: 'Test Task',
  description: 'Test Description',
  status: 'pending',
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  ...overrides,
});

export const createMockDevice = (overrides: Partial<any> = {}) => ({
  kidId: 'test-kid-id',
  macAddress: '00:11:22:33:44:55',
  deviceName: 'Test Device',
  deviceType: 'ps4',
  isBlocked: true,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  ...overrides,
}); 