import { handler } from '../../../lambda/tasks';
import {
  DynamoDBDocument,
  ScanCommand,
  GetCommand,
  PutCommand,
  QueryCommand,
  UpdateCommand,
  DeleteCommand,
} from '@aws-sdk/lib-dynamodb';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { mockClient } from 'aws-sdk-client-mock';
import 'aws-sdk-client-mock-jest';
import { APIGatewayProxyEvent } from 'aws-lambda';
import { Task, TaskStatus } from '../../../lambda/layers/common/nodejs/types';

const ddbMock = mockClient(DynamoDBDocument);
const s3Mock = mockClient(S3Client);

// Helper function to create mock API Gateway events
const createMockEvent = (
  method: string,
  path: string,
  options: {
    body?: any;
    pathParameters?: Record<string, string>;
    queryStringParameters?: Record<string, string>;
    claims?: Record<string, string>;
  } = {}
): APIGatewayProxyEvent => ({
  httpMethod: method,
  path,
  body: options.body ? JSON.stringify(options.body) : null,
  pathParameters: options.pathParameters || null,
  queryStringParameters: options.queryStringParameters || null,
  multiValueQueryStringParameters: null,
  headers: {},
  multiValueHeaders: {},
  isBase64Encoded: false,
  stageVariables: null,
  requestContext: {
    accountId: '123456789012',
    apiId: 'test-api',
    authorizer: { claims: options.claims || {} },
    protocol: 'HTTP/1.1',
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
    requestId: 'test-id',
    requestTimeEpoch: Date.now(),
    resourceId: 'test-resource',
    resourcePath: path,
  },
  resource: path,
});

