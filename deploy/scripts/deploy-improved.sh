#!/bin/bash
# Improved Deployment Script for Aura Team Project
# Prevents duplicate tasks, handles cleanup, and manages existing services properly

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [CLOUD_PROVIDER] [DEPLOYMENT_TYPE] [OPTIONS]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  local       - Local development with Docker Compose"
    echo "  dev         - Development environment"
    echo "  staging     - Staging environment"
    echo "  prod        - Production environment"
    echo ""
    echo "CLOUD_PROVIDER (optional for non-local):"
    echo "  aws         - Amazon Web Services (ECS/Fargate)"
    echo ""
    echo "DEPLOYMENT_TYPE (for cloud deployments):"
    echo "  backend     - Deploy only backend services (default)"
    echo "  frontend    - Deploy only frontend (requires backend running)"
    echo "  fullstack   - Deploy complete application (backend + frontend)"
    echo ""
    echo "OPTIONS:"
    echo "  --cleanup   - Stop and remove existing services before deployment"
    echo "  --force     - Force deployment even if tasks are running"
    echo "  --no-wait   - Don't wait for service stabilization"
    echo ""
    echo "Examples:"
    echo "  $0 local                              # Local development"
    echo "  $0 dev aws backend                    # Deploy backend only to AWS"
    echo "  $0 dev aws fullstack --cleanup        # Clean up and deploy complete app"
    echo "  $0 dev aws frontend --force           # Force frontend deployment"
    echo ""
    exit 1
}

# Function to parse command line options
parse_options() {
    CLEANUP_BEFORE_DEPLOY=false
    FORCE_DEPLOYMENT=false
    WAIT_FOR_STABILIZATION=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup)
                CLEANUP_BEFORE_DEPLOY=true
                shift
                ;;
            --force)
                FORCE_DEPLOYMENT=true
                shift
                ;;
            --no-wait)
                WAIT_FOR_STABILIZATION=false
                shift
                ;;
            *)
                # Not an option, break to handle positional arguments
                break
                ;;
        esac
    done
}

# Function to check prerequisites
check_prerequisites() {
    local environment=$1
    local cloud_provider=$2
    
    print_header "Checking Prerequisites"
    
    # Common prerequisites
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose."
        exit 1
    fi
    
    # Cloud-specific prerequisites
    if [[ "$environment" != "local" ]]; then
        case $cloud_provider in
            "aws")
                if ! command -v aws &> /dev/null; then
                    print_error "AWS CLI is not installed. Please install AWS CLI."
                    exit 1
                fi
                
                if ! command -v jq &> /dev/null; then
                    print_error "jq is not installed. Please install jq for JSON processing."
                    exit 1
                fi
                
                # Check AWS credentials
                if ! aws sts get-caller-identity &> /dev/null; then
                    print_error "AWS credentials not configured. Run 'aws configure'."
                    exit 1
                fi
                ;;
        esac
    fi
    
    print_status "All prerequisites checked ✓"
}

