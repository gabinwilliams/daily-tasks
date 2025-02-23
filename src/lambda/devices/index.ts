import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDB } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocument } from '@aws-sdk/lib-dynamodb';
import { z } from 'zod';
import {
  createResponse,
  createErrorResponse,
  validateRequest,
  verifyToken,
  deviceSchema,
  isValidMacAddress,
  MAX_DEVICES_PER_KID,
  ValidationError,
  AuthorizationError,
  NotFoundError,
} from '../layers/common/nodejs/utils';

// Initialize AWS clients
const dynamodb = DynamoDBDocument.from(new DynamoDB({}));

// Environment variables
const DEVICES_TABLE = process.env.DEVICES_TABLE!;
const USER_POOL_ID = process.env.USER_POOL_ID!;
const CLIENT_ID = process.env.CLIENT_ID!;

// Request schemas
const updateDeviceSchema = z.object({
  deviceName: z.string().min(1).max(50).optional(),
  deviceType: z.enum(['ps4', 'tablet', 'other']).optional(),
  isBlocked: z.boolean().optional(),
});

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    // Verify authentication
    const user = await verifyToken(event, USER_POOL_ID, CLIENT_ID);
    if (!user) {
      return createErrorResponse(401, 'Unauthorized');
    }

    const method = event.httpMethod;
    const macAddress = event.pathParameters?.macAddress;
    const body = event.body ? JSON.parse(event.body) : {};

    switch (method) {
      case 'GET':
        return listDevices(event, user);
      case 'POST':
        return registerDevice(body, user);
      case 'PUT':
        if (!macAddress) {
          return createErrorResponse(400, 'MAC address is required');
        }
        return updateDevice(macAddress, body, user);
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

async function listDevices(
  event: APIGatewayProxyEvent,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  const { kidId } = event.queryStringParameters || {};

  if (user.role === 'kid') {
    // Kids can only see their own devices
    const devices = await dynamodb.query({
      TableName: DEVICES_TABLE,
      KeyConditionExpression: 'kidId = :kidId',
      ExpressionAttributeValues: {
        ':kidId': user.userId,
      },
    });

    return createResponse(200, {
      items: devices.Items || [],
      count: devices.Count,
    });
  } else {
    // Parents can see all devices or filter by kidId
    if (kidId) {
      const devices = await dynamodb.query({
        TableName: DEVICES_TABLE,
        KeyConditionExpression: 'kidId = :kidId',
        ExpressionAttributeValues: {
          ':kidId': kidId,
        },
      });

      return createResponse(200, {
        items: devices.Items || [],
        count: devices.Count,
      });
    } else {
      const devices = await dynamodb.scan({
        TableName: DEVICES_TABLE,
      });

      return createResponse(200, {
        items: devices.Items || [],
        count: devices.Count,
      });
    }
  }
}

async function registerDevice(
  body: any,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  const validation = validateRequest(deviceSchema, body);
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  const { kidId, macAddress, deviceName, deviceType } = validation.data;

  // Validate MAC address format
  if (!isValidMacAddress(macAddress)) {
    return createErrorResponse(400, 'Invalid MAC address format');
  }

  // Check if device already exists
  const existingDevice = await dynamodb.get({
    TableName: DEVICES_TABLE,
    Key: {
      kidId,
      macAddress,
    },
  });

  if (existingDevice.Item) {
    return createErrorResponse(409, 'Device already registered');
  }

  // Check device limit per kid
  const existingDevices = await dynamodb.query({
    TableName: DEVICES_TABLE,
    KeyConditionExpression: 'kidId = :kidId',
    ExpressionAttributeValues: {
      ':kidId': kidId,
    },
  });

  if ((existingDevices.Items?.length || 0) >= MAX_DEVICES_PER_KID) {
    return createErrorResponse(
      400,
      `Maximum ${MAX_DEVICES_PER_KID} devices allowed per kid`
    );
  }

  // Create device record
  const device = {
    kidId,
    macAddress,
    deviceName,
    deviceType,
    isBlocked: true, // Initially blocked
    createdBy: user.userId,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  await dynamodb.put({
    TableName: DEVICES_TABLE,
    Item: device,
  });

  return createResponse(201, device);
}

async function updateDevice(
  macAddress: string,
  body: any,
  user: { userId: string; role: string }
): Promise<APIGatewayProxyResult> {
  const validation = validateRequest(updateDeviceSchema, body);
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  // Only parents can update device status
  if (user.role !== 'parent') {
    throw new AuthorizationError('Only parents can update devices');
  }

  // Get existing device
  const { kidId } = event.queryStringParameters || {};
  if (!kidId) {
    return createErrorResponse(400, 'Kid ID is required');
  }

  const existingDevice = await dynamodb.get({
    TableName: DEVICES_TABLE,
    Key: {
      kidId,
      macAddress,
    },
  });

  if (!existingDevice.Item) {
    throw new NotFoundError('Device not found');
  }

  const updates = validation.data;

  // Build update expression
  const updateExpr: string[] = [];
  const exprValues: Record<string, any> = {};
  const exprNames: Record<string, string> = {};

  Object.entries(updates).forEach(([key, value]) => {
    updateExpr.push(`#${key} = :${key}`);
    exprValues[`:${key}`] = value;
    exprNames[`#${key}`] = key;
  });

  updateExpr.push('#updatedAt = :updatedAt');
  exprValues[':updatedAt'] = new Date().toISOString();
  exprNames['#updatedAt'] = 'updatedAt';

  await dynamodb.update({
    TableName: DEVICES_TABLE,
    Key: {
      kidId,
      macAddress,
    },
    UpdateExpression: `SET ${updateExpr.join(', ')}`,
    ExpressionAttributeValues: exprValues,
    ExpressionAttributeNames: exprNames,
  });

  const updatedDevice = await dynamodb.get({
    TableName: DEVICES_TABLE,
    Key: {
      kidId,
      macAddress,
    },
  });

  return createResponse(200, updatedDevice.Item);
} 