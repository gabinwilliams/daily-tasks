import * as cdk from 'aws-cdk-lib';
import { DailyTasksStack } from './stacks/daily-tasks-stack';
import { GitHubActionsStack } from './stacks/github-actions-stack';

const app = new cdk.App();

// Environment configuration
const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
};

// Tags for all resources
const tags = {
  Project: 'DailyTasks',
  Environment: process.env.ENVIRONMENT || 'dev',
  ManagedBy: 'CDK',
};

// GitHub configuration
const githubConfig = {
  org: 'your-github-org', // Replace with your GitHub organization/username
  repo: 'daily-tasks',    // Replace with your repository name
};

// Create the GitHub Actions stack first
const githubStack = new GitHubActionsStack(app, 'DailyTasksGitHubStack', {
  env,
  tags,
  stackName: `daily-tasks-github-${tags.Environment}`,
  description: 'GitHub Actions IAM role for Daily Tasks deployments',
  githubOrg: githubConfig.org,
  githubRepo: githubConfig.repo,
});

// Create the main stack
const mainStack = new DailyTasksStack(app, 'DailyTasksStack', {
  env,
  tags,
  stackName: `daily-tasks-${tags.Environment}`,
  description: 'Daily Tasks - Kids WiFi Management System',
});

app.synth(); 