# Function to stop and cleanup existing ECS services
cleanup_ecs_services() {
    local environment=$1
    local cluster_name=$2
    
    print_header "Cleaning Up Existing ECS Services"
    
    # List of possible service names that might exist
    local service_names=("aura-app-service" "aura-frontend-service" "aura-backend-service")
    
    for service_name in "${service_names[@]}"; do
        print_status "Checking for existing service: $service_name"
        
        # Check if service exists and is active
        local service_status=$(aws ecs describe-services \
            --cluster "$cluster_name" \
            --services "$service_name" \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "NONE")
        
        if [[ "$service_status" == "ACTIVE" ]]; then
            print_warning "Found active service: $service_name. Stopping..."
            
            # Scale down to 0 first
            aws ecs update-service \
                --cluster "$cluster_name" \
                --service "$service_name" \
                --desired-count 0 \
                --region "$AWS_DEFAULT_REGION" > /dev/null
            
            print_status "Waiting for service to scale down..."
            aws ecs wait services-stable \
                --cluster "$cluster_name" \
                --services "$service_name" \
                --region "$AWS_DEFAULT_REGION"
            
            # Delete the service
            print_status "Deleting service: $service_name"
            aws ecs delete-service \
                --cluster "$cluster_name" \
                --service "$service_name" \
                --region "$AWS_DEFAULT_REGION" > /dev/null
            
            print_status "Service $service_name deleted successfully"
        elif [[ "$service_status" == "DRAINING" || "$service_status" == "PENDING" ]]; then
            print_warning "Service $service_name is in $service_status state. Waiting for it to complete..."
            aws ecs wait services-inactive \
                --cluster "$cluster_name" \
                --services "$service_name" \
                --region "$AWS_DEFAULT_REGION"
        else
            print_status "Service $service_name does not exist or is already inactive"
        fi
    done
    
    # Clean up old task definitions (keep only latest 3 revisions)
    print_status "Cleaning up old task definitions..."
    local task_families=("aura-app-${environment}" "aura-frontend-${environment}")
    
    for family in "${task_families[@]}"; do
        local task_definitions=$(aws ecs list-task-definitions \
            --family-prefix "$family" \
            --status ACTIVE \
            --sort DESC \
            --query 'taskDefinitionArns[3:]' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$task_definitions" && "$task_definitions" != "None" ]]; then
            print_status "Deregistering old task definitions for family: $family"
            for task_def in $task_definitions; do
                aws ecs deregister-task-definition --task-definition "$task_def" > /dev/null
                print_status "Deregistered: $(basename $task_def)"
            done
        fi
    done
    
    print_status "Cleanup completed ✓"
}

# Function to check for running tasks and handle conflicts
check_running_tasks() {
    local environment=$1
    local cluster_name=$2
    local deployment_type=$3
    
    print_status "Checking for running tasks..."
    
    # Determine which services we expect based on deployment type
    local expected_services=()
    case "$deployment_type" in
        "frontend")
            expected_services=("aura-frontend-service")
            ;;
        "fullstack")
            expected_services=("aura-app-service")
            ;;
        *)
            expected_services=("aura-app-service")
            ;;
    esac
    
    # Check for conflicting services
    local conflicting_services=()
    local all_possible_services=("aura-app-service" "aura-frontend-service" "aura-backend-service")
    
    for service_name in "${all_possible_services[@]}"; do
        local service_status=$(aws ecs describe-services \
            --cluster "$cluster_name" \
            --services "$service_name" \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "NONE")
        
        if [[ "$service_status" == "ACTIVE" ]]; then
            # Check if this service is expected for our deployment type
            local is_expected=false
            for expected in "${expected_services[@]}"; do
                if [[ "$service_name" == "$expected" ]]; then
                    is_expected=true
                    break
                fi
            done
            
            if [[ "$is_expected" == "false" ]]; then
                conflicting_services+=("$service_name")
                print_warning "Found conflicting service: $service_name"
            else
                print_status "Found existing target service: $service_name (will be updated)"
            fi
        fi
    done
    
    # Handle conflicts
    if [[ ${#conflicting_services[@]} -gt 0 && "$FORCE_DEPLOYMENT" == "false" ]]; then
        print_error "Conflicting services detected:"
        for service in "${conflicting_services[@]}"; do
            print_error "  - $service"
        done
        print_status ""
        print_status "Options to resolve:"
        print_status "  1. Use --cleanup flag to remove all existing services"
        print_status "  2. Use --force flag to proceed anyway (may cause issues)"
        print_status "  3. Manually clean up services using AWS console"
        print_status ""
        exit 1
    elif [[ ${#conflicting_services[@]} -gt 0 && "$FORCE_DEPLOYMENT" == "true" ]]; then
        print_warning "Proceeding with force deployment despite conflicts..."
    fi
}

# Function to get appropriate service and task definition names
get_service_config() {
    local deployment_type=$1
    local environment=$2
    
    case "$deployment_type" in
        "frontend")
            SERVICE_NAME="aura-frontend-service"
            TASK_FAMILY="aura-frontend-${environment}"
            TASK_DEF_FILE="deploy/aws/ecs/task-definition-frontend-only.json"
            ;;
        "fullstack")
            SERVICE_NAME="aura-app-service"
            TASK_FAMILY="aura-app-${environment}"
            TASK_DEF_FILE="deploy/aws/ecs/task-definition-with-frontend.json"
            ;;
        *)
            SERVICE_NAME="aura-app-service"
            TASK_FAMILY="aura-app-${environment}"
            TASK_DEF_FILE="deploy/aws/ecs/task-definition.json"
            ;;
    esac
}

# Function for AWS deployment with improved handling
deploy_aws_improved() {
    local environment=$1
    local deployment_type=${2:-backend}
    
    print_header "Deploying to AWS Environment: $environment ($deployment_type)"
    
    # Set AWS region
    export AWS_DEFAULT_REGION=us-east-2
    
    # Check if infrastructure exists
    local infrastructure_file="deploy/aws/infrastructure-${environment}.json"
    if [[ ! -f "$infrastructure_file" ]]; then
        print_error "Infrastructure file not found: $infrastructure_file"
        print_status "Please run setup-aws-infrastructure.sh first:"
        print_status "  ./deploy/scripts/setup-aws-infrastructure.sh $environment"
        exit 1
    fi
    
    # Load infrastructure configuration
    local vpc_id=$(jq -r '.vpc_id' "$infrastructure_file")
    local public_subnets=$(jq -r '.public_subnets | join(",")' "$infrastructure_file")
    local security_group_id=$(jq -r '.security_group_id' "$infrastructure_file")
    local cluster_name=$(jq -r '.ecs_cluster' "$infrastructure_file")
    
    print_status "Using infrastructure configuration:"
    print_status "  VPC: $vpc_id"
    print_status "  Subnets: $public_subnets"
    print_status "  Security Group: $security_group_id"
    print_status "  ECS Cluster: $cluster_name"
    
    # Cleanup if requested
    if [[ "$CLEANUP_BEFORE_DEPLOY" == "true" ]]; then
        cleanup_ecs_services "$environment" "$cluster_name"
    else
        check_running_tasks "$environment" "$cluster_name" "$deployment_type"
    fi
    
    # Get service configuration
    get_service_config "$deployment_type" "$environment"
    
    print_status "Service Configuration:"
    print_status "  Service Name: $SERVICE_NAME"
    print_status "  Task Family: $TASK_FAMILY"
    print_status "  Task Definition File: $TASK_DEF_FILE"
    
    # Create ECR repositories if they don't exist
    create_ecr_repositories "$deployment_type"
    
    # Build and push Docker images
    build_and_push_images_improved "$deployment_type"
    
    # Deploy to ECS
    deploy_to_ecs_improved "$environment" "$cluster_name" "$public_subnets" "$security_group_id"
    
    print_status "AWS deployment completed!"
}

# Function to create ECR repositories based on deployment type
create_ecr_repositories() {
    local deployment_type=$1
    
    print_status "Creating ECR repositories..."
    
    local repositories=()
    case "$deployment_type" in
        "frontend")
            repositories=("aura-frontend")
            ;;
        "fullstack")
            repositories=("aura-api-gateway" "aura-service-desk-host" "aura-databases" "aura-frontend")
            ;;
        *)
            repositories=("aura-api-gateway" "aura-service-desk-host" "aura-databases")
            ;;
    esac
    
    for repo in "${repositories[@]}"; do
        if ! aws ecr describe-repositories --repository-names "$repo" &> /dev/null; then
            print_status "Creating ECR repository: $repo"
            aws ecr create-repository --repository-name "$repo" --region us-east-2
        else
            print_status "ECR repository already exists: $repo"
        fi
    done
}

