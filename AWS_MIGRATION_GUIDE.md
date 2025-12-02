# AWS Migration Guide: From Split Services to Unified Architecture

## Overview

This guide provides step-by-step instructions for migrating from the old split-service architecture (multiple services in aura-cluster) to the new unified architecture (single service in aura-cluster) in AWS ECS.

## Problem with Old Architecture

The previous deployment had:
- **Multiple services** in the aura-cluster (api-gateway, service-desk-host, etc.)
- **Network routing issues** between containers
- **Frontend-backend connectivity problems** due to service discovery
- **Complex CORS configuration** 
- **Difficult debugging** with logs spread across multiple services

## New Unified Architecture

The new deployment has:
- **Single unified service** in aura-cluster
- **All backend code in one container** (aura-service)
- **Internal communication** - no network hops between services
- **Simplified deployment** - one task definition with 3 containers:
  1. **databases** (PostgreSQL, MongoDB, Redis)
  2. **aura-service** (All backend APIs)
  3. **frontend** (React app)

## Migration Steps

### Step 1: Backup Current Configuration (Optional)

If you want to keep a backup of your current setup:

```bash
# Save current task definitions
aws ecs describe-task-definition \
  --task-definition aura-app-dev \
  --region us-east-2 \
  > backup-task-definition.json

# List current services
aws ecs list-services \
  --cluster aura-cluster \
  --region us-east-2 \
  > backup-services.json
```

### Step 2: Clean Up Old Cluster

Run the cleanup script to remove all old services and the cluster:

```bash
# Make script executable (if not already)
chmod +x deploy/scripts/cleanup-old-cluster.sh

# Run cleanup
./deploy/scripts/cleanup-old-cluster.sh
```

**What the script does:**
1. Lists all services in aura-cluster
2. Scales down all services to 0 tasks
3. Waits for tasks to stop
4. Deletes all services
5. Stops any remaining tasks
6. Deletes the aura-cluster
7. Optionally deregisters old task definitions

**Expected output:**
```
🧹 Aura Cluster Cleanup Script
==============================

WARNING: This will delete the following:
  - ECS Cluster: aura-cluster
  - All services in the cluster
  - All running tasks

Are you sure you want to continue? (yes/no): yes

✓ Found cluster aura-cluster
✓ Found services to delete
✓ All services scaled down
✓ All services deleted
✓ No tasks found
✓ Cluster aura-cluster deleted

==================================
✅ Cleanup Complete!
==================================
```

### Step 3: Deploy New Unified Architecture

Deploy the new unified service:

```bash
# Make script executable (if not already)
chmod +x deploy/scripts/deploy-unified.sh

# Run deployment
./deploy/scripts/deploy-unified.sh
```

**What the deployment script does:**
1. Builds all Docker images (databases, aura-service, frontend)
2. Pushes images to ECR
3. Creates new aura-cluster
4. Registers new task definition (aura-app-unified)
5. Creates new service (aura-unified-service)
6. Waits for service to stabilize
7. Provides access URLs

**Expected output:**
```
🚀 Aura Unified Deployment Script
==================================

✓ AWS CLI found
✓ Docker found
✓ Logged in to ECR
✓ All repositories exist
✓ Database container pushed
✓ Aura unified service pushed
✓ Frontend container pushed
✓ Cluster created
✓ Log group created
✓ Task definition registered
✓ Service created
✓ Service is stable

==================================
✅ Deployment Successful!
==================================

Access URLs:
  Frontend: http://XX.XX.XX.XX:80
  API: http://XX.XX.XX.XX:8000
  API Health: http://XX.XX.XX.XX:8000/health
  API Docs: http://XX.XX.XX.XX:8000/docs
```

### Step 4: Verify Deployment

Check that everything is working:

```bash
# Get the public IP
TASK_ARN=$(aws ecs list-tasks \
  --cluster aura-cluster \
  --service-name aura-unified-service \
  --region us-east-2 \
  --query 'taskArns[0]' \
  --output text)

ENI_ID=$(aws ecs describe-tasks \
  --cluster aura-cluster \
  --tasks ${TASK_ARN} \
  --region us-east-2 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids ${ENI_ID} \
  --region us-east-2 \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)

echo "Public IP: ${PUBLIC_IP}"

# Test health endpoint
curl http://${PUBLIC_IP}:8000/health

# Test frontend
curl http://${PUBLIC_IP}:80
```

### Step 5: Monitor Logs

Check logs to ensure everything is running correctly:

```bash
# View all logs
aws logs tail /ecs/aura-app-unified --follow --region us-east-2

# View specific container logs
aws logs tail /ecs/aura-app-unified --follow --filter-pattern "aura-service" --region us-east-2
aws logs tail /ecs/aura-app-unified --follow --filter-pattern "databases" --region us-east-2
aws logs tail /ecs/aura-app-unified --follow --filter-pattern "frontend" --region us-east-2
```

## Architecture Comparison

### Old Architecture (Split Services)

**ECS Cluster: aura-cluster**
- Service: api-gateway
  - Container: api-gateway
- Service: service-desk-host
  - Container: service-desk-host
- Service: databases
  - Container: databases (multi-db)

**Problems:**
- Frontend connects to api-gateway
- api-gateway proxies to service-desk-host
- Network routing between services fails
- Service discovery issues in ECS
- CORS complications

