import * as cdk from 'aws-cdk-lib';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import * as path from 'path';

export class DailyTasksStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Cognito User Pool
    const userPool = new cognito.UserPool(this, 'DailyTasksUserPool', {
      userPoolName: 'daily-tasks-users',
      selfSignUpEnabled: false,
      signInAliases: {
        email: true,
      },
      standardAttributes: {
        email: {
          required: true,
          mutable: true,
        },
      },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: true,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
    });

    // Cognito App Client
    const userPoolClient = new cognito.UserPoolClient(this, 'DailyTasksUserPoolClient', {
      userPool,
      generateSecret: false,
      authFlows: {
        adminUserPassword: true,
        userPassword: true,
        userSrp: true,
      },
    });

    // DynamoDB Tables
    const usersTable = new dynamodb.Table(this, 'UsersTable', {
      tableName: 'daily-tasks-users',
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    const tasksTable = new dynamodb.Table(this, 'TasksTable', {
      tableName: 'daily-tasks-tasks',
      partitionKey: { name: 'taskId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'kidId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    const devicesTable = new dynamodb.Table(this, 'DevicesTable', {
      tableName: 'daily-tasks-devices',
      partitionKey: { name: 'kidId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'macAddress', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // S3 Bucket for Photos
    const photosBucket = new s3.Bucket(this, 'PhotosBucket', {
      bucketName: `daily-tasks-photos-${this.account}-${this.region}`,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      autoDeleteObjects: false,
      versioned: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      lifecycleRules: [
        {
          enabled: true,
          expiration: cdk.Duration.days(365),
          noncurrentVersionExpiration: cdk.Duration.days(30),
        },
      ],
    });

    // Lambda Layer for Common Code
    const commonLayer = new lambda.LayerVersion(this, 'CommonLayer', {
      code: lambda.Code.fromAsset(path.join(__dirname, '../../lambda/layers/common')),
      compatibleRuntimes: [lambda.Runtime.NODEJS_18_X],
      description: 'Common utilities and middleware',
    });

    // Lambda Functions
    const authFunction = new NodejsFunction(this, 'AuthFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'handler',
      entry: path.join(__dirname, '../../lambda/auth/index.ts'),
      environment: {
        USER_POOL_ID: userPool.userPoolId,
        CLIENT_ID: userPoolClient.userPoolClientId,
        USERS_TABLE: usersTable.tableName,
      },
      layers: [commonLayer],
    });

    const tasksFunction = new NodejsFunction(this, 'TasksFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'handler',
      entry: path.join(__dirname, '../../lambda/tasks/index.ts'),
      environment: {
        TASKS_TABLE: tasksTable.tableName,
        PHOTOS_BUCKET: photosBucket.bucketName,
      },
      layers: [commonLayer],
    });

    const devicesFunction = new NodejsFunction(this, 'DevicesFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'handler',
      entry: path.join(__dirname, '../../lambda/devices/index.ts'),
      environment: {
        DEVICES_TABLE: devicesTable.tableName,
      },
      layers: [commonLayer],
    });

    // Grant permissions
    usersTable.grantReadWriteData(authFunction);
    tasksTable.grantReadWriteData(tasksFunction);
    devicesTable.grantReadWriteData(devicesFunction);
    photosBucket.grantReadWrite(tasksFunction);

    // API Gateway
    const api = new apigateway.RestApi(this, 'DailyTasksApi', {
      restApiName: 'Daily Tasks API',
      description: 'API for Daily Tasks application',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
      },
    });

    // API Resources and Methods
    const auth = api.root.addResource('auth');
    auth.addMethod('POST', new apigateway.LambdaIntegration(authFunction));

    const tasks = api.root.addResource('tasks');
    tasks.addMethod('GET', new apigateway.LambdaIntegration(tasksFunction));
    tasks.addMethod('POST', new apigateway.LambdaIntegration(tasksFunction));

    const task = tasks.addResource('{taskId}');
    task.addMethod('PUT', new apigateway.LambdaIntegration(tasksFunction));
    task.addMethod('DELETE', new apigateway.LambdaIntegration(tasksFunction));

    const devices = api.root.addResource('devices');
    devices.addMethod('GET', new apigateway.LambdaIntegration(devicesFunction));
    devices.addMethod('POST', new apigateway.LambdaIntegration(devicesFunction));

    const device = devices.addResource('{macAddress}');
    device.addMethod('PUT', new apigateway.LambdaIntegration(devicesFunction));

    // Outputs
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: userPool.userPoolId,
      description: 'Cognito User Pool ID',
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: userPoolClient.userPoolClientId,
      description: 'Cognito User Pool Client ID',
    });

    new cdk.CfnOutput(this, 'ApiUrl', {
      value: api.url,
      description: 'API Gateway URL',
    });
  }
} 