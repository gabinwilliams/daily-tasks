import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDB } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocument, UpdateCommandInput } from '@aws-sdk/lib-dynamodb';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { z } from 'zod';
import {
  createResponse,
  createErrorResponse,
  validateRequest,
  verifyToken,
  generateId,
  isValidTaskStatus,
  canUpdateTaskStatus,
  generatePhotoKey,
  isValidPhotoType,
  ValidationError,
  AuthorizationError,
  NotFoundError,
  TaskStatus,
} from '../layers/common/nodejs/utils';
import {
  Task,
  CreateTaskInput,
  UpdateTaskInput,
  TaskQueryParams,
  UploadPhotoInput,
  TaskStats,
  TimeRange,
  DailyStats,
} from '../../types/task';

// Initialize AWS clients
const dynamodb = DynamoDBDocument.from(new DynamoDB({}));
const s3 = new S3Client({});

// Environment variables
const TASKS_TABLE = process.env.TASKS_TABLE!;
const PHOTOS_BUCKET = process.env.PHOTOS_BUCKET!;
const USER_POOL_ID = process.env.USER_POOL_ID!;
const CLIENT_ID = process.env.CLIENT_ID!;
const MAX_TASKS_PER_KID = 50;

// Request schemas
const createTaskSchema = z.object({
  kidId: z.string(),
  title: z.string().min(1).max(100),
  description: z.string().max(500),
  dueDate: z.string().datetime(),
});

const updateTaskSchema = z.object({
  title: z.string().min(1).max(100).optional(),
  description: z.string().max(500).optional(),
  status: z.enum(['completed', 'approved', 'rejected']).optional(),
  photoUrl: z.string().url().optional(),
  parentComment: z.string().max(500).optional(),
});

const uploadPhotoSchema = z.object({
  taskId: z.string(),
  contentType: z.string(),
});

const listTasksSchema = z.object({
  limit: z.coerce.number().min(1).max(100).default(20),
  nextToken: z.string().optional(),
  kidId: z.string().optional(),
  status: z.enum(['pending', 'completed', 'approved', 'rejected']).optional(),
  fromDate: z.string().datetime().optional(),
  toDate: z.string().datetime().optional(),
});

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    // Verify authentication
    const user = await verifyToken(event, USER_POOL_ID, CLIENT_ID);
    if (!user) {
      return createErrorResponse(401, 'Unauthorized');
    }

    const method = event.httpMethod;
    const taskId = event.pathParameters?.taskId;
    const body = event.body ? JSON.parse(event.body) : {};

    switch (method) {
      case 'GET':
        if (event.path.endsWith('/stats')) {
          return getTaskStats(event, user);
        }
        if (taskId) {
          return getTask(taskId, user);
        }
        return listTasks(event, user);
      case 'POST':
        if (event.path.endsWith('/upload-url')) {
          return getUploadUrl(body, user);
        }
        return createTask(body, user);
      case 'PUT':
        if (!taskId) {
          return createErrorResponse(400, 'Task ID is required');
        }
        return updateTask(taskId, body, user);
      case 'DELETE':
        if (!taskId) {
          return createErrorResponse(400, 'Task ID is required');
        }
        return deleteTask(taskId, user);
      default:
        return createErrorResponse(405, 'Method not allowed');
    }
  } catch (error) {
    console.error('Error:', error);
    if (error instanceof ValidationError) {
      return createErrorResponse(400, error.message);
    }
    if (error instanceof AuthorizationError) {
      return createErrorResponse(401, error.message);
    }
    if (error instanceof NotFoundError) {
      return createErrorResponse(404, error.message);
    }
    return createErrorResponse(500, 'Internal server error');
  }
};

