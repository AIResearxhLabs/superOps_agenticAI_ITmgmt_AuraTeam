#!/bin/bash
# AWS Deployment Status Checker
# Comprehensive status check for AWS deployed services

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
AWS_REGION="us-east-2"
CLUSTER_NAME="aura-dev-cluster"
SERVICE_NAME="aura-app-service"

# Function to check AWS CLI and credentials
check_aws_setup() {
    print_header "Checking AWS Setup"
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi
    
    if ! aws sts get-caller-identity --region $AWS_REGION &> /dev/null; then
        print_error "AWS credentials not configured or invalid."
        print_status "Run: aws configure"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text --region $AWS_REGION)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text --region $AWS_REGION)
    
    print_status "AWS Account ID: $account_id"
    print_status "User/Role: $user_arn"
    print_status "Region: $AWS_REGION"
}

# Function to check ECS cluster and service status
check_ecs_status() {
    print_header "ECS Cluster and Service Status"
    
    # Check if cluster exists
    if ! aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION &> /dev/null; then
        print_error "ECS cluster '$CLUSTER_NAME' not found in region $AWS_REGION"
        print_status "Available clusters:"
        aws ecs list-clusters --region $AWS_REGION --query 'clusterArns' --output table
        return 1
    fi
    
    print_status "✅ ECS Cluster '$CLUSTER_NAME' found"
    
    # Get cluster details
    local cluster_status=$(aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION --query 'clusters[0].status' --output text)
    local active_services=$(aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION --query 'clusters[0].activeServicesCount' --output text)
    local running_tasks=$(aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION --query 'clusters[0].runningTasksCount' --output text)
    
    print_status "Cluster Status: $cluster_status"
    print_status "Active Services: $active_services"
    print_status "Running Tasks: $running_tasks"
    
    # Check service status
    if ! aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION &> /dev/null; then
        print_error "Service '$SERVICE_NAME' not found in cluster '$CLUSTER_NAME'"
        print_status "Available services:"
        aws ecs list-services --cluster $CLUSTER_NAME --region $AWS_REGION --query 'serviceArns' --output table
        return 1
    fi
    
    print_status "✅ Service '$SERVICE_NAME' found"
    
    # Get service details
    local service_status=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].status' --output text)
    local desired_count=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].desiredCount' --output text)
    local running_count=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].runningCount' --output text)
    local pending_count=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].pendingCount' --output text)
    
    print_status "Service Status: $service_status"
    print_status "Desired Tasks: $desired_count"
    print_status "Running Tasks: $running_count"
    print_status "Pending Tasks: $pending_count"
    
    if [ "$running_count" != "$desired_count" ]; then
        print_warning "Service not at desired capacity!"
        print_status "Checking service events for issues..."
        aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION --query 'services[0].events[:5]' --output table
    fi
}

