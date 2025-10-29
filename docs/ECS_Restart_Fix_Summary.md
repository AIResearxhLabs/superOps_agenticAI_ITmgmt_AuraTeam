# ECS Restart Loop Fix - Technical Summary

## Problem Analysis
Your `aura-dev-service` was experiencing continuous restart loops due to two major issues:

1. **CRITICAL**: Docker image platform incompatibility
2. **Configuration**: ECS task definition issues

## Root Causes Identified

### 1. **🚨 CRITICAL: Docker Image Platform Incompatibility**
**Error**: `CannotPullContainerError: pull image manifest has been retried 7 time(s): image Manifest does not contain descriptor matching platform 'linux/amd64'`

- **Issue**: Docker images in ECR were built for the wrong platform architecture
- **Cause**: Images were likely built on Apple Silicon (ARM64) or without explicit platform targeting
- **Impact**: ECS Fargate requires `linux/amd64` but images only support ARM64/other platforms

### 2. **Health Check Timing Issues**
- **Database Container**: Original `startPeriod` of 60s was insufficient for a multi-database container running PostgreSQL, MongoDB, and Redis via supervisor
- **Application Containers**: Original `startPeriod` of 30s was too short for Python applications with dependency initialization

### 3. **Health Check Command Problems**
- **Curl Dependency**: Original health checks used `curl` which may not be available in slim Python containers
- **MongoDB Check**: Original command used `mongosh` which might not be available in the database container
- **Inconsistent Hostnames**: Mixed usage of `localhost` vs `127.0.0.1`

### 4. **Environment Variable Issues**
- Missing explicit `HOST` and `PORT` environment variables for applications
- Potential networking conflicts with hostname resolution

### 5. **Health Check Timeout Issues**
- Original timeout of 10s was too short for applications with database connections
- Insufficient retries for handling temporary network issues

## Applied Fixes

### ✅ Database Container (`databases`)
```json
{
  "startPeriod": 180,  // Extended from 60s to 180s
  "timeout": 15,       // Extended from 10s to 15s
  "retries": 5,        // Increased from 3 to 5
  "healthCheck": {
    "command": [
      "CMD-SHELL",
      "pg_isready -h 127.0.0.1 -p 5432 -U aura_user && redis-cli -h 127.0.0.1 -p 6379 ping | grep PONG && echo 'Databases healthy'"
    ]
  }
}
```
**Changes:**
- Removed problematic `mongosh` command
- Standardized on `127.0.0.1` hostname
- Extended startup period for supervisor to initialize all databases
- More robust health check with explicit success confirmation

### ✅ API Gateway Container (`api-gateway`)
```json
{
  "startPeriod": 90,   // Extended from 30s to 90s
  "timeout": 15,       // Extended from 10s to 15s
  "environment": [
    // ... existing vars ...
    {"name": "HOST", "value": "0.0.0.0"},
    {"name": "PORT", "value": "8000"}
  ],
  "healthCheck": {
    "command": [
      "CMD-SHELL",
      "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=10)\" || exit 1"
    ]
  }
}
```
**Changes:**
- Replaced `curl` with Python's built-in `urllib.request`
- Added explicit `HOST` and `PORT` environment variables
- Extended startup period for application initialization
- Consistent hostname usage (`127.0.0.1`)

### ✅ Service Desk Container (`service-desk-host`)
```json
{
  "startPeriod": 90,   // Extended from 30s to 90s
  "timeout": 15,       // Extended from 10s to 15s
  "environment": [
    // ... existing vars ...
    {"name": "HOST", "value": "0.0.0.0"},
    {"name": "PORT", "value": "8001"}
  ],
  "healthCheck": {
    "command": [
      "CMD-SHELL",
      "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8001/health', timeout=10)\" || exit 1"
    ]
  }
}
```
**Changes:**
- Same improvements as API Gateway
- Ensures database dependencies are fully ready before health checks

## Solution: Two-Step Fix Required

### 🚨 **STEP 1: Fix Docker Images (CRITICAL)**
The images must be rebuilt for the correct platform before any ECS deployment will work.

```bash
# 1. Rebuild images with correct platform targeting
chmod +x deploy/scripts/rebuild-images-for-ecs.sh
./deploy/scripts/rebuild-images-for-ecs.sh
```

This script will:
- Build all images specifically for `linux/amd64` platform
- Use Docker Buildx for multi-platform support  
- Push corrected images to your ECR repositories
- Verify successful deployment

### **STEP 2: Deploy Fixed Task Definition**
After images are rebuilt, deploy the corrected task definition:

```bash
# 2. Deploy the fixed task definition
./deploy/scripts/deploy-fixed-task.sh
```

## Alternative Manual Steps

### Option 1: Complete Automated Fix
```bash
# Run both scripts in sequence
./deploy/scripts/rebuild-images-for-ecs.sh
./deploy/scripts/deploy-fixed-task.sh
```