async function listTasks(
  event: APIGatewayProxyEvent,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  const validation = validateRequest(listTasksSchema, event.queryStringParameters || {});
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  const { limit, nextToken, kidId, status, fromDate, toDate } = validation.data;

  let filterExpression = '';
  const expressionValues: Record<string, any> = {};

  if (user.role === 'kid') {
    filterExpression = 'kidId = :kidId';
    expressionValues[':kidId'] = user.userId;
  } else if (kidId) {
    filterExpression = 'kidId = :kidId';
    expressionValues[':kidId'] = kidId;
  }

  if (status && isValidTaskStatus(status)) {
    filterExpression += filterExpression ? ' AND ' : '';
    filterExpression += 'status = :status';
    expressionValues[':status'] = status;
  }

  if (fromDate) {
    filterExpression += filterExpression ? ' AND ' : '';
    filterExpression += 'dueDate >= :fromDate';
    expressionValues[':fromDate'] = fromDate;
  }

  if (toDate) {
    filterExpression += filterExpression ? ' AND ' : '';
    filterExpression += 'dueDate <= :toDate';
    expressionValues[':toDate'] = toDate;
  }

  const queryParams = {
    TableName: TASKS_TABLE,
    FilterExpression: filterExpression || undefined,
    ExpressionAttributeValues: Object.keys(expressionValues).length ? expressionValues : undefined,
    Limit: limit,
    ExclusiveStartKey: nextToken
      ? JSON.parse(Buffer.from(nextToken, 'base64').toString())
      : undefined,
  };

  const result = await dynamodb.scan(queryParams);

  const response = {
    items: result.Items || [],
    count: result.Count || 0,
    nextToken: result.LastEvaluatedKey
      ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
      : undefined,
  };

  return createResponse(200, response);
}

async function getTask(
  taskId: string,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  const task = await dynamodb.get({
    TableName: TASKS_TABLE,
    Key: { taskId },
  });

  if (!task.Item) {
    throw new NotFoundError('Task not found');
  }

  if (user.role === 'kid' && task.Item.kidId !== user.userId) {
    throw new AuthorizationError('Not authorized to view this task');
  }

  return createResponse(200, task.Item);
}