# Function to get public IP and test endpoints
check_application_endpoints() {
    print_header "Application Endpoint Status"
    
    # Get task ARN
    local task_arn=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text)
    
    if [ "$task_arn" = "None" ] || [ "$task_arn" = "null" ] || [ -z "$task_arn" ]; then
        print_error "No running tasks found for service '$SERVICE_NAME'"
        return 1
    fi
    
    print_status "Task ARN: $task_arn"
    
    # Get network interface ID
    local eni_id=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $task_arn --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
    
    if [ "$eni_id" = "None" ] || [ "$eni_id" = "null" ] || [ -z "$eni_id" ]; then
        print_error "Could not retrieve network interface ID"
        return 1
    fi
    
    print_status "Network Interface ID: $eni_id"
    
    # Get public IP
    local public_ip=$(aws ec2 describe-network-interfaces --network-interface-ids $eni_id --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
    
    if [ "$public_ip" = "None" ] || [ "$public_ip" = "null" ] || [ -z "$public_ip" ]; then
        print_error "No public IP assigned to task"
        return 1
    fi
    
    print_status "🌐 Public IP: $public_ip"
    
    # Test endpoints
    print_header "Testing Application Endpoints"
    
    # Test API Gateway
    print_status "Testing API Gateway (port 8000)..."
    if curl -f -s --max-time 10 "http://$public_ip:8000/health" > /dev/null; then
        print_status "✅ API Gateway: Healthy"
        
        # Get detailed health info
        local api_health=$(curl -s --max-time 5 "http://$public_ip:8000/health" | jq -r '.status' 2>/dev/null || echo "unknown")
        print_status "   Status: $api_health"
    else
        print_error "❌ API Gateway: Not responding"
    fi
    
    # Test Service Desk
    print_status "Testing Service Desk (port 8001)..."
    if curl -f -s --max-time 10 "http://$public_ip:8001/health" > /dev/null; then
        print_status "✅ Service Desk: Healthy"
        
        # Get detailed health info
        local service_health=$(curl -s --max-time 5 "http://$public_ip:8001/health" | jq -r '.status' 2>/dev/null || echo "unknown")
        print_status "   Status: $service_health"
    else
        print_error "❌ Service Desk: Not responding"
    fi
    
    # Test Frontend (if deployed)
    print_status "Testing Frontend (port 80)..."
    if curl -f -s --max-time 10 "http://$public_ip:80/" > /dev/null; then
        print_status "✅ Frontend: Accessible"
    else
        print_warning "⚠️  Frontend: Not accessible (may not be deployed)"
    fi
    
    # Test API endpoints
    print_status "Testing API endpoints..."
    
    # Test tickets endpoint
    local tickets_count=$(curl -s --max-time 5 "http://$public_ip:8000/api/v1/tickets" | jq -r '.total' 2>/dev/null || echo "error")
    if [ "$tickets_count" != "error" ]; then
        print_status "✅ Tickets API: Working (${tickets_count} tickets)"
    else
        print_warning "⚠️  Tickets API: Issues detected"
    fi
    
    # Display access URLs
    print_header "🌐 Application Access URLs"
    echo "Frontend:         http://$public_ip:80"
    echo "API Gateway:      http://$public_ip:8000"
    echo "Service Desk:     http://$public_ip:8001"
    echo "API Documentation: http://$public_ip:8000/docs"
    echo "Swagger UI:       http://$public_ip:8000/docs"
}

# Function to check CloudWatch logs
check_logs() {
    print_header "Recent CloudWatch Logs"
    
    local log_group="/ecs/aura-app-dev"
    
    print_status "Checking log group: $log_group"
    
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region $AWS_REGION --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$log_group"; then
        print_status "✅ Log group exists"
        
        # Get recent log streams
        print_status "Recent log streams:"
        aws logs describe-log-streams --log-group-name "$log_group" --region $AWS_REGION --order-by LastEventTime --descending --max-items 5 --query 'logStreams[*].[logStreamName,lastEventTime]' --output table
        
        # Get recent errors
        print_status "Checking for recent errors..."
        local recent_errors=$(aws logs filter-log-events --log-group-name "$log_group" --region $AWS_REGION --start-time $(date -d '10 minutes ago' +%s)000 --filter-pattern "ERROR" --query 'events[*].message' --output text 2>/dev/null | head -5)
        
        if [ -n "$recent_errors" ]; then
            print_warning "Recent errors found:"
            echo "$recent_errors"
        else
            print_status "✅ No recent errors found"
        fi
    else
        print_warning "⚠️  Log group not found or not accessible"
    fi
}