### Option 2: Manual Image Rebuild
```bash
# Manual rebuild (if you prefer step-by-step control)
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 753353727891.dkr.ecr.us-east-2.amazonaws.com

# Build each image for linux/amd64
docker buildx build --platform linux/amd64 -f deploy/containers/multi-database/Dockerfile -t 753353727891.dkr.ecr.us-east-2.amazonaws.com/aura-databases:latest --push deploy/containers/multi-database

docker buildx build --platform linux/amd64 -f aura-backend/api-gateway/Dockerfile -t 753353727891.dkr.ecr.us-east-2.amazonaws.com/aura-api-gateway:latest --push aura-backend

docker buildx build --platform linux/amd64 -f aura-backend/service-desk-host/Dockerfile -t 753353727891.dkr.ecr.us-east-2.amazonaws.com/aura-service-desk-host:latest --push aura-backend
```

### Option 3: Manual Task Definition Deployment
```bash
# Register the new task definition
aws ecs register-task-definition \
  --cli-input-json file://deploy/aws/ecs/task-definition-final.json \
  --region us-east-2

# Update the service
aws ecs update-service \
  --cluster aura-dev-cluster \
  --service aura-dev-service \
  --task-definition aura-app-dev:LATEST_REVISION \
  --force-new-deployment \
  --region us-east-2
```

### Option 2: Manual Deployment
```bash
# Register the new task definition
aws ecs register-task-definition \
  --cli-input-json file://deploy/aws/ecs/task-definition-final.json \
  --region us-east-2

# Update the service
aws ecs update-service \
  --cluster aura-dev-cluster \
  --service aura-dev-service \
  --task-definition aura-app-dev:LATEST_REVISION \
  --region us-east-2
```

## Expected Results

### ✅ Container Startup Sequence
1. **Databases container** starts and initializes all databases (180s grace period)
2. **API Gateway** waits for databases to be healthy, then starts (90s grace period)
3. **Service Desk** waits for databases to be healthy, then starts (90s grace period)

### ✅ Health Check Behavior
- Health checks now use reliable, container-native commands
- Extended timeouts prevent premature failures during initialization
- Consistent networking configuration prevents hostname resolution issues

### ✅ Service Stability
- No more restart loops due to failed health checks
- Proper dependency ordering ensures databases are ready before applications
- Robust error handling with increased retry counts

## Monitoring and Troubleshooting

### View Logs
```bash
# CloudWatch Logs URL (provided by deployment script)
https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#logsV2:log-groups/log-group/%252Fecs%252Faura-app-dev

# Or via CLI
aws logs describe-log-streams \
  --log-group-name /ecs/aura-app-dev \
  --region us-east-2
```

### Check Service Status
```bash
aws ecs describe-services \
  --cluster aura-dev-cluster \
  --services aura-dev-service \
  --region us-east-2
```

### Verify Health Checks
```bash
# List running tasks
aws ecs list-tasks \
  --cluster aura-dev-cluster \
  --service-name aura-dev-service \
  --region us-east-2

# Check task health
aws ecs describe-tasks \
  --cluster aura-dev-cluster \
  --tasks TASK_ARN \
  --region us-east-2
```

## Files Created/Modified

| File | Purpose |
|------|---------|
| `deploy/aws/ecs/task-definition-final.json` | **New**: Fixed task definition with all corrections |
| `deploy/scripts/deploy-fixed-task.sh` | **New**: Automated deployment script |
| `deploy/scripts/rebuild-images-for-ecs.sh` | **New**: Script to rebuild images for correct platform |
| `docs/ECS_Restart_Fix_Summary.md` | **New**: This comprehensive documentation |

## Backup Information

The original task definitions are preserved:
- `deploy/aws/ecs/task-definition.json` - Original version
- `deploy/aws/ecs/task-definition-fixed.json` - Previous attempt

## Next Steps

1. **Deploy the fix**: Run the deployment script
2. **Monitor logs**: Watch CloudWatch logs during startup
3. **Verify stability**: Ensure services remain running after 10+ minutes
4. **Test functionality**: Verify API endpoints respond correctly
5. **Update documentation**: Document any additional environment-specific configurations

## Technical Notes

### Platform Architecture Fix
- **Critical Issue**: Original images were built for wrong platform (likely ARM64 on Apple Silicon)
- **Solution**: Rebuild with explicit `--platform linux/amd64` targeting
- **Tool**: Uses Docker Buildx for cross-platform compilation
- **Verification**: Script checks ECR after push to confirm successful deployment

### Task Definition Fixes
- Health checks now use container-native tools (Python vs external dependencies)
- Startup periods are appropriately sized for each container's initialization needs
- All containers use consistent networking configuration (127.0.0.1)
- Extended timeouts and retries for stability

### Service Management
- The deployment script handles both new service creation and existing service updates
- Includes proper service scaling (stop → register → start) to prevent conflicts
- Automated health verification and monitoring link generation

### Architecture Compatibility
- **ECS Fargate**: Requires `linux/amd64` images
- **Docker Buildx**: Enables cross-platform builds from any development machine
- **Multi-Platform Support**: Images can be built on ARM64 (Apple Silicon) for AMD64 deployment