# Function to build and push Docker images with improved logic
build_and_push_images_improved() {
    local deployment_type=$1
    
    print_header "Building and Pushing Docker Images"
    
    # Get AWS account ID
    local aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    local ecr_uri="${aws_account_id}.dkr.ecr.us-east-2.amazonaws.com"
    
    # Login to ECR
    print_status "Logging into ECR..."
    aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin "$ecr_uri"
    
    cd "$(dirname "$0")/../.." # Go to project root
    
    # Build based on deployment type
    case "$deployment_type" in
        "frontend")
            print_status "Building Frontend image only..."
            build_frontend_image "$ecr_uri"
            ;;
        "fullstack")
            print_status "Building all images (backend + frontend)..."
            build_backend_images "$ecr_uri"
            build_frontend_image "$ecr_uri"
            ;;
        *)
            print_status "Building backend images only..."
            build_backend_images "$ecr_uri"
            ;;
    esac
    
    print_status "All required images built and pushed successfully ✓"
}

# Function to build backend images
build_backend_images() {
    local ecr_uri=$1
    
    print_status "Setting up Docker Buildx for cross-platform builds..."
    # Create builder if it doesn't exist
    if ! docker buildx inspect multiarch-builder &> /dev/null; then
        docker buildx create --name multiarch-builder --use
    else
        docker buildx use multiarch-builder
    fi
    
    # Build and push API Gateway
    print_status "Building API Gateway image for linux/amd64..."
    docker buildx build --platform linux/amd64 \
        -f aura-backend/api-gateway/Dockerfile \
        -t "$ecr_uri/aura-api-gateway:latest" \
        --push aura-backend/
    
    # Build and push Service Desk Host
    print_status "Building Service Desk Host image for linux/amd64..."
    docker buildx build --platform linux/amd64 \
        -f aura-backend/service-desk-host/Dockerfile \
        -t "$ecr_uri/aura-service-desk-host:latest" \
        --push aura-backend/
    
    # Build and push Multi-Database
    print_status "Building Multi-Database image for linux/amd64..."
    docker buildx build --platform linux/amd64 \
        -t "$ecr_uri/aura-databases:latest" \
        --push deploy/containers/multi-database/
}

