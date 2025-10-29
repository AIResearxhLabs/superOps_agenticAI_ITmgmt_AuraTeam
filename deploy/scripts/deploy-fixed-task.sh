#!/bin/bash

# Deploy Fixed Aura ECS Task Definition
# This script deploys the corrected task definition to fix restart issues

set -e

# Configuration
CLUSTER_NAME="aura-dev-cluster"
SERVICE_NAME="aura-dev-service"
TASK_DEFINITION_FILE="deploy/aws/ecs/task-definition-final.json"
REGION="us-east-2"

echo "🚀 Deploying Fixed Aura ECS Task Definition"
echo "============================================"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if task definition file exists
if [ ! -f "$TASK_DEFINITION_FILE" ]; then
    echo "❌ Task definition file not found: $TASK_DEFINITION_FILE"
    exit 1
fi

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FULL_TASK_DEF_PATH="$PROJECT_ROOT/$TASK_DEFINITION_FILE"

echo "📍 Project root: $PROJECT_ROOT"
echo "📄 Task definition: $FULL_TASK_DEF_PATH"

# Check AWS credentials
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity --region $REGION > /dev/null 2>&1; then
    echo "❌ AWS credentials not configured or invalid"
    exit 1
fi

USER_INFO=$(aws sts get-caller-identity --region $REGION --query 'Arn' --output text)
echo "✅ Authenticated as: $USER_INFO"

# Stop current service if running (to prevent conflicts)
echo "🛑 Stopping current service to prevent conflicts..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --desired-count 0 \
    --region $REGION \
    --no-cli-pager || echo "⚠️  Service may not exist yet, continuing..."

echo "⏳ Waiting for service to scale down..."
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION || echo "⚠️  Service may not exist, continuing..."

# Register new task definition
echo "📝 Registering new task definition..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://$FULL_TASK_DEF_PATH \
    --region $REGION \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "✅ Task definition registered: $TASK_DEF_ARN"

# Extract revision number
REVISION=$(echo $TASK_DEF_ARN | sed 's/.*://')
echo "📌 Task definition revision: $REVISION"

# Create or update service
echo "🔄 Creating/updating ECS service..."

# Check if service exists
if aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION --query 'services[0].serviceName' --output text 2>/dev/null | grep -q $SERVICE_NAME; then
    echo "🔄 Updating existing service..."
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --task-definition $TASK_DEF_ARN \
        --desired-count 1 \
        --region $REGION \
        --no-cli-pager
else
    echo "🆕 Creating new service..."
    
    # Get subnet and security group info
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region $REGION --query 'Vpcs[0].VpcId' --output text)
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')
    
    # Create security group if it doesn't exist
    SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=aura-dev-sg" "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
    
    if [ "$SG_ID" = "None" ]; then
        echo "🔐 Creating security group..."
        SG_ID=$(aws ec2 create-security-group \
            --group-name aura-dev-sg \
            --description "Security group for Aura dev environment" \
            --vpc-id $VPC_ID \
            --region $REGION \
            --query 'GroupId' \
            --output text)
        
        # Add inbound rules
        aws ec2 authorize-security-group-ingress \
            --group-id $SG_ID \
            --protocol tcp \
            --port 8000 \
            --cidr 0.0.0.0/0 \
            --region $REGION
            
        aws ec2 authorize-security-group-ingress \
            --group-id $SG_ID \
            --protocol tcp \
            --port 8001 \
            --cidr 0.0.0.0/0 \
            --region $REGION
    fi
    
    # Create the service
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --task-definition $TASK_DEF_ARN \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
        --region $REGION \
        --no-cli-pager
fi

echo "⏳ Waiting for service to stabilize..."
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION

# Check service status
echo "📊 Checking service status..."
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION \
    --query 'services[0].status' \
    --output text)

RUNNING_COUNT=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION \
    --query 'services[0].runningCount' \
    --output text)

DESIRED_COUNT=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION \
    --query 'services[0].desiredCount' \
    --output text)

echo "📈 Service Status: $SERVICE_STATUS"
echo "🏃 Running Tasks: $RUNNING_COUNT/$DESIRED_COUNT"

if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ] && [ "$SERVICE_STATUS" = "ACTIVE" ]; then
    echo "✅ Service deployed successfully!"
    
    # Get task ARN to show logs location
    TASK_ARN=$(aws ecs list-tasks \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --region $REGION \
        --query 'taskArns[0]' \
        --output text)
    
    if [ "$TASK_ARN" != "None" ]; then
        echo "📋 Task ARN: $TASK_ARN"
        echo "📝 View logs at: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups/log-group/%252Fecs%252Faura-app-dev"
    fi
    
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo "Key fixes applied:"
    echo "  ✅ Extended startPeriod for databases (180s)"
    echo "  ✅ Extended startPeriod for applications (90s)"
    echo "  ✅ Fixed health check commands (removed curl dependency)"
    echo "  ✅ Increased health check timeout (15s)"
    echo "  ✅ Consistent hostname usage (127.0.0.1)"
    echo "  ✅ Added HOST and PORT environment variables"
    echo ""
else
    echo "❌ Service deployment may have issues"
    echo "Check the CloudWatch logs for more details:"
    echo "https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups/log-group/%252Fecs%252Faura-app-dev"
    exit 1
fi
