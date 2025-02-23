import { handler } from './index';
import { 
  DynamoDBClient, 
  ScanCommand, 
  GetItemCommand, 
  PutItemCommand, 
  DeleteItemCommand, 
  UpdateItemCommand,
  AttributeValue
} from '@aws-sdk/client-dynamodb';
import { mockClient } from 'aws-sdk-client-mock';
import { createMockEvent, createMockTask } from '../../test/setup';

describe('Tasks Lambda Function', () => {
  const ddbMock = mockClient(DynamoDBClient);

  beforeEach(() => {
    ddbMock.reset();
  });

  const mockTaskToAttributeValues = (task: any): Record<string, AttributeValue> => ({
    taskId: { S: task.taskId },
    kidId: { S: task.kidId },
    title: { S: task.title },
    description: { S: task.description },
    status: { S: task.status },
    dueDate: { S: task.dueDate },
    createdAt: { S: task.createdAt },
    updatedAt: { S: task.updatedAt },
    ...(task.photoUrl ? { photoUrl: { S: task.photoUrl } } : {}),
    ...(task.parentComment ? { parentComment: { S: task.parentComment } } : {})
  });

  describe('GET /tasks', () => {
    it('should list tasks for a kid', async () => {
      const tasks = [createMockTask(), createMockTask()];
      const mockTasks = tasks.map(mockTaskToAttributeValues);
      
      ddbMock.on(ScanCommand).resolves({
        Items: mockTasks,
        Count: mockTasks.length,
      });

      const event = createMockEvent('GET', '/tasks', null, undefined, undefined);
      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.body)).toEqual({
        items: mockTasks,
        count: mockTasks.length,
      });
    });

    it('should filter tasks by status', async () => {
      const task = createMockTask({ status: 'completed' });
      const mockTask = mockTaskToAttributeValues(task);
      
      ddbMock.on(ScanCommand).resolves({
        Items: [mockTask],
        Count: 1,
      });

      const event = createMockEvent('GET', '/tasks', null, { status: 'completed' }, undefined);
      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.body)).toEqual({
        items: [mockTask],
        count: 1,
      });
    });
  });

  describe('POST /tasks', () => {
    it('should create a new task', async () => {
      const taskData = {
        kidId: 'test-kid-id',
        title: 'New Task',
        description: 'Task Description',
        dueDate: '2024-03-20',
      };

      ddbMock.on(ScanCommand).resolves({
        Items: [],
        Count: 0,
      });

      ddbMock.on(PutItemCommand).resolves({});

      const event = createMockEvent('POST', '/tasks', taskData);
      const response = await handler(event);

      expect(response.statusCode).toBe(201);
      const body = JSON.parse(response.body);
      expect(body).toMatchObject({
        ...taskData,
        status: 'pending',
      });
      expect(body.taskId).toBeDefined();
      expect(body.createdAt).toBeDefined();
      expect(body.updatedAt).toBeDefined();
    });

    it('should reject task creation if kid has reached limit', async () => {
      const task = createMockTask();
      const mockTask = mockTaskToAttributeValues(task);
      const mockTasks = Array(10).fill(mockTask);
      
      ddbMock.on(ScanCommand).resolves({
        Items: mockTasks,
        Count: mockTasks.length,
      });

      const event = createMockEvent('POST', '/tasks', {
        kidId: 'test-kid-id',
        title: 'New Task',
        description: 'Task Description',
        dueDate: '2024-03-20',
      });

      const response = await handler(event);

      expect(response.statusCode).toBe(400);
      expect(JSON.parse(response.body)).toEqual({
        error: {
          code: 'ERROR',
          message: 'Maximum 10 tasks allowed per kid',
        },
      });
    });
  });

  describe('PUT /tasks/{taskId}', () => {
    it('should update task status', async () => {
      const task = createMockTask();
      const mockTask = mockTaskToAttributeValues(task);
      const updatedTask = { ...task, status: 'completed' };
      const mockUpdatedTask = mockTaskToAttributeValues(updatedTask);

      ddbMock
        .on(GetItemCommand).resolves({ Item: mockTask })
        .on(UpdateItemCommand).resolves({
          Attributes: mockUpdatedTask,
        });

      const event = createMockEvent(
        'PUT',
        '/tasks/test-task-id',
        { status: 'completed' },
        undefined,
        { taskId: 'test-task-id' }
      );

      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.body)).toMatchObject(mockUpdatedTask);
    });

    it('should reject invalid status updates', async () => {
      const task = createMockTask();
      const mockTask = mockTaskToAttributeValues(task);
      
      ddbMock.on(GetItemCommand).resolves({ Item: mockTask });

      const event = createMockEvent(
        'PUT',
        '/tasks/test-task-id',
        { status: 'invalid' },
        undefined,
        { taskId: 'test-task-id' }
      );

      const response = await handler(event);

      expect(response.statusCode).toBe(400);
      expect(JSON.parse(response.body).error.message).toContain('Invalid');
    });
  });

  describe('DELETE /tasks/{taskId}', () => {
    it('should delete a task', async () => {
      const task = createMockTask();
      const mockTask = mockTaskToAttributeValues(task);
      
      ddbMock
        .on(GetItemCommand).resolves({ Item: mockTask })
        .on(DeleteItemCommand).resolves({});

      const event = createMockEvent(
        'DELETE',
        '/tasks/test-task-id',
        null,
        undefined,
        { taskId: 'test-task-id' }
      );

      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.body)).toEqual({
        message: 'Task deleted successfully',
      });
    });

    it('should return 404 for non-existent task', async () => {
      ddbMock.on(GetItemCommand).resolves({ Item: undefined });

      const event = createMockEvent(
        'DELETE',
        '/tasks/non-existent',
        null,
        undefined,
        { taskId: 'non-existent' }
      );

      const response = await handler(event);

      expect(response.statusCode).toBe(404);
      expect(JSON.parse(response.body).error.message).toBe('Task not found');
    });
  });
}); 