# Function to build frontend image
build_frontend_image() {
    local ecr_uri=$1
    
    print_status "Building Frontend image for linux/amd64..."
    
    print_status "Setting up Docker Buildx for cross-platform builds..."
    # Create builder if it doesn't exist
    if ! docker buildx inspect multiarch-builder &> /dev/null; then
        docker buildx create --name multiarch-builder --use
    else
        docker buildx use multiarch-builder
    fi
    
    # Set API URL for production build
    export REACT_APP_API_BASE_URL="http://127.0.0.1:8000"
    
    # Build and push Frontend for linux/amd64
    docker buildx build --platform linux/amd64 \
        -t "$ecr_uri/aura-frontend:latest" \
        --push aura-frontend/
}

# Function to deploy to ECS with improved handling
deploy_to_ecs_improved() {
    local environment=$1
    local cluster_name=$2
    local public_subnets=$3
    local security_group_id=$4
    
    print_status "Deploying to ECS..."
    
    # Update task definition with current AWS account ID
    local aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    local updated_task_def="/tmp/task-definition-${environment}-$(date +%s).json"
    
    # Replace account ID in task definition
    sed "s/753353727891/$aws_account_id/g" "$TASK_DEF_FILE" > "$updated_task_def"
    
    # Create CloudWatch log group
    local log_group="/ecs/${TASK_FAMILY}"
    if ! aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        print_status "Creating CloudWatch log group: $log_group"
        aws logs create-log-group --log-group-name "$log_group"
        aws logs put-retention-policy --log-group-name "$log_group" --retention-in-days 7
    fi
    
    # Register task definition
    print_status "Registering ECS task definition with account ID: $aws_account_id"
    local task_def_arn=$(aws ecs register-task-definition --cli-input-json file://"$updated_task_def" --query 'taskDefinition.taskDefinitionArn' --output text)
    print_status "Task definition registered: $task_def_arn"
    
    # Create or update ECS service
    local service_exists=$(aws ecs describe-services --cluster "$cluster_name" --services "$SERVICE_NAME" --query 'services[0].status' --output text 2>/dev/null || echo "NONE")
    
    if [[ "$service_exists" == "ACTIVE" ]]; then
        print_status "Updating existing ECS service: $SERVICE_NAME"
        aws ecs update-service \
            --cluster "$cluster_name" \
            --service "$SERVICE_NAME" \
            --task-definition "$TASK_FAMILY" \
            --region "$AWS_DEFAULT_REGION"
    else
        print_status "Creating new ECS service: $SERVICE_NAME"
        aws ecs create-service \
            --cluster "$cluster_name" \
            --service-name "$SERVICE_NAME" \
            --task-definition "$TASK_FAMILY" \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[$public_subnets],securityGroups=[$security_group_id],assignPublicIp=ENABLED}" \
            --region "$AWS_DEFAULT_REGION"
    fi
    
    # Wait for service to stabilize if requested
    if [[ "$WAIT_FOR_STABILIZATION" == "true" ]]; then
        print_status "Waiting for ECS service to stabilize..."
        aws ecs wait services-stable --cluster "$cluster_name" --services "$SERVICE_NAME" --region "$AWS_DEFAULT_REGION"
        
        # Get service status and public IP
        get_service_info "$cluster_name" "$SERVICE_NAME"
    else
        print_status "Skipping stabilization wait (--no-wait flag used)"
    fi
    
    # Clean up temp file
    rm -f "$updated_task_def"
    
    print_status "ECS deployment completed!"
}

