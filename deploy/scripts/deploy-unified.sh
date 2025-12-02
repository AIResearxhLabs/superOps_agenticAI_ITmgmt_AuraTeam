#!/bin/bash

# Unified Aura Deployment Script for AWS ECS
# This script deploys the consolidated aura-service architecture

set -e

echo "🚀 Aura Unified Deployment Script"
echo "=================================="

# Configuration
AWS_REGION="${AWS_REGION:-us-east-2}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-753353727891}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
CLUSTER_NAME="${CLUSTER_NAME:-aura-dev-cluster}"
SERVICE_NAME="${SERVICE_NAME:-aura-unified-service}"
TASK_DEFINITION_FILE="deploy/aws/ecs/task-definition-unified.json"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
echo ""
echo "📋 Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install it first."
    exit 1
fi
print_status "AWS CLI found"

if ! command -v docker &> /dev/null; then
    print_error "Docker not found. Please install it first."
    exit 1
fi
print_status "Docker found"

# Login to ECR
echo ""
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
print_status "Logged in to ECR"

# Create ECR repositories if they don't exist
echo ""
echo "📦 Checking ECR repositories..."

repositories=("aura-databases" "aura-unified-service" "aura-frontend")

for repo in "${repositories[@]}"; do
    if ! aws ecr describe-repositories --repository-names ${repo} --region ${AWS_REGION} &> /dev/null; then
        print_warning "Creating ECR repository: ${repo}"
        aws ecr create-repository --repository-name ${repo} --region ${AWS_REGION}
        print_status "Repository ${repo} created"
    else
        print_status "Repository ${repo} exists"
    fi
done

# Build and push multi-database container
echo ""
echo "🏗️  Building multi-database container..."
cd deploy/containers/multi-database
docker build -t ${ECR_REGISTRY}/aura-databases:latest .
docker push ${ECR_REGISTRY}/aura-databases:latest
print_status "Database container pushed"
cd ../../..

# Build and push unified aura-service
echo ""
echo "🏗️  Building unified aura-service..."
cd aura-backend
docker build -f aura-service/Dockerfile -t ${ECR_REGISTRY}/aura-unified-service:latest .
docker push ${ECR_REGISTRY}/aura-unified-service:latest
print_status "Aura unified service pushed"
cd ..

# Build and push frontend
echo ""
echo "🏗️  Building frontend..."
cd aura-frontend
docker build -t ${ECR_REGISTRY}/aura-frontend:latest .
docker push ${ECR_REGISTRY}/aura-frontend:latest
print_status "Frontend container pushed"
cd ..

# Create or update ECS cluster
echo ""
echo "🔧 Setting up ECS cluster..."
if ! aws ecs describe-clusters --clusters ${CLUSTER_NAME} --region ${AWS_REGION} | grep -q "ACTIVE"; then
    print_warning "Creating ECS cluster: ${CLUSTER_NAME}"
    aws ecs create-cluster --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION}
    print_status "Cluster created"
else
    print_status "Cluster ${CLUSTER_NAME} exists"
fi

# Create CloudWatch log group
echo ""
echo "📊 Setting up CloudWatch logs..."
LOG_GROUP="/ecs/aura-app-unified"
if ! aws logs describe-log-groups --log-group-name-prefix ${LOG_GROUP} --region ${AWS_REGION} | grep -q ${LOG_GROUP}; then
    aws logs create-log-group --log-group-name ${LOG_GROUP} --region ${AWS_REGION}
    print_status "Log group created"
else
    print_status "Log group exists"
fi

# Register task definition
echo ""
echo "📝 Registering task definition..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://${TASK_DEFINITION_FILE} \
    --region ${AWS_REGION} \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)
print_status "Task definition registered: ${TASK_DEF_ARN}"

# Check if service exists
echo ""
echo "🔍 Checking for existing service..."
if aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${AWS_REGION} | grep -q "ACTIVE"; then
    print_warning "Service exists, updating..."
    
    # Update service
    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${SERVICE_NAME} \
        --task-definition ${TASK_DEF_ARN} \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    print_status "Service updated"
else
    print_warning "Service does not exist, creating..."
    
    # Get VPC configuration
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text --region ${AWS_REGION})" \
        --query 'Subnets[*].SubnetId' \
        --output text \
        --region ${AWS_REGION} | tr '\t' ',')
    
    SECURITY_GROUP=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=default" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --region ${AWS_REGION})
    
    # Create service
    aws ecs create-service \
        --cluster ${CLUSTER_NAME} \
        --service-name ${SERVICE_NAME} \
        --task-definition ${TASK_DEF_ARN} \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP}],assignPublicIp=ENABLED}" \
        --region ${AWS_REGION}
    
    print_status "Service created"
fi

# Wait for service to stabilize
echo ""
echo "⏳ Waiting for service to stabilize (this may take a few minutes)..."
aws ecs wait services-stable \
    --cluster ${CLUSTER_NAME} \
    --services ${SERVICE_NAME} \
    --region ${AWS_REGION}

print_status "Service is stable"

# Get service details
echo ""
echo "📊 Getting service details..."
TASK_ARN=$(aws ecs list-tasks \
    --cluster ${CLUSTER_NAME} \
    --service-name ${SERVICE_NAME} \
    --region ${AWS_REGION} \
    --query 'taskArns[0]' \
    --output text)

if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    ENI_ID=$(aws ecs describe-tasks \
        --cluster ${CLUSTER_NAME} \
        --tasks ${TASK_ARN} \
        --region ${AWS_REGION} \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
        --output text)
    
    PUBLIC_IP=$(aws ec2 describe-network-interfaces \
        --network-interface-ids ${ENI_ID} \
        --region ${AWS_REGION} \
        --query 'NetworkInterfaces[0].Association.PublicIp' \
        --output text)
    
    echo ""
    echo "=================================="
    echo "✅ Deployment Successful!"
    echo "=================================="
    echo ""
    echo "Service Details:"
    echo "  Cluster: ${CLUSTER_NAME}"
    echo "  Service: ${SERVICE_NAME}"
    echo "  Task Definition: ${TASK_DEF_ARN}"
    echo ""
    echo "Access URLs:"
    echo "  Frontend: http://${PUBLIC_IP}:80"
    echo "  API: http://${PUBLIC_IP}:8000"
    echo "  API Health: http://${PUBLIC_IP}:8000/health"
    echo "  API Docs: http://${PUBLIC_IP}:8000/docs"
    echo ""
    echo "Monitoring:"
    echo "  CloudWatch Logs: https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups/log-group/${LOG_GROUP}"
    echo "  ECS Service: https://console.aws.amazon.com/ecs/home?region=${AWS_REGION}#/clusters/${CLUSTER_NAME}/services/${SERVICE_NAME}"
    echo ""
else
    print_error "Could not retrieve task information"
fi

echo "✨ Deployment complete!"
