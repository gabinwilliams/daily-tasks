# System Architecture

## Overview

The Daily Tasks system implements a modern serverless architecture with three main components:
1. iOS Mobile Application
2. AWS Serverless Backend
3. Raspberry Pi Network Controller

## Component Details

### 1. iOS Mobile Application

#### Technology Stack
- Swift 5.x
- SwiftUI for UI components
- Combine framework for reactive programming
- KeychainSwift for secure storage
- SDWebImage for image caching

#### Key Components
- **AuthenticationManager**: Handles user authentication via AWS Cognito
- **TaskManager**: Manages task CRUD operations
- **PhotoUploader**: Handles image compression and S3 uploads
- **NetworkManager**: Manages API communications
- **NotificationHandler**: Manages push notifications

### 2. AWS Serverless Backend

#### Infrastructure (CDK)
```typescript
// Core Infrastructure Stack
- VPC with private subnets
- API Gateway (HTTP API)
- Cognito User Pool
- S3 Bucket (photo storage)
- DynamoDB Tables
- Lambda Functions
- CloudWatch Logs
```

#### DynamoDB Schema

**Users Table**
```typescript
interface User {
  userId: string;        // Partition Key
  email: string;
  role: 'parent' | 'kid';
  parentId?: string;     // For kid accounts
  createdAt: number;
  updatedAt: number;
}
```

**Tasks Table**
```typescript
interface Task {
  taskId: string;       // Partition Key
  kidId: string;        // Sort Key
  title: string;
  description: string;
  status: 'pending' | 'completed' | 'approved' | 'rejected';
  photoUrl?: string;
  parentComment?: string;
  dueDate: number;
  createdAt: number;
  updatedAt: number;
}
```

**Devices Table**
```typescript
interface Device {
  kidId: string;        // Partition Key
  macAddress: string;   // Sort Key
  deviceName: string;
  deviceType: 'ps4' | 'tablet' | 'other';
  isBlocked: boolean;
  lastUpdated: number;
}
```

#### Lambda Functions

1. **Authentication Functions**
   - registerUser
   - confirmUser
   - login
   - refreshToken

2. **Task Management Functions**
   - createTask
   - updateTask
   - deleteTask
   - listTasks
   - approveTask
   - rejectTask

3. **Device Management Functions**
   - registerDevice
   - updateDeviceStatus
   - listDevices
   - toggleDeviceAccess

4. **Photo Management Functions**
   - getPresignedUrl
   - processUploadedPhoto

### 3. Raspberry Pi Network Controller

#### Components
- Node.js Express server
- iptables wrapper
- WebSocket client for real-time updates
- PM2 process manager

#### Network Control Flow
```typescript
interface NetworkControl {
  // Allow device access
  allowDevice(macAddress: string): Promise<void>;
  
  // Block device access
  blockDevice(macAddress: string): Promise<void>;
  
  // Check device status
  getDeviceStatus(macAddress: string): Promise<boolean>;
  
  // Sync with backend
  syncDeviceStates(): Promise<void>;
}
```

## Security Measures

### Authentication & Authorization
- JWT-based authentication
- Cognito User Pools for identity management
- IAM roles with least privilege
- API Gateway authorization

### Data Security
- All data encrypted at rest (DynamoDB encryption)
- S3 bucket encryption
- HTTPS for all API communications
- Secure WebSocket connections

### Network Security
- Private subnets for Lambda functions
- Security groups with minimal access
- WAF rules on API Gateway
- Regular security audits

## Monitoring & Logging

### AWS CloudWatch
- Lambda function logs
- API Gateway access logs
- Custom metrics for task completion
- Alarms for error rates

### Application Insights
- User activity tracking
- Task completion rates
- Device access patterns
- Error tracking

## Scaling Considerations

### DynamoDB
- On-demand capacity mode
- Global secondary indexes for queries
- TTL for old records

### Lambda
- Memory optimization
- Concurrent execution limits
- Cold start mitigation

### S3
- Lifecycle policies for old photos
- Compression for storage optimization
- CDN integration if needed

## Deployment Strategy

### CI/CD Pipeline
```typescript
// GitHub Actions workflow
- Build TypeScript
- Run tests
- CDK diff
- CDK deploy
- iOS build
```

### Environment Management
- Development
- Staging
- Production

## Error Handling

### Backend Errors
```typescript
interface ApiError {
  code: string;
  message: string;
  details?: any;
  timestamp: number;
}
```

### Client Error Handling
- Retry mechanisms
- Offline support
- Error boundaries
- User feedback

## Future Considerations

1. Multi-device support
2. Advanced scheduling
3. AI-powered task verification
4. Parent dashboard analytics
5. Integration with smart home devices 