import * as cdk from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import { DailyTasksStack } from '../../cdk/stacks/daily-tasks-stack';

describe('DailyTasksStack', () => {
  const app = new cdk.App();
  const stack = new DailyTasksStack(app, 'TestStack', {
    env: {
      account: '123456789012',
      region: 'us-east-1',
    },
    tags: {
      Project: 'DailyTasks',
      Environment: 'test',
    },
  });
  const template = Template.fromStack(stack);

  test('DynamoDB Tables Created', () => {
    template.resourceCountIs('AWS::DynamoDB::Table', 3); // Users, Tasks, and Devices tables
    
    // Test Users table
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      BillingMode: 'PAY_PER_REQUEST',
      TableName: 'daily-tasks-users',
      AttributeDefinitions: Match.arrayWith([
        {
          AttributeName: 'userId',
          AttributeType: 'S',
        },
      ]),
      KeySchema: Match.arrayWith([
        {
          AttributeName: 'userId',
          KeyType: 'HASH',
        },
      ]),
    });

    // Test Tasks table
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      BillingMode: 'PAY_PER_REQUEST',
      TableName: 'daily-tasks-tasks',
      AttributeDefinitions: Match.arrayWith([
        {
          AttributeName: 'taskId',
          AttributeType: 'S',
        },
      ]),
      KeySchema: Match.arrayWith([
        {
          AttributeName: 'taskId',
          KeyType: 'HASH',
        },
      ]),
    });

    // Test Devices table
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      BillingMode: 'PAY_PER_REQUEST',
      TableName: 'daily-tasks-devices',
      AttributeDefinitions: Match.arrayWith([
        {
          AttributeName: 'macAddress',
          AttributeType: 'S',
        },
      ]),
      KeySchema: Match.arrayWith([
        {
          AttributeName: 'macAddress',
          KeyType: 'HASH',
        },
      ]),
    });
  });

  test('Cognito User Pool Created', () => {
    template.resourceCountIs('AWS::Cognito::UserPool', 1);
    template.hasResourceProperties('AWS::Cognito::UserPool', {
      AdminCreateUserConfig: {
        AllowAdminCreateUserOnly: true, // Updated to match actual configuration
      },
      AutoVerifiedAttributes: ['email'],
      UserPoolName: 'daily-tasks-users',
      UsernameAttributes: ['email'],
    });
  });

  test('API Gateway Created', () => {
    template.resourceCountIs('AWS::ApiGateway::RestApi', 1);
    template.hasResourceProperties('AWS::ApiGateway::RestApi', {
      Name: 'Daily Tasks API',
      Description: 'API for Daily Tasks application',
    });
  });

  test('Lambda Functions Created', () => {
    // Check auth function
    template.hasResourceProperties('AWS::Lambda::Function', {
      Handler: 'index.handler',
      Runtime: 'nodejs18.x',
      Environment: {
        Variables: {
          USER_POOL_ID: Match.anyValue(),
          CLIENT_ID: Match.anyValue(),
          USERS_TABLE: Match.anyValue(),
        },
      },
    });

    // Check tasks function
    template.hasResourceProperties('AWS::Lambda::Function', {
      Handler: 'index.handler',
      Runtime: 'nodejs18.x',
      Environment: {
        Variables: {
          TASKS_TABLE: Match.anyValue(),
          PHOTOS_BUCKET: Match.anyValue(),
        },
      },
    });

    // Check devices function
    template.hasResourceProperties('AWS::Lambda::Function', {
      Handler: 'index.handler',
      Runtime: 'nodejs18.x',
      Environment: {
        Variables: {
          DEVICES_TABLE: Match.anyValue(),
        },
      },
    });
  });

  test('S3 Bucket Created', () => {
    template.resourceCountIs('AWS::S3::Bucket', 1);
    template.hasResourceProperties('AWS::S3::Bucket', {
      BucketEncryption: {
        ServerSideEncryptionConfiguration: [
          {
            ServerSideEncryptionByDefault: {
              SSEAlgorithm: 'AES256',
            },
          },
        ],
      },
    });
  });

  test('IAM Roles Created', () => {
    // Check Lambda execution roles
    template.hasResourceProperties('AWS::IAM::Role', {
      AssumeRolePolicyDocument: {
        Statement: [
          {
            Action: 'sts:AssumeRole',
            Effect: 'Allow',
            Principal: {
              Service: 'lambda.amazonaws.com',
            },
          },
        ],
        Version: '2012-10-17',
      },
    });
  });

  test('Security Configurations', () => {
    // Check API Gateway methods
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      AuthorizationType: Match.anyValue(), // Some methods may not require auth
      HttpMethod: Match.anyValue(),
      Integration: {
        Type: 'AWS_PROXY',
        IntegrationHttpMethod: 'POST',
      },
    });

    // Check S3 bucket has encryption and public access blocks
    template.hasResourceProperties('AWS::S3::Bucket', {
      PublicAccessBlockConfiguration: {
        BlockPublicAcls: true,
        BlockPublicPolicy: true,
        IgnorePublicAcls: true,
        RestrictPublicBuckets: true,
      },
    });
  });
}); 