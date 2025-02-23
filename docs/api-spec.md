# API Specification

## Base URL

```
https://api.daily-tasks.yourdomain.com/v1
```

## Authentication

All API requests must include a valid JWT token in the Authorization header:

```
Authorization: Bearer <token>
```

## Endpoints

### Authentication

#### POST /auth/register
Register a new user (parent or kid)

**Request**
```typescript
interface RegisterRequest {
  email: string;
  password: string;
  role: 'parent' | 'kid';
  parentId?: string;  // Required for kid accounts
}
```

**Response**
```typescript
interface RegisterResponse {
  userId: string;
  email: string;
  role: 'parent' | 'kid';
  confirmationRequired: boolean;
}
```

#### POST /auth/confirm
Confirm user registration

**Request**
```typescript
interface ConfirmRequest {
  email: string;
  code: string;
}
```

**Response**
```typescript
interface ConfirmResponse {
  success: boolean;
}
```

#### POST /auth/login
Authenticate user

**Request**
```typescript
interface LoginRequest {
  email: string;
  password: string;
}
```

**Response**
```typescript
interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: {
    userId: string;
    email: string;
    role: 'parent' | 'kid';
  };
}
```

### Tasks

#### GET /tasks
List tasks for the authenticated user

**Query Parameters**
```typescript
interface TasksQuery {
  status?: 'pending' | 'completed' | 'approved' | 'rejected';
  kidId?: string;  // For parent users
  fromDate?: string;
  toDate?: string;
  limit?: number;
  nextToken?: string;
}
```

**Response**
```typescript
interface TasksResponse {
  items: Array<{
    taskId: string;
    title: string;
    description: string;
    status: 'pending' | 'completed' | 'approved' | 'rejected';
    photoUrl?: string;
    parentComment?: string;
    dueDate: string;
    createdAt: string;
    updatedAt: string;
  }>;
  nextToken?: string;
}
```

#### POST /tasks
Create a new task

**Request**
```typescript
interface CreateTaskRequest {
  kidId: string;
  title: string;
  description: string;
  dueDate: string;
}
```

**Response**
```typescript
interface Task {
  taskId: string;
  kidId: string;
  title: string;
  description: string;
  status: 'pending';
  dueDate: string;
  createdAt: string;
  updatedAt: string;
}
```

#### PUT /tasks/{taskId}
Update a task

**Request**
```typescript
interface UpdateTaskRequest {
  title?: string;
  description?: string;
  dueDate?: string;
  status?: 'completed';  // Kids can only mark as completed
  photoUrl?: string;
  parentComment?: string;  // Parents only
}
```

**Response**
```typescript
interface Task {
  // Same as Task interface above
}
```

#### DELETE /tasks/{taskId}
Delete a task (parents only)

**Response**
```typescript
interface DeleteResponse {
  success: boolean;
}
```

### Photos

#### POST /photos/upload-url
Get pre-signed URL for photo upload

**Request**
```typescript
interface UploadUrlRequest {
  taskId: string;
  contentType: string;
}
```

**Response**
```typescript
interface UploadUrlResponse {
  uploadUrl: string;
  photoUrl: string;
  expiresIn: number;
}
```

### Devices

#### GET /devices
List registered devices

**Query Parameters**
```typescript
interface DevicesQuery {
  kidId?: string;  // Required for parent users
}
```

**Response**
```typescript
interface DevicesResponse {
  items: Array<{
    kidId: string;
    macAddress: string;
    deviceName: string;
    deviceType: 'ps4' | 'tablet' | 'other';
    isBlocked: boolean;
    lastUpdated: string;
  }>;
}
```

#### POST /devices
Register a new device

**Request**
```typescript
interface RegisterDeviceRequest {
  kidId: string;
  macAddress: string;
  deviceName: string;
  deviceType: 'ps4' | 'tablet' | 'other';
}
```

**Response**
```typescript
interface Device {
  kidId: string;
  macAddress: string;
  deviceName: string;
  deviceType: 'ps4' | 'tablet' | 'other';
  isBlocked: boolean;
  lastUpdated: string;
}
```

#### PUT /devices/{macAddress}
Update device status

**Request**
```typescript
interface UpdateDeviceRequest {
  isBlocked: boolean;
}
```

**Response**
```typescript
interface Device {
  // Same as Device interface above
}
```

### Network Control (Raspberry Pi)

#### POST /network/allow
Allow device access

**Request**
```typescript
interface AllowDeviceRequest {
  macAddress: string;
}
```

**Response**
```typescript
interface NetworkResponse {
  success: boolean;
  message: string;
}
```

#### POST /network/block
Block device access

**Request**
```typescript
interface BlockDeviceRequest {
  macAddress: string;
}
```

**Response**
```typescript
interface NetworkResponse {
  success: boolean;
  message: string;
}
```

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```typescript
interface BadRequestError {
  code: 'BAD_REQUEST';
  message: string;
  details?: any;
}
```

### 401 Unauthorized
```typescript
interface UnauthorizedError {
  code: 'UNAUTHORIZED';
  message: string;
}
```

### 403 Forbidden
```typescript
interface ForbiddenError {
  code: 'FORBIDDEN';
  message: string;
}
```

### 404 Not Found
```typescript
interface NotFoundError {
  code: 'NOT_FOUND';
  message: string;
}
```

### 500 Internal Server Error
```typescript
interface ServerError {
  code: 'SERVER_ERROR';
  message: string;
  requestId: string;
}
```

## Rate Limiting

- API requests are limited to 100 requests per minute per user
- Photo upload URLs are limited to 50 requests per hour per user
- Network control commands are limited to 10 requests per minute per device

## Versioning

The API uses semantic versioning in the URL path. Breaking changes will result in a new major version number. 