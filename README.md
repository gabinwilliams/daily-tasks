# Daily Tasks - Kids WiFi Management System

A comprehensive solution for managing children's daily tasks and automated WiFi access control for gaming consoles and tablets.

## Overview

This system consists of three main components:
- iOS Mobile App (Swift)
- Serverless Backend (TypeScript/Node.js on AWS)
- Raspberry Pi WiFi Controller

### Key Features

- **Task Management**
  - Daily task checklists for kids
  - Photo proof submission
  - Parental review and approval
  
- **Automated WiFi Control**
  - Device registration via MAC address
  - Automatic access control based on task completion
  - Raspberry Pi-based network management

- **User Roles**
  - Kids: Task completion and photo submission
  - Parents: Task review, approval, and device management

## Technology Stack

- **Frontend**
  - iOS (Swift)
  - SwiftUI for modern UI components
  - Async/await for API communication

- **Backend**
  - TypeScript/Node.js
  - AWS Lambda (Serverless)
  - DynamoDB for data storage
  - S3 for photo storage
  - AWS Cognito for authentication

- **Network Control**
  - Raspberry Pi running Linux
  - iptables for traffic control
  - Node.js control server

## Getting Started

### Prerequisites

- Node.js 18.x or later
- AWS Account (Free Tier eligible)
- Xcode 14.x or later
- Raspberry Pi 4 (recommended) or 3B+
- TypeScript 5.x

### Installation

1. **Backend Setup**
   ```bash
   npm install
   npm run build
   ```

2. **AWS Configuration**
   ```bash
   aws configure
   cdk deploy
   ```

3. **Raspberry Pi Setup**
   ```bash
   # Instructions in docs/raspberry-pi-setup.md
   ```

4. **iOS App Setup**
   ```bash
   cd ios
   pod install
   open DailyTasks.xcworkspace
   ```

## Project Structure

```
├── backend/           # AWS CDK + Lambda functions
├── ios/              # iOS application
├── raspberry-pi/     # Pi control scripts
└── docs/             # Documentation
```

## Development

See detailed documentation in the `docs/` directory:
- [Architecture Overview](docs/architecture.md)
- [API Specification](docs/api-spec.md)
- [Raspberry Pi Setup](docs/raspberry-pi-setup.md)

## Security

- All communications are encrypted via HTTPS
- AWS IAM roles follow least privilege principle
- Raspberry Pi implements secure API authentication
- User data is encrypted at rest

## License

Test