# Function to check AWS resources and costs
check_aws_resources() {
    print_header "AWS Resources Overview"
    
    # Check ECR repositories
    print_status "ECR Repositories:"
    local ecr_repos=$(aws ecr describe-repositories --region $AWS_REGION --query 'repositories[?contains(repositoryName, `aura`)].repositoryName' --output text 2>/dev/null || echo "")
    
    if [ -n "$ecr_repos" ]; then
        echo "$ecr_repos" | tr '\t' '\n' | while read repo; do
            if [ -n "$repo" ]; then
                local image_count=$(aws ecr describe-images --repository-name "$repo" --region $AWS_REGION --query 'length(imageDetails)' --output text 2>/dev/null || echo "0")
                print_status "  $repo: $image_count images"
            fi
        done
    else
        print_warning "No ECR repositories found"
    fi
    
    # Check VPC resources
    print_status "VPC Resources:"
    local vpc_count=$(aws ec2 describe-vpcs --region $AWS_REGION --query 'length(Vpcs)' --output text 2>/dev/null || echo "0")
    local subnet_count=$(aws ec2 describe-subnets --region $AWS_REGION --query 'length(Subnets)' --output text 2>/dev/null || echo "0")
    local sg_count=$(aws ec2 describe-security-groups --region $AWS_REGION --query 'length(SecurityGroups)' --output text 2>/dev/null || echo "0")
    
    print_status "  VPCs: $vpc_count"
    print_status "  Subnets: $subnet_count"
    print_status "  Security Groups: $sg_count"
}

# Function to run performance tests
run_performance_tests() {
    print_header "Performance Tests"
    
    # Get public IP first
    local task_arn=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --region $AWS_REGION --query 'taskArns[0]' --output text)
    local eni_id=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $task_arn --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
    local public_ip=$(aws ec2 describe-network-interfaces --network-interface-ids $eni_id --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
    
    if [ "$public_ip" = "None" ] || [ -z "$public_ip" ]; then
        print_warning "Cannot run performance tests - no public IP available"
        return 1
    fi
    
    print_status "Running performance tests against $public_ip..."
    
    # Test API Gateway response time
    local api_time=$(curl -o /dev/null -s -w '%{time_total}\n' "http://$public_ip:8000/health")
    print_status "API Gateway response time: ${api_time}s"
    
    # Test Service Desk response time
    local service_time=$(curl -o /dev/null -s -w '%{time_total}\n' "http://$public_ip:8001/health")
    print_status "Service Desk response time: ${service_time}s"
    
    # Test multiple requests for average
    print_status "Running load test (10 requests)..."
    local total_time=0
    for i in {1..10}; do
        local req_time=$(curl -o /dev/null -s -w '%{time_total}\n' "http://$public_ip:8000/health")
        total_time=$(echo "$total_time + $req_time" | bc -l)
    done
    local avg_time=$(echo "scale=3; $total_time / 10" | bc -l)
    print_status "Average response time (10 requests): ${avg_time}s"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cluster NAME     ECS cluster name (default: $CLUSTER_NAME)"
    echo "  --service NAME     ECS service name (default: $SERVICE_NAME)"
    echo "  --region REGION    AWS region (default: $AWS_REGION)"
    echo "  --performance      Run performance tests"
    echo "  --logs             Show recent logs"
    echo "  --resources        Show AWS resources overview"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Basic status check"
    echo "  $0 --performance             # Include performance tests"
    echo "  $0 --logs --resources        # Include logs and resource overview"
    echo "  $0 --cluster my-cluster      # Use different cluster"
}

# Main function
main() {
    local run_performance=false
    local show_logs=false
    local show_resources=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cluster)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --service)
                SERVICE_NAME="$2"
                shift 2
                ;;
            --region)
                AWS_REGION="$2"
                shift 2
                ;;
            --performance)
                run_performance=true
                shift
                ;;
            --logs)
                show_logs=true
                shift
                ;;
            --resources)
                show_resources=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_header "AWS Deployment Status Check"
    print_status "Cluster: $CLUSTER_NAME"
    print_status "Service: $SERVICE_NAME"
    print_status "Region: $AWS_REGION"
    
    # Run checks
    check_aws_setup
    check_ecs_status
    check_application_endpoints
    
    [ "$show_logs" = true ] && check_logs
    [ "$show_resources" = true ] && check_aws_resources
    [ "$run_performance" = true ] && run_performance_tests
    
    print_header "Status Check Complete"
    print_status "🎉 AWS deployment status check finished!"
}

# Run main function with all arguments
main "$@"