# Function to get service information
get_service_info() {
    local cluster_name=$1
    local service_name=$2
    
    print_status "Getting service details..."
    local task_arns=$(aws ecs list-tasks --cluster "$cluster_name" --service-name "$service_name" --query 'taskArns[0]' --output text --region "$AWS_DEFAULT_REGION")
    
    if [[ "$task_arns" != "None" && "$task_arns" != "null" && -n "$task_arns" ]]; then
        local public_ip=$(aws ecs describe-tasks --cluster "$cluster_name" --tasks "$task_arns" --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region "$AWS_DEFAULT_REGION" | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region "$AWS_DEFAULT_REGION")
        
        if [[ "$public_ip" != "None" && "$public_ip" != "null" && -n "$public_ip" ]]; then
            print_status "Application deployed successfully!"
            print_status "Access your application at:"
            
            # Show appropriate URLs based on service type
            if [[ "$SERVICE_NAME" == "aura-frontend-service" ]]; then
                print_status "  - 🌐 Frontend UI: http://$public_ip:80"
            elif [[ "$SERVICE_NAME" == "aura-app-service" ]]; then
                print_status "  - 🌐 Frontend UI: http://$public_ip:80 (if included)"
                print_status "  - 🔌 API Gateway: http://$public_ip:8000"
                print_status "  - 🎫 Service Desk: http://$public_ip:8001"
                print_status "  - 📚 API Documentation: http://$public_ip:8000/docs"
            else
                print_status "  - 🔌 API Gateway: http://$public_ip:8000"
                print_status "  - 🎫 Service Desk: http://$public_ip:8001"
                print_status "  - 📚 API Documentation: http://$public_ip:8000/docs"
            fi
        else
            print_warning "Could not retrieve public IP address. Check AWS console for service status."
        fi
    else
        print_warning "No running tasks found. Check AWS console for deployment status."
    fi
}

# Function to cleanup deployment
cleanup_deployment() {
    local environment=$1
    local cloud_provider=${2:-aws}
    
    print_header "Cleaning up deployment: $environment"
    
    if [[ "$environment" == "local" ]]; then
        cd "$(dirname "$0")/../.."
        docker-compose -f deploy/environments/local/docker-compose.yml down -v
        print_status "Local services stopped and volumes removed."
    elif [[ "$cloud_provider" == "aws" ]]; then
        # Set AWS region
        export AWS_DEFAULT_REGION=us-east-2
        
        # Load infrastructure configuration
        local infrastructure_file="deploy/aws/infrastructure-${environment}.json"
        if [[ ! -f "$infrastructure_file" ]]; then
            print_error "Infrastructure file not found: $infrastructure_file"
            exit 1
        fi
        
        local cluster_name=$(jq -r '.ecs_cluster' "$infrastructure_file")
        cleanup_ecs_services "$environment" "$cluster_name"
    else
        print_warning "Cloud cleanup for $cloud_provider not implemented."
    fi
}

