import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { S3Client } from '@aws-sdk/client-s3';
import { CognitoIdentityProviderClient } from '@aws-sdk/client-cognito-identity-provider';
import { mockClient } from 'aws-sdk-client-mock';
import { APIGatewayProxyEvent, APIGatewayEventRequestContext } from 'aws-lambda';

// Create mock clients using aws-sdk-client-mock
export const mockDynamoDB = mockClient(DynamoDBClient);
export const mockS3 = mockClient(S3Client);
export const mockCognito = mockClient(CognitoIdentityProviderClient);

// Environment variables
process.env.USER_POOL_ID = 'test-user-pool-id';
process.env.CLIENT_ID = 'test-client-id';
process.env.USERS_TABLE = 'test-users-table';
process.env.TASKS_TABLE = 'test-tasks-table';
process.env.DEVICES_TABLE = 'test-devices-table';
process.env.PHOTOS_BUCKET = 'test-photos-bucket';

// Reset all mocks before each test
beforeEach(() => {
  mockDynamoDB.reset();
  mockS3.reset();
  mockCognito.reset();
});

interface User {
  userId: string;
  email: string;
  role: 'parent' | 'kid';
}

// Helper functions for tests
export const createMockEvent = (
  method: string,
  path: string,
  body?: any,
  queryParams?: Record<string, string>,
  pathParams?: Record<string, string>
): APIGatewayProxyEvent => ({
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
    accountId: '123456789012',
    apiId: 'test-api',
    httpMethod: method,
    identity: {
      accessKey: null,
      accountId: null,
      apiKey: null,
      apiKeyId: null,
      caller: null,
      clientCert: null,
      cognitoAuthenticationProvider: null,
      cognitoAuthenticationType: null,
      cognitoIdentityId: null,
      cognitoIdentityPoolId: null,
      principalOrgId: null,
      sourceIp: '127.0.0.1',
      user: null,
      userAgent: null,
      userArn: null,
    },
    path,
    stage: 'test',
    requestId: 'test-request-id',
    resourceId: 'test-resource',
    resourcePath: path,
    protocol: 'HTTP/1.1',
    requestTimeEpoch: Date.now(),
    domainName: 'test-domain.com',
    domainPrefix: 'test',
  } as APIGatewayEventRequestContext,
  multiValueHeaders: {},
  isBase64Encoded: false,
  multiValueQueryStringParameters: null,
  stageVariables: null,
  resource: path,
});

export const createMockUser = (role: 'parent' | 'kid' = 'parent'): User => ({
  userId: 'test-user-id',
  email: 'test@example.com',
  role,
});

// Task interface for better type safety
interface Task {
  taskId: string;
  kidId: string;
  title: string;
  description: string;
  status: 'pending' | 'completed' | 'approved' | 'rejected';
  createdAt: string;
  updatedAt: string;
  photoUrl?: string;
  parentComment?: string;
}

export const createMockTask = (overrides: Partial<Task> = {}): Task => ({
  taskId: 'test-task-id',
  kidId: 'test-kid-id',
  title: 'Test Task',
  description: 'Test Description',
  status: 'pending',
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  ...overrides,
});

interface Device {
  kidId: string;
  macAddress: string;
  deviceName: string;
  deviceType: 'ps4' | 'tablet' | 'other';
  isBlocked: boolean;
  createdAt: string;
  updatedAt: string;
}

export const createMockDevice = (overrides: Partial<Device> = {}): Device => ({
  kidId: 'test-kid-id',
  macAddress: '00:11:22:33:44:55',
  deviceName: 'Test Device',
  deviceType: 'ps4',
  isBlocked: true,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  ...overrides,
}); 