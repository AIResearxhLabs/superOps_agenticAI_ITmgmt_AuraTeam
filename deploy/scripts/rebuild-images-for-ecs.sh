#!/bin/bash

# Rebuild Docker Images for ECS Fargate (linux/amd64)
# This script fixes the platform compatibility issue

set -e

# Configuration
REGION="us-east-2"
ACCOUNT_ID="753353727891"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "🐳 Rebuilding Docker Images for ECS Fargate (linux/amd64)"
echo "=========================================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "📍 Project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# Function to build and push image
build_and_push_image() {
    local IMAGE_NAME=$1
    local DOCKERFILE_PATH=$2
    local CONTEXT_PATH=$3
    
    echo ""
    echo "🔨 Building $IMAGE_NAME for linux/amd64..."
    
    # Build for linux/amd64 platform specifically
    docker buildx build \
        --platform linux/amd64 \
        --file "$DOCKERFILE_PATH" \
        --tag "${ECR_REGISTRY}/${IMAGE_NAME}:latest" \
        --push \
        "$CONTEXT_PATH"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully built and pushed $IMAGE_NAME"
    else
        echo "❌ Failed to build $IMAGE_NAME"
        exit 1
    fi
}

# Enable Docker Buildx (for multi-platform builds)
echo "🔧 Setting up Docker Buildx..."
docker buildx create --use --name multiarch-builder --driver docker-container --bootstrap 2>/dev/null || docker buildx use multiarch-builder

# Build 1: Multi-Database Container
echo ""
echo "======================================="
echo "Building aura-databases image..."
echo "======================================="

build_and_push_image "aura-databases" "deploy/containers/multi-database/Dockerfile" "deploy/containers/multi-database"

# Build 2: API Gateway
echo ""
echo "======================================="
echo "Building aura-api-gateway image..."
echo "======================================="

build_and_push_image "aura-api-gateway" "aura-backend/api-gateway/Dockerfile" "aura-backend"

# Build 3: Service Desk Host
echo ""
echo "======================================="
echo "Building aura-service-desk-host image..."
echo "======================================="

build_and_push_image "aura-service-desk-host" "aura-backend/service-desk-host/Dockerfile" "aura-backend"

# Verify images
echo ""
echo "🔍 Verifying pushed images..."
echo "==============================="

for repo in "aura-databases" "aura-api-gateway" "aura-service-desk-host"; do
    echo "Checking $repo..."
    IMAGE_DIGEST=$(aws ecr describe-images --repository-name $repo --region $REGION --image-ids imageTag=latest --query 'imageDetails[0].imageDigest' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$IMAGE_DIGEST" != "NOT_FOUND" ]; then
        echo "✅ $repo:latest - Digest: $IMAGE_DIGEST"
    else
        echo "❌ $repo:latest - NOT FOUND"
    fi
done

echo ""
echo "🎉 Image rebuild completed!"
echo ""
echo "Next steps:"
echo "1. The images are now compatible with linux/amd64 (ECS Fargate)"
echo "2. Deploy the updated task definition:"
echo "   ./deploy/scripts/deploy-fixed-task.sh"
echo ""
echo "Or manually update your ECS service to pick up the new images:"
echo "   aws ecs update-service --cluster aura-dev-cluster --service aura-dev-service --force-new-deployment --region $REGION"
echo ""