async function createTask(
  body: CreateTaskInput,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  if (user.role !== 'parent') {
    throw new AuthorizationError('Only parents can create tasks');
  }

  const validation = validateRequest(createTaskSchema, body);
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  const { kidId } = validation.data;

  // Check task limit
  const existingTasks = await dynamodb.query({
    TableName: TASKS_TABLE,
    KeyConditionExpression: 'kidId = :kidId',
    ExpressionAttributeValues: { ':kidId': kidId },
  });

  if ((existingTasks.Items?.length || 0) >= MAX_TASKS_PER_KID) {
    return createErrorResponse(400, `Maximum ${MAX_TASKS_PER_KID} tasks allowed per kid`);
  }

  const task: Task = {
    taskId: generateId(),
    ...validation.data,
    status: 'pending',
    createdBy: user.userId,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  await dynamodb.put({
    TableName: TASKS_TABLE,
    Item: task,
  });

  return createResponse(201, task);
}

async function updateTask(
  taskId: string,
  body: UpdateTaskInput,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  const validation = validateRequest(updateTaskSchema, body);
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  // Get existing task
  const existingTask = await dynamodb.get({
    TableName: TASKS_TABLE,
    Key: { taskId },
  });

  if (!existingTask.Item) {
    throw new NotFoundError('Task not found');
  }

  if (user.role === 'kid' && existingTask.Item.kidId !== user.userId) {
    throw new AuthorizationError('Not authorized to update this task');
  }

  const updates = validation.data;

  // Validate status update
  if (updates.status) {
    if (!canUpdateTaskStatus(existingTask.Item.status, updates.status as TaskStatus, user.role)) {
      throw new ValidationError('Invalid status transition');
    }
  }

  // Build update expression
  let updateExpression = 'SET updatedAt = :updatedAt';
  const expressionValues: Record<string, any> = {
    ':updatedAt': new Date().toISOString(),
  };

  Object.entries(updates).forEach(([key, value]) => {
    updateExpression += `, #${key} = :${key}`;
    expressionValues[`:${key}`] = value;
  });

  const updateParams: UpdateCommandInput = {
    TableName: TASKS_TABLE,
    Key: { taskId },
    UpdateExpression: updateExpression,
    ExpressionAttributeValues: expressionValues,
    ExpressionAttributeNames: Object.fromEntries(Object.keys(updates).map(key => [`#${key}`, key])),
    ReturnValues: 'ALL_NEW',
  };

  const result = await dynamodb.update(updateParams);
  return createResponse(200, result.Attributes || {});
}

async function deleteTask(
  taskId: string,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  if (user.role !== 'parent') {
    throw new AuthorizationError('Only parents can delete tasks');
  }

  await dynamodb.delete({
    TableName: TASKS_TABLE,
    Key: { taskId },
  });

  return createResponse(204, {});
}

async function getUploadUrl(
  body: UploadPhotoInput,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  const validation = validateRequest(uploadPhotoSchema, body);
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  const { taskId, contentType } = validation.data;

  if (!isValidPhotoType(contentType)) {
    return createErrorResponse(400, 'Invalid content type');
  }

  // Get task to verify permissions
  const task = await dynamodb.get({
    TableName: TASKS_TABLE,
    Key: { taskId },
  });

  if (!task.Item) {
    throw new NotFoundError('Task not found');
  }

  if (user.role === 'kid' && task.Item.kidId !== user.userId) {
    throw new AuthorizationError('Not authorized to upload photo for this task');
  }

  const key = generatePhotoKey(taskId, user.userId);
  const command = new PutObjectCommand({
    Bucket: PHOTOS_BUCKET,
    Key: key,
    ContentType: contentType,
  });

  const signedUrl = await getSignedUrl(s3, command, { expiresIn: 3600 });

  return createResponse(200, { uploadUrl: signedUrl, key });
}

async function getTaskStats(
  event: APIGatewayProxyEvent,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  const querySchema = z.object({
    timeRange: z.enum(['week', 'month', 'year'] as const).default('week'),
    kidId: z.string().optional(),
  });

  const params = event.queryStringParameters || {};
  const validation = validateRequest(querySchema, params);

  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  const { timeRange, kidId } = validation.data;

  // Calculate date range
  const now = new Date();
  const startDate = new Date();
  switch (timeRange) {
    case 'week':
      startDate.setDate(now.getDate() - 7);
      break;
    case 'month':
      startDate.setMonth(now.getMonth() - 1);
      break;
    case 'year':
      startDate.setFullYear(now.getFullYear() - 1);
      break;
  }

  // Build query parameters
  const dbQueryParams = {
    TableName: TASKS_TABLE,
    IndexName: 'byCreatedAt',
    KeyConditionExpression: 'createdAt >= :startDate',
    ExpressionAttributeValues: {
      ':startDate': startDate.toISOString(),
    },
  } as const;

  // Add kidId filter if provided
  const filterExpressions: string[] = [];
  const expressionValues: Record<string, any> = {
    ':startDate': startDate.toISOString(),
  };

  if (kidId) {
    filterExpressions.push('kidId = :kidId');
    expressionValues[':kidId'] = kidId;
  }

  // Add role-based filtering
  if (user.role === 'kid') {
    filterExpressions.push('kidId = :userId');
    expressionValues[':userId'] = user.userId;
  }

  const queryParams = {
    ...dbQueryParams,
    ...(filterExpressions.length > 0 && {
      FilterExpression: filterExpressions.join(' AND '),
      ExpressionAttributeValues: expressionValues,
    }),
  };

  try {
    const result = await dynamodb.query(queryParams);
    const tasks = result.Items || [];

    // Calculate statistics
    const stats: TaskStats = {
      totalTasks: tasks.length,
      completedTasks: tasks.filter(t => t.status === 'completed' || t.status === 'approved').length,
      approvedTasks: tasks.filter(t => t.status === 'approved').length,
      rejectedTasks: tasks.filter(t => t.status === 'rejected').length,
      pendingTasks: tasks.filter(t => t.status === 'pending').length,
      completionRate: 0,
      approvalRate: 0,
      averageResponseTime: 0,
      dailyStats: [],
    };

    // Calculate rates
    if (stats.totalTasks > 0) {
      stats.completionRate = stats.completedTasks / stats.totalTasks;
      stats.approvalRate = stats.approvedTasks / stats.totalTasks;
    }

    // Calculate average response time (time between completion and approval/rejection)
    const responseTimes = tasks
      .filter(t => t.status === 'approved' || t.status === 'rejected')
      .map(t => {
        const completedAt = new Date(
          t.statusHistory?.find((h: { status: TaskStatus }) => h.status === 'completed')?.timestamp || t.createdAt
        );
        const respondedAt = new Date(t.updatedAt);
        return respondedAt.getTime() - completedAt.getTime();
      });

    if (responseTimes.length > 0) {
      stats.averageResponseTime = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;
    }

    // Calculate daily stats
    const dailyMap = new Map<string, DailyStats>();

    tasks.forEach(task => {
      const date = task.createdAt.split('T')[0];
      const daily = dailyMap.get(date) || {
        date,
        totalTasks: 0,
        completedTasks: 0,
        approvedTasks: 0,
      };

      daily.totalTasks++;
      if (task.status === 'completed' || task.status === 'approved') daily.completedTasks++;
      if (task.status === 'approved') daily.approvedTasks++;

      dailyMap.set(date, daily);
    });

    stats.dailyStats = Array.from(dailyMap.values()).sort((a, b) => a.date.localeCompare(b.date));

    return createResponse(200, stats);
  } catch (error) {
    console.error('Error fetching task statistics:', error);
    return createErrorResponse(500, 'Error fetching task statistics');
  }
} 