#!/bin/bash
# Standalone Cleanup Script for Aura Team ECS Tasks
# Stops and removes duplicate/conflicting ECS services and tasks

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
    echo "Usage: $0 [ENVIRONMENT] [OPTIONS]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  dev         - Development environment (default)"
    echo "  staging     - Staging environment"
    echo "  prod        - Production environment"
    echo ""
    echo "OPTIONS:"
    echo "  --dry-run   - Show what would be cleaned up without actually doing it"
    echo "  --force     - Skip confirmation prompts"
    echo "  --all       - Clean up all task definitions and services"
    echo ""
    echo "Examples:"
    echo "  $0                    # Clean up dev environment (with confirmation)"
    echo "  $0 dev --dry-run      # Show what would be cleaned in dev"
    echo "  $0 staging --force    # Force cleanup of staging without prompts"
    echo "  $0 dev --all          # Clean up everything for dev environment"
    echo ""
    echo "This script will:"
    echo "  1. Stop all running ECS services for the environment"
    echo "  2. Delete the services from the cluster"
    echo "  3. Optionally clean up old task definitions"
    echo "  4. List remaining resources for verification"
    echo ""
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure'."
        exit 1
    fi
    
    print_status "All prerequisites checked ✓"
}

# Function to get cluster info
get_cluster_info() {
    local environment=$1
    
    # Check if infrastructure exists
    local infrastructure_file="deploy/aws/infrastructure-${environment}.json"
    if [[ ! -f "$infrastructure_file" ]]; then
        print_error "Infrastructure file not found: $infrastructure_file"
        print_status "Please run setup-aws-infrastructure.sh first:"
        print_status "  ./deploy/scripts/setup-aws-infrastructure.sh $environment"
        exit 1
    fi
    
    # Load infrastructure configuration
    CLUSTER_NAME=$(jq -r '.ecs_cluster' "$infrastructure_file")
    
    if [[ "$CLUSTER_NAME" == "null" || -z "$CLUSTER_NAME" ]]; then
        print_error "Could not find ECS cluster name in infrastructure file"
        exit 1
    fi
    
    print_status "Using ECS cluster: $CLUSTER_NAME"
}

# Function to list current services and tasks
list_current_resources() {
    local environment=$1
    
    print_header "Current ECS Resources for $environment"
    
    # List all services in the cluster
    print_status "Active Services:"
    local services=$(aws ecs list-services --cluster "$CLUSTER_NAME" --query 'serviceArns' --output text 2>/dev/null || echo "")
    
    if [[ -n "$services" && "$services" != "None" ]]; then
        for service_arn in $services; do
            local service_name=$(basename "$service_arn")
            local service_status=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service_name" --query 'services[0].status' --output text)
            local running_count=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service_name" --query 'services[0].runningCount' --output text)
            local desired_count=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service_name" --query 'services[0].desiredCount' --output text)
            
            echo "  - $service_name: $service_status (Running: $running_count, Desired: $desired_count)"
        done
    else
        echo "  No active services found"
    fi
    
    # List running tasks
    print_status "Running Tasks:"
    local tasks=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns' --output text 2>/dev/null || echo "")
    
    if [[ -n "$tasks" && "$tasks" != "None" ]]; then
        for task_arn in $tasks; do
            local task_id=$(basename "$task_arn")
            local task_status=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$task_arn" --query 'tasks[0].lastStatus' --output text)
            local task_def=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$task_arn" --query 'tasks[0].taskDefinitionArn' --output text | sed 's/.*\///')
            
            echo "  - $task_id: $task_status (Task Def: $task_def)"
        done
    else
        echo "  No running tasks found"
    fi
    
    # List task definitions for this environment
    print_status "Task Definition Families:"
    local task_families=("aura-app-${environment}" "aura-frontend-${environment}")
    
    for family in "${task_families[@]}"; do
        local task_defs=$(aws ecs list-task-definitions --family-prefix "$family" --status ACTIVE --query 'length(taskDefinitionArns)' --output text 2>/dev/null || echo "0")
        echo "  - $family: $task_defs active revisions"
    done
}

