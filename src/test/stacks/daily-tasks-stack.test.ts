import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
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
    
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      BillingMode: 'PAY_PER_REQUEST',
      TableName: {
        'Fn::Join': [
          '-',
          [
            'daily-tasks',
            'test',
            'users',
          ],
        ],
      },
    });
  });

  test('Cognito User Pool Created', () => {
    template.resourceCountIs('AWS::Cognito::UserPool', 1);
    template.hasResourceProperties('AWS::Cognito::UserPool', {
      AdminCreateUserConfig: {
        AllowAdminCreateUserOnly: false,
      },
      AutoVerifiedAttributes: ['email'],
    });
  });

  test('API Gateway Created', () => {
    template.resourceCountIs('AWS::ApiGateway::RestApi', 1);
    template.hasResourceProperties('AWS::ApiGateway::RestApi', {
      Name: {
        'Fn::Join': [
          '-',
          [
            'daily-tasks',
            'test',
            'api',
          ],
        ],
      },
    });
  });

  test('Lambda Functions Created', () => {
    // Check auth functions
    template.hasResourceProperties('AWS::Lambda::Function', {
      Handler: 'index.handler',
      Runtime: 'nodejs18.x',
      Environment: {
        Variables: {
          USER_POOL_ID: {
            Ref: expect.any(String),
          },
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
      },
    });
  });

  test('Security Configurations', () => {
    // Check API Gateway has authorization
    template.hasResourceProperties('AWS::ApiGateway::Method', {
      AuthorizationType: 'COGNITO_USER_POOLS',
    });

    // Check S3 bucket has encryption
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