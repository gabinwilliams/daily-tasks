import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export interface GitHubActionsStackProps extends cdk.StackProps {
  readonly githubOrg: string;
  readonly githubRepo: string;
}

export class GitHubActionsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: GitHubActionsStackProps) {
    super(scope, id, props);

    // Create OIDC Provider for GitHub Actions
    const provider = new iam.OpenIdConnectProvider(this, 'GitHubProvider', {
      url: 'https://token.actions.githubusercontent.com',
      clientIds: ['sts.amazonaws.com'],
      thumbprints: [
        '6938fd4d98bab03faadb97b34396831e3780aea1',
        '1c58a3a8518e8759bf075b76b750d4f2df264fcd'
      ],
    });

    // Define conditions for the trust policy
    const conditions: { [key: string]: any } = {
      StringLike: {
        'token.actions.githubusercontent.com:sub': `repo:${props.githubOrg}/${props.githubRepo}:*`,
      },
      StringEquals: {
        'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
      },
    };

    // Create IAM role for GitHub Actions
    const role = new iam.Role(this, 'GitHubActionsRole', {
      assumedBy: new iam.WebIdentityPrincipal(provider.openIdConnectProviderArn, conditions),
      description: 'Role used by GitHub Actions to deploy CDK stacks',
      roleName: `${props.githubRepo}-github-actions-role`,
      maxSessionDuration: cdk.Duration.hours(1),
    });

    // Add required permissions for CDK deployment
    role.addToPolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: [
        'cloudformation:*',
        's3:*',
        'iam:*',
        'lambda:*',
        'apigateway:*',
        'dynamodb:*',
        'cognito-idp:*',
        'logs:*',
        'execute-api:*',
        'cloudwatch:*',
      ],
      resources: ['*'],
    }));

    // Output the role ARN
    new cdk.CfnOutput(this, 'RoleArn', {
      value: role.roleArn,
      description: 'ARN of the GitHub Actions IAM role',
      exportName: 'GitHubActionsRoleArn',
    });
  }
} 