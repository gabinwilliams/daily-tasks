import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { DynamoDB } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocument } from '@aws-sdk/lib-dynamodb';
import {
  CognitoIdentityProviderClient,
  AdminCreateUserCommand,
  AdminInitiateAuthCommand,
  AdminRespondToAuthChallengeCommand,
  AdminSetUserPasswordCommand,
  AuthFlowType,
} from '@aws-sdk/client-cognito-identity-provider';
import { z } from 'zod';
import {
  createResponse,
  createErrorResponse,
  validateRequest,
  normalizeEmail,
  ValidationError,
  AuthorizationError,
} from '../layers/common/nodejs/utils';

// Initialize AWS clients
const cognito = new CognitoIdentityProviderClient({});
const dynamodb = DynamoDBDocument.from(new DynamoDB({}));

// Environment variables
const USER_POOL_ID = process.env.USER_POOL_ID!;
const CLIENT_ID = process.env.CLIENT_ID!;
const USERS_TABLE = process.env.USERS_TABLE!;

// Request schemas
const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  role: z.enum(['parent', 'kid']),
  parentId: z.string().uuid().optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

const confirmSchema = z.object({
  email: z.string().email(),
  code: z.string(),
});

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    const path = event.path.replace('/auth/', '');
    const body = event.body ? JSON.parse(event.body) : {};

    switch (path) {
      case 'register':
        return handleRegister(body);
      case 'login':
        return handleLogin(body);
      case 'confirm':
        return handleConfirm(body);
      default:
        return createErrorResponse(404, 'Route not found');
    }
  } catch (error) {
    console.error('Error:', error);
    if (error instanceof ValidationError) {
      return createErrorResponse(400, error.message);
    }
    if (error instanceof AuthorizationError) {
      return createErrorResponse(401, error.message);
    }
    return createErrorResponse(500, 'Internal server error');
  }
};

async function handleRegister(body: any): Promise<APIGatewayProxyResult> {
  const validation = validateRequest(registerSchema, body);
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  const { email, password, role, parentId } = validation.data;
  const normalizedEmail = normalizeEmail(email);

  // Validate parent ID for kid accounts
  if (role === 'kid' && !parentId) {
    return createErrorResponse(400, 'Parent ID is required for kid accounts');
  }

  // Check if parent exists for kid accounts
  if (role === 'kid') {
    const parent = await dynamodb.get({
      TableName: USERS_TABLE,
      Key: { userId: parentId },
    });

    if (!parent.Item || parent.Item.role !== 'parent') {
      return createErrorResponse(400, 'Invalid parent ID');
    }
  }

  try {
    // Create user in Cognito
    await cognito.send(
      new AdminCreateUserCommand({
        UserPoolId: USER_POOL_ID,
        Username: normalizedEmail,
        UserAttributes: [
          { Name: 'email', Value: normalizedEmail },
          { Name: 'email_verified', Value: 'true' },
          { Name: 'custom:role', Value: role },
        ],
        TemporaryPassword: password,
      })
    );

    // Set permanent password
    await cognito.send(
      new AdminSetUserPasswordCommand({
        UserPoolId: USER_POOL_ID,
        Username: normalizedEmail,
        Password: password,
        Permanent: true,
      })
    );

    // Store user in DynamoDB
    const userId = Date.now().toString(36) + Math.random().toString(36).substr(2);
    await dynamodb.put({
      TableName: USERS_TABLE,
      Item: {
        userId,
        email: normalizedEmail,
        role,
        parentId: role === 'kid' ? parentId : null,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    });

    return createResponse(201, {
      message: 'User registered successfully',
      userId,
    });
  } catch (error) {
    console.error('Registration error:', error);
    return createErrorResponse(500, 'Failed to register user');
  }
}

async function handleLogin(body: any): Promise<APIGatewayProxyResult> {
  const validation = validateRequest(loginSchema, body);
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  const { email, password } = validation.data;
  const normalizedEmail = normalizeEmail(email);

  try {
    // Authenticate user
    const authResponse = await cognito.send(
      new AdminInitiateAuthCommand({
        UserPoolId: USER_POOL_ID,
        ClientId: CLIENT_ID,
        AuthFlow: AuthFlowType.ADMIN_USER_PASSWORD_AUTH,
        AuthParameters: {
          USERNAME: normalizedEmail,
          PASSWORD: password,
        },
      })
    );

    if (authResponse.ChallengeName) {
      // Handle auth challenges if needed
      return createErrorResponse(400, 'Password change required');
    }

    if (!authResponse.AuthenticationResult) {
      return createErrorResponse(401, 'Authentication failed');
    }

    // Get user from DynamoDB
    const user = await dynamodb.get({
      TableName: USERS_TABLE,
      Key: { email: normalizedEmail },
    });

    if (!user.Item) {
      return createErrorResponse(404, 'User not found');
    }

    return createResponse(200, {
      token: authResponse.AuthenticationResult.AccessToken,
      refreshToken: authResponse.AuthenticationResult.RefreshToken,
      expiresIn: authResponse.AuthenticationResult.ExpiresIn,
      user: {
        userId: user.Item.userId,
        email: user.Item.email,
        role: user.Item.role,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    return createErrorResponse(401, 'Invalid credentials');
  }
}

async function handleConfirm(body: any): Promise<APIGatewayProxyResult> {
  const validation = validateRequest(confirmSchema, body);
  if (!validation.success) {
    return createErrorResponse(400, validation.error);
  }

  const { email, code } = validation.data;
  const normalizedEmail = normalizeEmail(email);

  try {
    // Verify confirmation code
    await cognito.send(
      new AdminRespondToAuthChallengeCommand({
        UserPoolId: USER_POOL_ID,
        ClientId: CLIENT_ID,
        ChallengeName: 'NEW_PASSWORD_REQUIRED',
        ChallengeResponses: {
          USERNAME: normalizedEmail,
          NEW_PASSWORD: code,
        },
      })
    );

    return createResponse(200, {
      message: 'Email confirmed successfully',
    });
  } catch (error) {
    console.error('Confirmation error:', error);
    return createErrorResponse(400, 'Invalid confirmation code');
  }
} 