# Function for local deployment (unchanged)
deploy_local() {
    print_header "Deploying to Local Environment"
    
    cd "$(dirname "$0")/../.." # Go to project root
    
    # Check if .env exists in aura-backend
    if [[ ! -f "aura-backend/.env" ]]; then
        print_status "Creating .env file from template..."
        cp aura-backend/.env.example aura-backend/.env
        print_warning "Please update aura-backend/.env with your OpenAI API key"
    fi
    
    # Use local docker-compose configuration
    print_status "Starting local services with Docker Compose..."
    docker-compose -f deploy/environments/local/docker-compose.yml up -d --build
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 30
    
    # Check service health
    check_local_health
    
    print_status "Local deployment completed!"
    print_status "Access the application at:"
    print_status "  - API Gateway: http://localhost:8000"
    print_status "  - Service Desk: http://localhost:8001"
    print_status "  - Frontend: http://localhost:3000 (start separately)"
    print_status "  - API Docs: http://localhost:8000/docs"
}

# Function to check local service health
check_local_health() {
    print_status "Checking service health..."
    
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://localhost:8000/health > /dev/null && \
           curl -s http://localhost:8001/health > /dev/null; then
            print_status "All services are healthy ✓"
            return 0
        fi
        
        print_status "Attempt $attempt/$max_attempts - Services not ready yet..."
        sleep 10
        ((attempt++))
    done
    
    print_warning "Services may not be fully ready. Check logs with:"
    print_status "docker-compose -f deploy/environments/local/docker-compose.yml logs"
}

# Main script logic
main() {
    # Parse options first
    local args=("$@")
    parse_options "${args[@]}"
    
    # Remove parsed options from args
    local filtered_args=()
    for arg in "${args[@]}"; do
        if [[ "$arg" != "--cleanup" && "$arg" != "--force" && "$arg" != "--no-wait" ]]; then
            filtered_args+=("$arg")
        fi
    done
    
    # Parse remaining arguments
    local environment="${filtered_args[0]:-}"
    local cloud_provider="${filtered_args[1]:-}"
    local deployment_type="${filtered_args[2]:-}"
    
    # Show usage if no arguments
    if [[ -z "$environment" ]]; then
        show_usage
    fi
    
    # Handle special commands
    case $environment in
        "cleanup")
            cleanup_deployment "${filtered_args[1]:-dev}" "${filtered_args[2]:-aws}"
            exit 0
            ;;
        "local"|"dev"|"staging"|"prod")
            ;;
        *)
            print_error "Invalid environment: $environment"
            show_usage
            ;;
    esac
    
    # Set default cloud provider for non-local environments
    if [[ "$environment" != "local" && -z "$cloud_provider" ]]; then
        cloud_provider="aws"
        print_warning "No cloud provider specified. Defaulting to AWS."
    fi
    
    # Parse deployment type for cloud deployments
    if [[ "$environment" != "local" ]]; then
        case "${deployment_type:-}" in
            "fullstack"|"full")
                deployment_type="fullstack"
                ;;
            "frontend")
                deployment_type="frontend"
                ;;
            "backend"|"")
                deployment_type="backend"
                ;;
            *)
                print_error "Invalid deployment type: ${deployment_type:-}. Use: backend, frontend, or fullstack"
                show_usage
                ;;
        esac
    else
        deployment_type="local"
    fi
    
    print_header "Aura Team Project Deployment (Improved)"
    print_status "Environment: $environment"
    if [[ "$environment" != "local" ]]; then
        print_status "Cloud Provider: $cloud_provider"
        print_status "Deployment Type: $deployment_type"
        print_status "Cleanup Before Deploy: $CLEANUP_BEFORE_DEPLOY"
        print_status "Force Deployment: $FORCE_DEPLOYMENT"
        print_status "Wait for Stabilization: $WAIT_FOR_STABILIZATION"
    fi
    
    # Check prerequisites
    check_prerequisites "$environment" "$cloud_provider"
    
    # Deploy based on environment
    case $environment in
        "local")
            deploy_local
            ;;
        *)
            case $cloud_provider in
                "aws")
                    deploy_aws_improved "$environment" "$deployment_type"
                    ;;
                *)
                    print_error "Invalid cloud provider: $cloud_provider"
                    show_usage
                    ;;
            esac
            ;;
    esac
}

# Run main function with all arguments
main "$@"
