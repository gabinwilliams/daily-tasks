import { handler } from './index';
import { DynamoDB } from '@aws-sdk/client-dynamodb';
import { createMockEvent, createMockTask, createMockUser } from '../../test/setup';

describe('Tasks Lambda Function', () => {
  const mockDynamoDB = DynamoDB as jest.MockedClass<typeof DynamoDB>;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /tasks', () => {
    it('should list tasks for a kid', async () => {
      const mockTasks = [createMockTask(), createMockTask()];
      mockDynamoDB.prototype.send.mockResolvedValueOnce({
        Items: mockTasks,
        Count: mockTasks.length,
      });

      const event = createMockEvent('GET', '/tasks', null, null, null);
      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.body)).toEqual({
        items: mockTasks,
        count: mockTasks.length,
      });
    });

    it('should filter tasks by status', async () => {
      const mockTasks = [createMockTask({ status: 'completed' })];
      mockDynamoDB.prototype.send.mockResolvedValueOnce({
        Items: mockTasks,
        Count: mockTasks.length,
      });

      const event = createMockEvent('GET', '/tasks', null, { status: 'completed' });
      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.body)).toEqual({
        items: mockTasks,
        count: mockTasks.length,
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

      mockDynamoDB.prototype.send.mockResolvedValueOnce({
        Items: [],
        Count: 0,
      });

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
      const mockTasks = Array(10).fill(createMockTask());
      mockDynamoDB.prototype.send.mockResolvedValueOnce({
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
      const mockTask = createMockTask();
      mockDynamoDB.prototype.send
        .mockResolvedValueOnce({ Item: mockTask })
        .mockResolvedValueOnce({})
        .mockResolvedValueOnce({
          Item: { ...mockTask, status: 'completed' },
        });

      const event = createMockEvent(
        'PUT',
        '/tasks/test-task-id',
        { status: 'completed' },
        null,
        { taskId: 'test-task-id' }
      );

      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.body)).toMatchObject({
        ...mockTask,
        status: 'completed',
      });
    });

    it('should reject invalid status updates', async () => {
      const mockTask = createMockTask();
      mockDynamoDB.prototype.send.mockResolvedValueOnce({ Item: mockTask });

      const event = createMockEvent(
        'PUT',
        '/tasks/test-task-id',
        { status: 'invalid' },
        null,
        { taskId: 'test-task-id' }
      );

      const response = await handler(event);

      expect(response.statusCode).toBe(400);
      expect(JSON.parse(response.body).error.message).toContain('Invalid');
    });
  });

  describe('DELETE /tasks/{taskId}', () => {
    it('should delete a task', async () => {
      const mockTask = createMockTask();
      mockDynamoDB.prototype.send
        .mockResolvedValueOnce({ Item: mockTask })
        .mockResolvedValueOnce({});

      const event = createMockEvent(
        'DELETE',
        '/tasks/test-task-id',
        null,
        null,
        { taskId: 'test-task-id' }
      );

      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      expect(JSON.parse(response.body)).toEqual({
        message: 'Task deleted successfully',
      });
    });

    it('should return 404 for non-existent task', async () => {
      mockDynamoDB.prototype.send.mockResolvedValueOnce({ Item: null });

      const event = createMockEvent(
        'DELETE',
        '/tasks/non-existent',
        null,
        null,
        { taskId: 'non-existent' }
      );

      const response = await handler(event);

      expect(response.statusCode).toBe(404);
      expect(JSON.parse(response.body).error.message).toBe('Task not found');
    });
  });
}); 