#!/bin/bash
# Frontend-Only Deployment Script for Aura Team Project
# Quick deployment script specifically for frontend updates

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
    echo "Usage: $0 [ENVIRONMENT]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  dev         - Development environment (default)"
    echo "  staging     - Staging environment"
    echo "  prod        - Production environment"
    echo ""
    echo "Examples:"
    echo "  $0           # Deploy frontend to dev environment"
    echo "  $0 dev       # Deploy frontend to dev environment"
    echo "  $0 staging   # Deploy frontend to staging environment"
    echo ""
    echo "This script will:"
    echo "  1. Build the React frontend with production optimizations"
    echo "  2. Push the frontend Docker image to ECR"
    echo "  3. Deploy only the frontend service to ECS"
    echo "  4. Display the frontend URL when deployment is complete"
    echo ""
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker."
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure'."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    print_status "All prerequisites checked ✓"
}

# Main deployment function
deploy_frontend() {
    local environment=${1:-dev}
    
    print_header "Frontend-Only Deployment to $environment"
    
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
    
    # Get AWS account ID and ECR URI
    local aws_account_id=$(aws sts get-caller-identity --query Account --output text)
    local ecr_uri="${aws_account_id}.dkr.ecr.us-east-2.amazonaws.com"
    
    # Login to ECR
    print_status "Logging into ECR..."
    aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin "$ecr_uri"
    
    # Create ECR repository if it doesn't exist
    if ! aws ecr describe-repositories --repository-names "aura-frontend" &> /dev/null; then
        print_status "Creating ECR repository: aura-frontend"
        aws ecr create-repository --repository-name "aura-frontend" --region us-east-2
    fi
    
    # Build frontend image
    print_status "Building Frontend Docker image..."
    cd "$(dirname "$0")/../.." # Go to project root
    
    # Set API URL for production build
    export REACT_APP_API_BASE_URL="http://127.0.0.1:8000"
    
    docker build -t aura-frontend aura-frontend/
    docker tag aura-frontend:latest "$ecr_uri/aura-frontend:latest"
    
    # Push image to ECR
    print_status "Pushing Frontend image to ECR..."
    docker push "$ecr_uri/aura-frontend:latest"
    
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
    
    # Prepare task definition
    local task_def_file="deploy/aws/ecs/task-definition-frontend-only.json"
    local updated_task_def="/tmp/task-definition-frontend-${environment}.json"
    local service_name="aura-frontend-service"
    local task_family="aura-frontend-${environment}"
    
    # Replace account ID in task definition
    sed "s/753353727891/$aws_account_id/g" "$task_def_file" > "$updated_task_def"
    
    # Create CloudWatch log group for frontend
    local log_group="/ecs/aura-frontend-${environment}"
    if ! aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        print_status "Creating CloudWatch log group: $log_group"
        aws logs create-log-group --log-group-name "$log_group"
        aws logs put-retention-policy --log-group-name "$log_group" --retention-in-days 7
    fi
    
    # Register task definition
    print_status "Registering ECS task definition..."
    local task_def_arn=$(aws ecs register-task-definition --cli-input-json file://"$updated_task_def" --query 'taskDefinition.taskDefinitionArn' --output text)
    print_status "Task definition registered: $task_def_arn"
    
    # Create or update ECS service
    if aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --query 'services[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
        print_status "Updating existing ECS service: $service_name"
        aws ecs update-service \
            --cluster "$cluster_name" \
            --service "$service_name" \
            --task-definition "$task_family" \
            --region "$AWS_DEFAULT_REGION"
    else
        print_status "Creating new ECS service: $service_name"
        aws ecs create-service \
            --cluster "$cluster_name" \
            --service-name "$service_name" \
            --task-definition "$task_family" \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[$public_subnets],securityGroups=[$security_group_id],assignPublicIp=ENABLED}" \
            --region "$AWS_DEFAULT_REGION"
    fi
    
    # Wait for service to stabilize
    print_status "Waiting for ECS service to stabilize..."
    aws ecs wait services-stable --cluster "$cluster_name" --services "$service_name" --region "$AWS_DEFAULT_REGION"
    
    # Get service status and public IP
    print_status "Getting service details..."
    local task_arns=$(aws ecs list-tasks --cluster "$cluster_name" --service-name "$service_name" --query 'taskArns[0]' --output text --region "$AWS_DEFAULT_REGION")
    
    if [[ "$task_arns" != "None" && "$task_arns" != "null" ]]; then
        local public_ip=$(aws ecs describe-tasks --cluster "$cluster_name" --tasks "$task_arns" --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region "$AWS_DEFAULT_REGION" | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region "$AWS_DEFAULT_REGION")
        
        if [[ "$public_ip" != "None" && "$public_ip" != "null" ]]; then
            print_status "Frontend deployment completed successfully!"
            print_status ""
            print_status "🌐 Frontend URL: http://$public_ip:80"
            print_status ""
            print_status "Note: Make sure your backend services are running at:"
            print_status "  - API Gateway: http://$public_ip:8000 (if using same infrastructure)"
            print_status "  - Service Desk: http://$public_ip:8001 (if using same infrastructure)"
        else
            print_warning "Could not retrieve public IP address. Check AWS console for service status."
        fi
    else
        print_warning "No running tasks found. Check AWS console for deployment status."
    fi
    
    # Clean up temp file
    rm -f "$updated_task_def"
    
    print_status "Frontend-only deployment completed!"
}

# Main script logic
main() {
    local environment="${1:-dev}"
    
    # Show usage if help requested
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
    fi
    
    # Validate environment
    case $environment in
        "dev"|"staging"|"prod")
            ;;
        *)
            print_error "Invalid environment: $environment"
            print_status "Valid environments: dev, staging, prod"
            show_usage
            ;;
    esac
    
    print_header "Aura Frontend Deployment"
    print_status "Environment: $environment"
    print_status "Deployment Type: Frontend Only"
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy frontend
    deploy_frontend "$environment"
}

# Run main function with all arguments
main "$@"
