#!/bin/bash

# Cleanup Script for Old Split-Service Architecture
# This script removes the old aura-cluster with multiple services

set -e

echo "🧹 Aura Cluster Cleanup Script"
echo "=============================="
echo ""
echo "This script will remove the old split-service architecture from AWS ECS"
echo ""

# Configuration
AWS_REGION="${AWS_REGION:-us-east-2}"
OLD_CLUSTER_NAME="${OLD_CLUSTER_NAME:-aura-cluster}"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Confirm action
echo -e "${YELLOW}WARNING: This will delete the following:${NC}"
echo "  - ECS Cluster: ${OLD_CLUSTER_NAME}"
echo "  - All services in the cluster"
echo "  - All running tasks"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "🔍 Checking for existing cluster..."

# Check if cluster exists
if ! aws ecs describe-clusters --clusters ${OLD_CLUSTER_NAME} --region ${AWS_REGION} | grep -q "ACTIVE"; then
    print_warning "Cluster ${OLD_CLUSTER_NAME} does not exist or is not active"
    exit 0
fi

print_status "Found cluster ${OLD_CLUSTER_NAME}"

# List all services in the cluster
echo ""
echo "📋 Finding services in cluster..."
SERVICES=$(aws ecs list-services --cluster ${OLD_CLUSTER_NAME} --region ${AWS_REGION} --query 'serviceArns[*]' --output text)

if [ -n "$SERVICES" ]; then
    print_status "Found services to delete"
    
    # Scale down each service to 0
    echo ""
    echo "⬇️  Scaling down services..."
    for service_arn in $SERVICES; do
        service_name=$(basename $service_arn)
        echo "  Scaling down: ${service_name}"
        
        aws ecs update-service \
            --cluster ${OLD_CLUSTER_NAME} \
            --service ${service_name} \
            --desired-count 0 \
            --region ${AWS_REGION} \
            --output text > /dev/null
    done
    
    print_status "All services scaled down"
    
    # Wait for tasks to stop
    echo ""
    echo "⏳ Waiting for tasks to stop (this may take a minute)..."
    sleep 30
    
    # Delete each service
    echo ""
    echo "🗑️  Deleting services..."
    for service_arn in $SERVICES; do
        service_name=$(basename $service_arn)
        echo "  Deleting: ${service_name}"
        
        aws ecs delete-service \
            --cluster ${OLD_CLUSTER_NAME} \
            --service ${service_name} \
            --force \
            --region ${AWS_REGION} \
            --output text > /dev/null
    done
    
    print_status "All services deleted"
else
    print_status "No services found in cluster"
fi

# List and stop any remaining tasks
echo ""
echo "🛑 Checking for remaining tasks..."
TASKS=$(aws ecs list-tasks --cluster ${OLD_CLUSTER_NAME} --region ${AWS_REGION} --query 'taskArns[*]' --output text)

if [ -n "$TASKS" ]; then
    print_warning "Found remaining tasks, stopping them..."
    for task_arn in $TASKS; do
        task_id=$(basename $task_arn)
        echo "  Stopping: ${task_id}"
        
        aws ecs stop-task \
            --cluster ${OLD_CLUSTER_NAME} \
            --task ${task_arn} \
            --region ${AWS_REGION} \
            --output text > /dev/null
    done
    
    print_status "All tasks stopped"
    
    # Wait for tasks to fully stop
    echo "⏳ Waiting for tasks to fully stop..."
    sleep 20
else
    print_status "No tasks found"
fi

# Delete the cluster
echo ""
echo "🗑️  Deleting cluster..."
aws ecs delete-cluster \
    --cluster ${OLD_CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --output text > /dev/null

print_status "Cluster ${OLD_CLUSTER_NAME} deleted"

# Optional: Clean up task definitions (they don't cost anything, so this is optional)
echo ""
read -p "Do you want to deregister old task definitions? (yes/no): " cleanup_tasks

if [ "$cleanup_tasks" = "yes" ]; then
    echo ""
    echo "🗑️  Deregistering old task definitions..."
    
    # List task definition families
    FAMILIES=$(aws ecs list-task-definition-families \
        --status ACTIVE \
        --region ${AWS_REGION} \
        --query 'families[?starts_with(@, `aura-`)]' \
        --output text)
    
    for family in $FAMILIES; do
        echo "  Processing family: ${family}"
        
        # Get all revisions for this family
        REVISIONS=$(aws ecs list-task-definitions \
            --family-prefix ${family} \
            --status ACTIVE \
            --region ${AWS_REGION} \
            --query 'taskDefinitionArns[*]' \
            --output text)
        
        # Deregister each revision
        for revision_arn in $REVISIONS; do
            revision=$(basename $revision_arn)
            echo "    Deregistering: ${revision}"
            
            aws ecs deregister-task-definition \
                --task-definition ${revision_arn} \
                --region ${AWS_REGION} \
                --output text > /dev/null
        done
    done
    
    print_status "Task definitions deregistered"
fi

echo ""
echo "=================================="
echo "✅ Cleanup Complete!"
echo "=================================="
echo ""
echo "The old cluster has been removed. You can now deploy the new unified architecture:"
echo "  ./deploy/scripts/deploy-unified.sh"
echo ""