### New Architecture (Unified Service)

**ECS Cluster: aura-cluster**
- Service: aura-unified-service
  - Container: databases (PostgreSQL, MongoDB, Redis)
  - Container: aura-service (All APIs combined)
  - Container: frontend (React app)

**Benefits:**
- Frontend connects directly to aura-service
- No inter-service communication needed
- All containers share localhost networking
- Simplified CORS (single origin)
- All logs in one task

## Task Definition Changes

### Old Task Definition (task-definition.json)
```json
{
  "family": "aura-app-dev",
  "containerDefinitions": [
    {"name": "databases", ...},
    {"name": "api-gateway", ...},
    {"name": "service-desk-host", ...}
  ]
}
```

### New Task Definition (task-definition-unified.json)
```json
{
  "family": "aura-app-unified",
  "containerDefinitions": [
    {"name": "databases", ...},
    {"name": "aura-service", ...},   // Combined service
    {"name": "frontend", ...}
  ]
}
```

## Networking Changes

### Old Setup
```
Frontend (port 80) → ALB → 
  api-gateway (port 8000) → 
    service-desk-host (port 8001)
```

### New Setup
```
Frontend (port 80) → aura-service (port 8000)
                    (All APIs at localhost:8000)
```

## Environment Variables

The unified service consolidates all environment variables:

```bash
# Application
HOST=0.0.0.0
PORT=8000
ENVIRONMENT=aws-production

# All databases now at localhost
DATABASE_URL=postgresql://aura_user:aura_password@localhost:5432/aura_servicedesk
MONGODB_URL=mongodb://localhost:27017/aura_servicedesk
REDIS_URL=redis://localhost:6379

# API Keys (from Systems Manager)
OPENAI_API_KEY=<from SSM>
```

## Rollback Procedure

If you need to rollback to the old architecture:

1. **Stop the new service:**
```bash
aws ecs update-service \
  --cluster aura-cluster \
  --service aura-unified-service \
  --desired-count 0 \
  --region us-east-2
```

2. **Restore old task definition:**
```bash
aws ecs register-task-definition \
  --cli-input-json file://backup-task-definition.json \
  --region us-east-2
```

3. **Recreate old services:**
```bash
# Recreate each service using backup-services.json
# This requires manual recreation based on your backup
```

## Troubleshooting

### Issue: Cleanup script fails

**Solution:**
```bash
# Manually list services
aws ecs list-services --cluster aura-cluster --region us-east-2

# Manually delete each service
aws ecs delete-service \
  --cluster aura-cluster \
  --service <service-name> \
  --force \
  --region us-east-2
```

### Issue: Deployment script fails

**Solution:**
```bash
# Check ECR login
aws ecr get-login-password --region us-east-2

# Verify images exist
aws ecr describe-images \
  --repository-name aura-unified-service \
  --region us-east-2

# Check ECS cluster
aws ecs describe-clusters \
  --clusters aura-cluster \
  --region us-east-2
```

### Issue: Service won't start

**Solution:**
```bash
# Check task logs
aws ecs describe-tasks \
  --cluster aura-cluster \
  --tasks <task-arn> \
  --region us-east-2

# Check CloudWatch logs
aws logs tail /ecs/aura-app-unified --region us-east-2

# Verify security group allows traffic on ports 80 and 8000
```

## Cost Comparison

### Old Architecture
- **Multiple services**: 3 services × $X per hour
- **Separate tasks**: Higher memory/CPU allocation
- **Network bandwidth**: Inter-service communication

### New Architecture
- **Single service**: 1 service × $Y per hour
- **Shared resources**: Lower total allocation
- **No internal network**: Reduced bandwidth costs

**Estimated savings**: 30-40% reduction in ECS costs

## Security Considerations

1. **Secrets Management**: Continue using AWS Systems Manager Parameter Store
2. **Security Groups**: Update to allow only ports 80 and 8000
3. **IAM Roles**: Same roles used (ecsTaskExecutionRole, ecsTaskRole)
4. **Network**: All containers in same task share network namespace

## Post-Migration Checklist

- [ ] Old cluster deleted successfully
- [ ] New cluster created with unified service
- [ ] All containers running and healthy
- [ ] Health check passing: `http://<IP>:8000/health`
- [ ] Frontend accessible: `http://<IP>:80`
- [ ] API docs accessible: `http://<IP>:8000/docs`
- [ ] Logs visible in CloudWatch
- [ ] Frontend can communicate with backend
- [ ] All API endpoints working
- [ ] Database connections successful
- [ ] No errors in CloudWatch logs

## Summary

This migration:
1. ✅ Removes the problematic split-service architecture
2. ✅ Deploys a unified service architecture
3. ✅ Fixes frontend-backend connectivity issues
4. ✅ Simplifies deployment and debugging
5. ✅ Reduces infrastructure costs
6. ✅ Improves application reliability

## Next Steps

After successful migration:
1. Monitor application performance for 24-48 hours
2. Update DNS/domain configuration if needed
3. Configure auto-scaling for production workloads
4. Set up Application Load Balancer for better traffic management
5. Implement backup and disaster recovery procedures

---

**Last Updated**: November 23, 2025
**Migration Status**: ✅ Ready for execution
