# 🚀 Deployment Scripts Guide

This guide covers the improved deployment scripts that prevent duplicate tasks, handle cleanup, and manage ECS services properly.

## 📋 Table of Contents

- [Overview](#overview)
- [Scripts Available](#scripts-available)
- [Common Issues Solved](#common-issues-solved)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

The improved deployment scripts solve critical issues with the original deployment process:

- **Duplicate Tasks**: Prevents multiple services from creating conflicting tasks
- **Service Conflicts**: Detects and handles conflicting services
- **Task Cleanup**: Automatically cleans up old/failed tasks
- **Platform Compatibility**: Ensures Linux/AMD64 builds for ECS Fargate
- **State Management**: Tracks and manages service states properly

## 📦 Scripts Available

### 1. `deploy-improved.sh` - Main Deployment Script

**Purpose**: Enhanced deployment script with conflict detection and cleanup

**Features**:
- ✅ Checks for existing conflicting services
- ✅ Prevents duplicate task creation
- ✅ Handles service updates gracefully
- ✅ Builds platform-specific images
- ✅ Provides detailed status reporting

**Usage**:
```bash
./deploy/scripts/deploy-improved.sh [ENVIRONMENT] [CLOUD_PROVIDER] [DEPLOYMENT_TYPE] [OPTIONS]
```

### 2. `cleanup-tasks.sh` - Standalone Cleanup Utility

**Purpose**: Clean up duplicate/stuck ECS services and tasks

**Features**:
- ✅ Lists all current services and tasks
- ✅ Safe cleanup with confirmation prompts
- ✅ Dry-run mode for testing
- ✅ Force mode for automated cleanup
- ✅ Task definition cleanup

**Usage**:
```bash
./deploy/scripts/cleanup-tasks.sh [ENVIRONMENT] [OPTIONS]
```

## 🔧 Common Issues Solved

### Issue 1: "aura-app-service" Task Duplication
**Problem**: The `aura-app-service` task was deployed and running, but new tasks kept triggering in a loop.

**Solution**: 
```bash
# Check current state first
./deploy/scripts/cleanup-tasks.sh dev --dry-run

# Clean up conflicting services
./deploy/scripts/cleanup-tasks.sh dev --force

# Deploy with cleanup
./deploy/scripts/deploy-improved.sh dev aws fullstack --cleanup
```

### Issue 2: Platform Compatibility Errors
**Problem**: "Manifest does not contain descriptor matching platform 'linux/amd64'"

**Solution**: The improved script automatically builds images for the correct platform:
```bash
# Rebuild images for ECS Fargate
./deploy/scripts/rebuild-images-for-ecs.sh

# Or use the improved deployment script
./deploy/scripts/deploy-improved.sh dev aws backend
```

### Issue 3: Service State Conflicts
**Problem**: Services stuck in INACTIVE, DRAINING, or conflicting states

**Solution**:
```bash
# Force cleanup and redeploy
./deploy/scripts/deploy-improved.sh dev aws fullstack --cleanup --force
```

## 📚 Usage Examples

### Basic Deployment
```bash
# Clean deployment to dev environment
./deploy/scripts/deploy-improved.sh dev aws fullstack --cleanup
```

### Frontend-Only Update
```bash
# Check for conflicts first
./deploy/scripts/cleanup-tasks.sh dev --dry-run

# Deploy only frontend changes
./deploy/scripts/deploy-improved.sh dev aws frontend
```

### Force Deployment (Skip Confirmations)
```bash
# Force deployment without prompts
./deploy/scripts/deploy-improved.sh dev aws backend --force --no-wait
```

### Cleanup Operations
```bash
# Show what would be cleaned up
./deploy/scripts/cleanup-tasks.sh dev --dry-run

# Clean up dev environment
./deploy/scripts/cleanup-tasks.sh dev

# Force cleanup without prompts
./deploy/scripts/cleanup-tasks.sh dev --force

# Clean up everything including all task definitions
./deploy/scripts/cleanup-tasks.sh dev --all --force
```

## 🎛️ Command Line Options

### deploy-improved.sh Options

| Option | Description |
|--------|-------------|
| `--cleanup` | Stop and remove existing services before deployment |
| `--force` | Force deployment even if conflicts are detected |
| `--no-wait` | Don't wait for service stabilization |

### cleanup-tasks.sh Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be cleaned without doing it |
| `--force` | Skip confirmation prompts |
| `--all` | Clean up all task definitions and services |

## 🔍 Deployment Types

| Type | Description | Services Created |
|------|-------------|------------------|
| `backend` | Backend services only | `aura-app-service` |
| `frontend` | Frontend only | `aura-frontend-service` |
| `fullstack` | Complete application | `aura-app-service` (with frontend) |

## 🚨 Troubleshooting

### Problem: "Service was not ACTIVE" Error
```bash
# Check service status
aws ecs describe-services --cluster aura-dev-cluster --services aura-app-service --region us-east-2

# Clean up inactive services
./deploy/scripts/cleanup-tasks.sh dev --force

# Redeploy
./deploy/scripts/deploy-improved.sh dev aws fullstack
```

### Problem: Tasks Stuck in "PROVISIONING" or "PENDING"
```bash
# Check task status
aws ecs describe-tasks --cluster aura-dev-cluster --tasks TASK_ID --region us-east-2

# Force stop and cleanup
./deploy/scripts/cleanup-tasks.sh dev --force

# Rebuild images and deploy
./deploy/scripts/rebuild-images-for-ecs.sh
./deploy/scripts/deploy-improved.sh dev aws backend
```

### Problem: Image Platform Compatibility
```bash
# Rebuild images for correct platform
./deploy/scripts/rebuild-images-for-ecs.sh

# Or use the improved script which handles this automatically
./deploy/scripts/deploy-improved.sh dev aws fullstack
```

### Problem: Multiple Services Running
```bash
# List all current services
./deploy/scripts/cleanup-tasks.sh dev --dry-run

# Clean up all services
./deploy/scripts/cleanup-tasks.sh dev --all --force

# Deploy fresh
./deploy/scripts/deploy-improved.sh dev aws fullstack
```

## 🔧 Best Practices

### 1. Always Check Current State First
```bash
./deploy/scripts/cleanup-tasks.sh dev --dry-run
```

### 2. Use Cleanup Before Major Deployments
```bash
./deploy/scripts/deploy-improved.sh dev aws fullstack --cleanup
```

### 3. Test with Dry Run
```bash
./deploy/scripts/cleanup-tasks.sh dev --dry-run
```

### 4. Monitor Deployment Progress
```bash
# Watch service status
aws ecs describe-services --cluster aura-dev-cluster --services aura-app-service --region us-east-2

# Check task logs
aws logs tail /ecs/aura-app-dev --follow --region us-east-2
```

## 📊 Service Health Monitoring

### Check Service Status
```bash
# List all services and their status
aws ecs list-services --cluster aura-dev-cluster --region us-east-2
aws ecs describe-services --cluster aura-dev-cluster --services SERVICE_NAME --region us-east-2
```

### Access Application
```bash
# Get public IP
TASK_ARN=$(aws ecs list-tasks --cluster aura-dev-cluster --service-name aura-app-service --query 'taskArns[0]' --output text --region us-east-2)
ENI=$(aws ecs describe-tasks --cluster aura-dev-cluster --tasks $TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region us-east-2)
PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region us-east-2)

# Test endpoints
curl -f http://$PUBLIC_IP:8000/health  # API Gateway
curl -f http://$PUBLIC_IP:8001/health  # Service Desk
curl -f http://$PUBLIC_IP:80/           # Frontend (if deployed)
```

## 🎯 Migration from Old Scripts

### Step 1: Clean Up Current State
```bash
./deploy/scripts/cleanup-tasks.sh dev --all --force
```

### Step 2: Use New Deployment Script
```bash
./deploy/scripts/deploy-improved.sh dev aws fullstack
```

### Step 3: Verify Deployment
```bash
# Check service status
./deploy/scripts/cleanup-tasks.sh dev --dry-run

# Test endpoints
curl -f http://PUBLIC_IP:8000/health
```

## 🔐 Security Considerations

- Scripts require AWS CLI to be configured with appropriate permissions
- Uses secure ECR login with temporary tokens
- Follows least-privilege access patterns
- Includes confirmation prompts for destructive operations

## 📞 Support

If you encounter issues:

1. Check the current state: `./deploy/scripts/cleanup-tasks.sh dev --dry-run`
2. Review AWS ECS console for detailed error messages
3. Check CloudWatch logs: `/ecs/aura-app-dev`
4. Verify infrastructure setup: `deploy/aws/infrastructure-dev.json` exists

---

**Note**: These scripts are designed to work with the existing AWS infrastructure setup. Make sure you have run `./deploy/scripts/setup-aws-infrastructure.sh dev` before using these deployment scripts.