describe('Tasks Lambda', () => {
  const mockParentUser = {
    sub: 'test-parent-id',
    email: 'parent@test.com',
    'custom:role': 'parent',
  };

  const mockKidUser = {
    sub: 'test-kid-id',
    email: 'kid@test.com',
    'custom:role': 'kid',
  };

  const mockTask: Task = {
    taskId: 'test-task-id',
    kidId: 'test-kid-id',
    title: 'Test Task',
    description: 'Test Description',
    status: 'pending',
    dueDate: new Date().toISOString(),
    createdBy: 'test-parent-id',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  beforeEach(() => {
    ddbMock.reset();
    s3Mock.reset();
    process.env.TASKS_TABLE = 'test-tasks-table';
    process.env.PHOTOS_BUCKET = 'test-photos-bucket';
  });

  describe('GET /tasks', () => {
    it('should list tasks for a kid', async () => {
      const mockEvent = createMockEvent('GET', '/tasks', {
        claims: mockKidUser,
      });

      ddbMock.on(ScanCommand).resolves({
        Items: [mockTask],
        Count: 1,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(200);

      const body = JSON.parse(response.body);
      expect(body.items).toHaveLength(1);
      expect(body.items[0].taskId).toBe(mockTask.taskId);
    });

    it('should filter tasks by status and date range', async () => {
      const mockEvent = createMockEvent('GET', '/tasks', {
        claims: mockParentUser,
        queryStringParameters: {
          status: 'pending',
          fromDate: '2024-01-01',
          toDate: '2024-12-31',
        },
      });

      ddbMock.on(ScanCommand).resolves({
        Items: [mockTask],
        Count: 1,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(200);
    });

    it('should handle empty result set', async () => {
      const mockEvent = createMockEvent('GET', '/tasks', {
        claims: mockKidUser,
      });

      ddbMock.on(ScanCommand).resolves({
        Items: [],
        Count: 0,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(200);

      const body = JSON.parse(response.body);
      expect(body.items).toHaveLength(0);
      expect(body.count).toBe(0);
    });
  });

  describe('GET /tasks/{taskId}', () => {
    it('should get a specific task', async () => {
      const mockEvent = createMockEvent('GET', '/tasks/test-task-id', {
        pathParameters: { taskId: 'test-task-id' },
        claims: mockParentUser,
      });

      ddbMock.on(GetCommand).resolves({
        Item: mockTask,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(200);

      const body = JSON.parse(response.body);
      expect(body.taskId).toBe(mockTask.taskId);
    });

    it('should return 404 for non-existent task', async () => {
      const mockEvent = createMockEvent('GET', '/tasks/non-existent', {
        pathParameters: { taskId: 'non-existent' },
        claims: mockParentUser,
      });

      ddbMock.on(GetCommand).resolves({});

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(404);
    });

    it('should prevent kid from accessing other kids tasks', async () => {
      const mockEvent = createMockEvent('GET', '/tasks/test-task-id', {
        pathParameters: { taskId: 'test-task-id' },
        claims: { ...mockKidUser, sub: 'other-kid-id' },
      });

      ddbMock.on(GetCommand).resolves({
        Item: mockTask,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(401);
    });
  });

  describe('POST /tasks', () => {
    it('should create a new task', async () => {
      const mockEvent = createMockEvent('POST', '/tasks', {
        body: {
          kidId: 'test-kid-id',
          title: 'New Task',
          description: 'Task Description',
          dueDate: new Date().toISOString(),
        },
        claims: mockParentUser,
      });

      ddbMock.on(QueryCommand).resolves({ Items: [] });
      ddbMock.on(PutCommand).resolves({});

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(201);

      const body = JSON.parse(response.body);
      expect(body.title).toBe('New Task');
      expect(body.status).toBe('pending');
    });

    it('should prevent kids from creating tasks', async () => {
      const mockEvent = createMockEvent('POST', '/tasks', {
        body: {
          kidId: 'test-kid-id',
          title: 'New Task',
          description: 'Task Description',
          dueDate: new Date().toISOString(),
        },
        claims: mockKidUser,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(401);
    });

    it('should validate task input', async () => {
      const mockEvent = createMockEvent('POST', '/tasks', {
        body: {
          kidId: 'test-kid-id',
          title: '', // Invalid: empty title
          description: 'Task Description',
          dueDate: 'invalid-date', // Invalid date format
        },
        claims: mockParentUser,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(400);
    });
  });

  describe('PUT /tasks/{taskId}', () => {
    it('should update task status', async () => {
      const mockEvent = createMockEvent('PUT', '/tasks/test-task-id', {
        pathParameters: { taskId: 'test-task-id' },
        body: {
          status: 'completed' as TaskStatus,
        },
        claims: mockKidUser,
      });

      ddbMock.on(GetCommand).resolves({
        Item: { ...mockTask, kidId: mockKidUser.sub },
      });

      ddbMock.on(UpdateCommand).resolves({
        Attributes: { ...mockTask, status: 'completed' },
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(200);

      const body = JSON.parse(response.body);
      expect(body.status).toBe('completed');
    });

    it('should validate status transitions', async () => {
      const mockEvent = createMockEvent('PUT', '/tasks/test-task-id', {
        pathParameters: { taskId: 'test-task-id' },
        body: {
          status: 'approved' as TaskStatus, // Invalid: kid cannot approve
        },
        claims: mockKidUser,
      });

      ddbMock.on(GetCommand).resolves({
        Item: { ...mockTask, kidId: mockKidUser.sub },
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(400);
    });
  });

  describe('POST /tasks/upload-url', () => {
    it('should generate upload URL for task photo', async () => {
      const mockEvent = createMockEvent('POST', '/tasks/upload-url', {
        body: {
          taskId: 'test-task-id',
          contentType: 'image/jpeg',
        },
        claims: mockKidUser,
      });

      ddbMock.on(GetCommand).resolves({
        Item: { ...mockTask, kidId: mockKidUser.sub },
      });

      s3Mock.on(PutObjectCommand).resolves({});

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(200);

      const body = JSON.parse(response.body);
      expect(body.uploadUrl).toBeDefined();
      expect(body.key).toBeDefined();
    });

    it('should validate content type', async () => {
      const mockEvent = createMockEvent('POST', '/tasks/upload-url', {
        body: {
          taskId: 'test-task-id',
          contentType: 'application/pdf', // Invalid content type
        },
        claims: mockKidUser,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(400);
    });
  });

  describe('DELETE /tasks/{taskId}', () => {
    it('should delete a task', async () => {
      const mockEvent = createMockEvent('DELETE', '/tasks/test-task-id', {
        pathParameters: { taskId: 'test-task-id' },
        claims: mockParentUser,
      });

      ddbMock.on(DeleteCommand).resolves({});

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(204);
    });

    it('should prevent kids from deleting tasks', async () => {
      const mockEvent = createMockEvent('DELETE', '/tasks/test-task-id', {
        pathParameters: { taskId: 'test-task-id' },
        claims: mockKidUser,
      });

      const response = await handler(mockEvent);
      expect(response.statusCode).toBe(401);
    });
  });
}); 