# Function to stop and remove services
cleanup_services() {
    local environment=$1
    local dry_run=$2
    local force=$3
    
    print_header "Cleaning Up ECS Services"
    
    # List of possible service names that might exist
    local service_names=("aura-app-service" "aura-frontend-service" "aura-backend-service")
    local services_to_cleanup=()
    
    # Check which services actually exist
    for service_name in "${service_names[@]}"; do
        local service_status=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$service_name" \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "NONE")
        
        if [[ "$service_status" != "NONE" && "$service_status" != "null" ]]; then
            services_to_cleanup+=("$service_name:$service_status")
            print_status "Found service: $service_name ($service_status)"
        fi
    done
    
    if [[ ${#services_to_cleanup[@]} -eq 0 ]]; then
        print_status "No services found to clean up ✓"
        return 0
    fi
    
    # Show what will be cleaned up
    print_warning "Services to be cleaned up:"
    for service_info in "${services_to_cleanup[@]}"; do
        echo "  - ${service_info%:*} (${service_info#*:})"
    done
    
    if [[ "$dry_run" == "true" ]]; then
        print_status "Dry run mode - no actual cleanup performed"
        return 0
    fi
    
    # Confirm with user unless force is specified
    if [[ "$force" != "true" ]]; then
        echo ""
        read -p "Are you sure you want to clean up these services? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleanup cancelled by user"
            return 0
        fi
    fi
    
    # Perform cleanup
    for service_info in "${services_to_cleanup[@]}"; do
        local service_name="${service_info%:*}"
        local service_status="${service_info#*:}"
        
        print_status "Cleaning up service: $service_name"
        
        if [[ "$service_status" == "ACTIVE" ]]; then
            # Scale down to 0 first
            print_status "  Scaling down to 0 tasks..."
            aws ecs update-service \
                --cluster "$CLUSTER_NAME" \
                --service "$service_name" \
                --desired-count 0 \
                --region "$AWS_DEFAULT_REGION" > /dev/null
            
            print_status "  Waiting for service to scale down..."
            aws ecs wait services-stable \
                --cluster "$CLUSTER_NAME" \
                --services "$service_name" \
                --region "$AWS_DEFAULT_REGION"
        fi
        
        # Delete the service
        print_status "  Deleting service..."
        aws ecs delete-service \
            --cluster "$CLUSTER_NAME" \
            --service "$service_name" \
            --region "$AWS_DEFAULT_REGION" > /dev/null
        
        print_status "Service $service_name deleted successfully ✓"
    done
}

# Function to cleanup task definitions
cleanup_task_definitions() {
    local environment=$1
    local dry_run=$2
    local force=$3
    local cleanup_all=$4
    
    print_header "Cleaning Up Task Definitions"
    
    local task_families=("aura-app-${environment}" "aura-frontend-${environment}")
    local total_to_cleanup=0
    
    # Count what needs to be cleaned up
    for family in "${task_families[@]}"; do
        local task_definitions
        if [[ "$cleanup_all" == "true" ]]; then
            # Clean up all task definitions for this family
            task_definitions=$(aws ecs list-task-definitions \
                --family-prefix "$family" \
                --status ACTIVE \
                --query 'taskDefinitionArns' \
                --output text 2>/dev/null || echo "")
        else
            # Keep only latest 3 revisions
            task_definitions=$(aws ecs list-task-definitions \
                --family-prefix "$family" \
                --status ACTIVE \
                --sort DESC \
                --query 'taskDefinitionArns[3:]' \
                --output text 2>/dev/null || echo "")
        fi
        
        if [[ -n "$task_definitions" && "$task_definitions" != "None" ]]; then
            local count=$(echo "$task_definitions" | wc -w)
            total_to_cleanup=$((total_to_cleanup + count))
            print_status "Family $family: $count task definitions to clean up"
        fi
    done
    
    if [[ $total_to_cleanup -eq 0 ]]; then
        print_status "No task definitions found to clean up ✓"
        return 0
    fi
    
    print_warning "Total task definitions to deregister: $total_to_cleanup"
    
    if [[ "$dry_run" == "true" ]]; then
        print_status "Dry run mode - no actual cleanup performed"
        return 0
    fi
    
    # Confirm with user unless force is specified
    if [[ "$force" != "true" ]]; then
        echo ""
        read -p "Are you sure you want to deregister these task definitions? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Task definition cleanup cancelled by user"
            return 0
        fi
    fi
    
    # Perform cleanup
    for family in "${task_families[@]}"; do
        local task_definitions
        if [[ "$cleanup_all" == "true" ]]; then
            task_definitions=$(aws ecs list-task-definitions \
                --family-prefix "$family" \
                --status ACTIVE \
                --query 'taskDefinitionArns' \
                --output text 2>/dev/null || echo "")
        else
            task_definitions=$(aws ecs list-task-definitions \
                --family-prefix "$family" \
                --status ACTIVE \
                --sort DESC \
                --query 'taskDefinitionArns[3:]' \
                --output text 2>/dev/null || echo "")
        fi
        
        if [[ -n "$task_definitions" && "$task_definitions" != "None" ]]; then
            print_status "Deregistering task definitions for family: $family"
            for task_def in $task_definitions; do
                aws ecs deregister-task-definition --task-definition "$task_def" > /dev/null
                print_status "  Deregistered: $(basename $task_def)"
            done
        fi
    done
    
    print_status "Task definition cleanup completed ✓"
}

# Function to force stop running tasks
force_stop_tasks() {
    local dry_run=$1
    local force=$2
    
    print_header "Force Stopping Running Tasks"
    
    # Get all running tasks
    local tasks=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --query 'taskArns' --output text 2>/dev/null || echo "")
    
    if [[ -z "$tasks" || "$tasks" == "None" ]]; then
        print_status "No running tasks found to stop ✓"
        return 0
    fi
    
    local task_count=$(echo "$tasks" | wc -w)
    print_warning "Found $task_count running tasks to stop"
    
    if [[ "$dry_run" == "true" ]]; then
        for task_arn in $tasks; do
            local task_id=$(basename "$task_arn")
            print_status "  Would stop: $task_id"
        done
        return 0
    fi
    
    # Confirm with user unless force is specified
    if [[ "$force" != "true" ]]; then
        echo ""
        read -p "Are you sure you want to force stop all running tasks? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Task stopping cancelled by user"
            return 0
        fi
    fi
    
    # Stop all tasks
    for task_arn in $tasks; do
        local task_id=$(basename "$task_arn")
        print_status "Stopping task: $task_id"
        aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$task_arn" --reason "Manual cleanup" > /dev/null
    done
    
    print_status "All tasks stop requested ✓"
    print_status "Tasks may take a moment to fully stop"
}

# Main function
main() {
    local environment="dev"
    local dry_run=false
    local force=false
    local cleanup_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --all)
                cleanup_all=true
                shift
                ;;
            -h|--help)
                show_usage
                ;;
            dev|staging|prod)
                environment=$1
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                ;;
        esac
    done
    
    # Set AWS region
    export AWS_DEFAULT_REGION=us-east-2
    
    print_header "Aura Team ECS Cleanup Utility"
    print_status "Environment: $environment"
    print_status "Dry Run: $dry_run"
    print_status "Force: $force"
    print_status "Cleanup All: $cleanup_all"
    
    # Check prerequisites
    check_prerequisites
    
    # Get cluster information
    get_cluster_info "$environment"
    
    # Show current state
    list_current_resources "$environment"
    
    # Perform cleanup operations
    cleanup_services "$environment" "$dry_run" "$force"
    force_stop_tasks "$dry_run" "$force"
    cleanup_task_definitions "$environment" "$dry_run" "$force" "$cleanup_all"
    
    # Show final state
    echo ""
    print_header "Final State After Cleanup"
    list_current_resources "$environment"
    
    if [[ "$dry_run" == "false" ]]; then
        print_status "Cleanup completed! ✓"
        print_status "You can now run deployments without conflicts"
    else
        print_status "Dry run completed! Use without --dry-run to perform actual cleanup"
    fi
}

# Run main function with all arguments
main "$@"
