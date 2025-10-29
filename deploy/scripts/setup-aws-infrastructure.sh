#!/bin/bash
# AWS Infrastructure Setup Script for Aura Team Project
# Creates necessary AWS resources for ECS Fargate deployment

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

# Configuration
AWS_REGION="${AWS_REGION:-us-east-2}"
PROJECT_NAME="aura"
ENVIRONMENT="${1:-dev}"

# Derived names
VPC_NAME="${PROJECT_NAME}-${ENVIRONMENT}-vpc"
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
SECURITY_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-sg"
SUBNET_PUBLIC_1_NAME="${PROJECT_NAME}-${ENVIRONMENT}-public-1"
SUBNET_PUBLIC_2_NAME="${PROJECT_NAME}-${ENVIRONMENT}-public-2"
SUBNET_PRIVATE_1_NAME="${PROJECT_NAME}-${ENVIRONMENT}-private-1"
SUBNET_PRIVATE_2_NAME="${PROJECT_NAME}-${ENVIRONMENT}-private-2"
IGW_NAME="${PROJECT_NAME}-${ENVIRONMENT}-igw"
NAT_GW_NAME="${PROJECT_NAME}-${ENVIRONMENT}-nat"

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
    echo "  $0 dev      # Setup AWS infrastructure for development"
    echo "  $0 staging  # Setup AWS infrastructure for staging"
    echo ""
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI."
        print_status "Install instructions: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure'."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq for JSON parsing."
        print_status "Install with: brew install jq (macOS) or sudo apt-get install jq (Ubuntu)"
        exit 1
    fi
    
    print_status "All prerequisites checked ✓"
    
    # Display current AWS identity
    local aws_identity=$(aws sts get-caller-identity)
    local account_id=$(echo "$aws_identity" | jq -r '.Account')
    local user_arn=$(echo "$aws_identity" | jq -r '.Arn')
    
    print_status "AWS Account ID: $account_id"
    print_status "AWS User/Role: $user_arn"
    print_status "AWS Region: $AWS_REGION"
}

# Function to create VPC
create_vpc() {
    print_header "Creating VPC Infrastructure"
    
    # Check if VPC already exists
    local existing_vpc=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=$VPC_NAME" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "None")
    
    if [[ "$existing_vpc" != "None" && "$existing_vpc" != "null" ]]; then
        print_status "VPC already exists: $existing_vpc"
        VPC_ID="$existing_vpc"
        return 0
    fi
    
    # Create VPC
    print_status "Creating VPC: $VPC_NAME"
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block 10.0.0.0/16 \
        --query 'Vpc.VpcId' \
        --output text \
        --region "$AWS_REGION")
    
    # Tag VPC
    aws ec2 create-tags \
        --resources "$VPC_ID" \
        --tags Key=Name,Value="$VPC_NAME" \
        --region "$AWS_REGION"
    
    # Enable DNS hostnames
    aws ec2 modify-vpc-attribute \
        --vpc-id "$VPC_ID" \
        --enable-dns-hostnames \
        --region "$AWS_REGION"
    
    print_status "VPC created: $VPC_ID"
}

# Function to create subnets
create_subnets() {
    print_header "Creating Subnets"
    
    # Get availability zones
    local az1=$(aws ec2 describe-availability-zones \
        --query 'AvailabilityZones[0].ZoneName' \
        --output text \
        --region "$AWS_REGION")
    local az2=$(aws ec2 describe-availability-zones \
        --query 'AvailabilityZones[1].ZoneName' \
        --output text \
        --region "$AWS_REGION")
    
    # Create public subnet 1
    print_status "Creating public subnet 1 in $az1"
    PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block 10.0.1.0/24 \
        --availability-zone "$az1" \
        --query 'Subnet.SubnetId' \
        --output text \
        --region "$AWS_REGION")
    
    aws ec2 create-tags \
        --resources "$PUBLIC_SUBNET_1_ID" \
        --tags Key=Name,Value="$SUBNET_PUBLIC_1_NAME" \
        --region "$AWS_REGION"
    
    # Create public subnet 2
    print_status "Creating public subnet 2 in $az2"
    PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block 10.0.2.0/24 \
        --availability-zone "$az2" \
        --query 'Subnet.SubnetId' \
        --output text \
        --region "$AWS_REGION")
    
    aws ec2 create-tags \
        --resources "$PUBLIC_SUBNET_2_ID" \
        --tags Key=Name,Value="$SUBNET_PUBLIC_2_NAME" \
        --region "$AWS_REGION"
    
    # Create private subnet 1
    print_status "Creating private subnet 1 in $az1"
    PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block 10.0.11.0/24 \
        --availability-zone "$az1" \
        --query 'Subnet.SubnetId' \
        --output text \
        --region "$AWS_REGION")
    
    aws ec2 create-tags \
        --resources "$PRIVATE_SUBNET_1_ID" \
        --tags Key=Name,Value="$SUBNET_PRIVATE_1_NAME" \
        --region "$AWS_REGION"
    
    # Create private subnet 2
    print_status "Creating private subnet 2 in $az2"
    PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block 10.0.12.0/24 \
        --availability-zone "$az2" \
        --query 'Subnet.SubnetId' \
        --output text \
        --region "$AWS_REGION")
    
    aws ec2 create-tags \
        --resources "$PRIVATE_SUBNET_2_ID" \
        --tags Key=Name,Value="$SUBNET_PRIVATE_2_NAME" \
        --region "$AWS_REGION"
    
    print_status "Subnets created successfully"
}

# Function to create internet gateway
create_internet_gateway() {
    print_header "Creating Internet Gateway"
    
    # Create Internet Gateway
    print_status "Creating Internet Gateway: $IGW_NAME"
    IGW_ID=$(aws ec2 create-internet-gateway \
        --query 'InternetGateway.InternetGatewayId' \
        --output text \
        --region "$AWS_REGION")
    
    # Tag Internet Gateway
    aws ec2 create-tags \
        --resources "$IGW_ID" \
        --tags Key=Name,Value="$IGW_NAME" \
        --region "$AWS_REGION"
    
    # Attach to VPC
    aws ec2 attach-internet-gateway \
        --internet-gateway-id "$IGW_ID" \
        --vpc-id "$VPC_ID" \
        --region "$AWS_REGION"
    
    print_status "Internet Gateway created and attached: $IGW_ID"
}

# Function to create NAT Gateway
create_nat_gateway() {
    print_header "Creating NAT Gateway"
    
    # Allocate Elastic IP
    print_status "Allocating Elastic IP for NAT Gateway"
    EIP_ALLOCATION_ID=$(aws ec2 allocate-address \
        --domain vpc \
        --query 'AllocationId' \
        --output text \
        --region "$AWS_REGION")
    
    # Create NAT Gateway
    print_status "Creating NAT Gateway: $NAT_GW_NAME"
    NAT_GW_ID=$(aws ec2 create-nat-gateway \
        --subnet-id "$PUBLIC_SUBNET_1_ID" \
        --allocation-id "$EIP_ALLOCATION_ID" \
        --query 'NatGateway.NatGatewayId' \
        --output text \
        --region "$AWS_REGION")
    
    # Tag NAT Gateway
    aws ec2 create-tags \
        --resources "$NAT_GW_ID" \
        --tags Key=Name,Value="$NAT_GW_NAME" \
        --region "$AWS_REGION"
    
    # Wait for NAT Gateway to be available
    print_status "Waiting for NAT Gateway to be available..."
    aws ec2 wait nat-gateway-available \
        --nat-gateway-ids "$NAT_GW_ID" \
        --region "$AWS_REGION"
    
    print_status "NAT Gateway created: $NAT_GW_ID"
}

# Function to create route tables
create_route_tables() {
    print_header "Creating Route Tables"
    
    # Create public route table
    print_status "Creating public route table"
    PUBLIC_RT_ID=$(aws ec2 create-route-table \
        --vpc-id "$VPC_ID" \
        --query 'RouteTable.RouteTableId' \
        --output text \
        --region "$AWS_REGION")
    
    aws ec2 create-tags \
        --resources "$PUBLIC_RT_ID" \
        --tags Key=Name,Value="${PROJECT_NAME}-${ENVIRONMENT}-public-rt" \
        --region "$AWS_REGION"
    
    # Add route to Internet Gateway
    aws ec2 create-route \
        --route-table-id "$PUBLIC_RT_ID" \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id "$IGW_ID" \
        --region "$AWS_REGION"
    
    # Associate public subnets
    aws ec2 associate-route-table \
        --subnet-id "$PUBLIC_SUBNET_1_ID" \
        --route-table-id "$PUBLIC_RT_ID" \
        --region "$AWS_REGION"
    
    aws ec2 associate-route-table \
        --subnet-id "$PUBLIC_SUBNET_2_ID" \
        --route-table-id "$PUBLIC_RT_ID" \
        --region "$AWS_REGION"
    
    # Create private route table
    print_status "Creating private route table"
    PRIVATE_RT_ID=$(aws ec2 create-route-table \
        --vpc-id "$VPC_ID" \
        --query 'RouteTable.RouteTableId' \
        --output text \
        --region "$AWS_REGION")
    
    aws ec2 create-tags \
        --resources "$PRIVATE_RT_ID" \
        --tags Key=Name,Value="${PROJECT_NAME}-${ENVIRONMENT}-private-rt" \
        --region "$AWS_REGION"
    
    # Add route to NAT Gateway
    aws ec2 create-route \
        --route-table-id "$PRIVATE_RT_ID" \
        --destination-cidr-block 0.0.0.0/0 \
        --nat-gateway-id "$NAT_GW_ID" \
        --region "$AWS_REGION"
    
    # Associate private subnets
    aws ec2 associate-route-table \
        --subnet-id "$PRIVATE_SUBNET_1_ID" \
        --route-table-id "$PRIVATE_RT_ID" \
        --region "$AWS_REGION"
    
    aws ec2 associate-route-table \
        --subnet-id "$PRIVATE_SUBNET_2_ID" \
        --route-table-id "$PRIVATE_RT_ID" \
        --region "$AWS_REGION"
    
    print_status "Route tables created and associated"
}

# Function to create security groups
create_security_groups() {
    print_header "Creating Security Groups"
    
    # Create ECS security group
    print_status "Creating ECS security group: $SECURITY_GROUP_NAME"
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "Security group for Aura ECS tasks" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' \
        --output text \
        --region "$AWS_REGION")
    
    # Tag security group
    aws ec2 create-tags \
        --resources "$SG_ID" \
        --tags Key=Name,Value="$SECURITY_GROUP_NAME" \
        --region "$AWS_REGION"
    
    # Add ingress rules
    # HTTP (80 - Frontend)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    # HTTP (8000 - API Gateway)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 8000 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    # HTTP (8001 - Service Desk)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 8001 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    # Database ports (internal communication)
    for port in 5432 6379 27017; do
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port "$port" \
            --source-group "$SG_ID" \
            --region "$AWS_REGION"
    done
    
    # HTTPS (443)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"
    
    print_status "Security group created: $SG_ID"
}

# Function to create ECS cluster
create_ecs_cluster() {
    print_header "Creating ECS Cluster"
    
    # Check if cluster already exists
    local existing_cluster=$(aws ecs describe-clusters \
        --clusters "$CLUSTER_NAME" \
        --query 'clusters[0].status' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "None")
    
    if [[ "$existing_cluster" == "ACTIVE" ]]; then
        print_status "ECS cluster already exists and is active: $CLUSTER_NAME"
        return 0
    fi
    
    # Create ECS cluster
    print_status "Creating ECS cluster: $CLUSTER_NAME"
    aws ecs create-cluster \
        --cluster-name "$CLUSTER_NAME" \
        --capacity-providers FARGATE \
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
        --region "$AWS_REGION"
    
    print_status "ECS cluster created: $CLUSTER_NAME"
}

# Function to create IAM roles
create_iam_roles() {
    print_header "Creating IAM Roles"
    
    # ECS Task Execution Role
    local task_execution_role_name="ecsTaskExecutionRole"
    if ! aws iam get-role --role-name "$task_execution_role_name" &>/dev/null; then
        print_status "Creating ECS Task Execution Role"
        
        # Create trust policy
        cat > /tmp/ecs-task-execution-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
        
        aws iam create-role \
            --role-name "$task_execution_role_name" \
            --assume-role-policy-document file:///tmp/ecs-task-execution-trust-policy.json \
            --region "$AWS_REGION"
        
        # Attach managed policy
        aws iam attach-role-policy \
            --role-name "$task_execution_role_name" \
            --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
            --region "$AWS_REGION"
        
        # Add policy for SSM parameter access (for secrets)
        aws iam attach-role-policy \
            --role-name "$task_execution_role_name" \
            --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess \
            --region "$AWS_REGION"
        
        print_status "ECS Task Execution Role created"
    else
        print_status "ECS Task Execution Role already exists"
    fi
    
    # ECS Task Role
    local task_role_name="ecsTaskRole"
    if ! aws iam get-role --role-name "$task_role_name" &>/dev/null; then
        print_status "Creating ECS Task Role"
        
        aws iam create-role \
            --role-name "$task_role_name" \
            --assume-role-policy-document file:///tmp/ecs-task-execution-trust-policy.json \
            --region "$AWS_REGION"
        
        # Create custom policy for task role
        cat > /tmp/ecs-task-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:${AWS_REGION}:*:parameter/aura/*"
    }
  ]
}
EOF
        
        aws iam put-role-policy \
            --role-name "$task_role_name" \
            --policy-name "AuraTaskPolicy" \
            --policy-document file:///tmp/ecs-task-policy.json \
            --region "$AWS_REGION"
        
        print_status "ECS Task Role created"
    else
        print_status "ECS Task Role already exists"
    fi
    
    # Clean up temp files
    rm -f /tmp/ecs-task-execution-trust-policy.json /tmp/ecs-task-policy.json
}

# Function to create SSM parameters
create_ssm_parameters() {
    print_header "Creating SSM Parameters"
    
    print_status "Creating SSM parameter for OpenAI API key"
    print_warning "Please update the OpenAI API key in AWS Systems Manager Parameter Store:"
    print_status "Parameter name: /aura/${ENVIRONMENT}/openai-api-key"
    print_status "AWS Console: https://${AWS_REGION}.console.aws.amazon.com/systems-manager/parameters"
    
    # Create placeholder parameter if it doesn't exist
    if ! aws ssm get-parameter --name "/aura/${ENVIRONMENT}/openai-api-key" --region "$AWS_REGION" &>/dev/null; then
        aws ssm put-parameter \
            --name "/aura/${ENVIRONMENT}/openai-api-key" \
            --value "your_openai_api_key_here" \
            --type "SecureString" \
            --description "OpenAI API key for Aura ${ENVIRONMENT} environment" \
            --region "$AWS_REGION"
        
        print_status "Placeholder SSM parameter created. Please update with actual API key."
    else
        print_status "SSM parameter already exists"
    fi
}

# Function to create CloudWatch log group
create_cloudwatch_log_group() {
    print_header "Creating CloudWatch Log Group"
    
    local log_group="/ecs/aura-app-${ENVIRONMENT}"
    
    if ! aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0].logGroupName' --output text --region "$AWS_REGION" 2>/dev/null | grep -q "$log_group"; then
        print_status "Creating CloudWatch log group: $log_group"
        aws logs create-log-group \
            --log-group-name "$log_group" \
            --retention-in-days 7 \
            --region "$AWS_REGION"
        
        print_status "CloudWatch log group created"
    else
        print_status "CloudWatch log group already exists"
    fi
}

# Function to output configuration
output_configuration() {
    print_header "Infrastructure Setup Complete"
    
    print_status "AWS Infrastructure Summary:"
    print_status "  VPC ID: $VPC_ID"
    print_status "  Public Subnets: $PUBLIC_SUBNET_1_ID, $PUBLIC_SUBNET_2_ID"
    print_status "  Private Subnets: $PRIVATE_SUBNET_1_ID, $PRIVATE_SUBNET_2_ID"
    print_status "  Security Group: $SG_ID"
    print_status "  ECS Cluster: $CLUSTER_NAME"
    print_status "  Region: $AWS_REGION"
    
    # Save configuration to file
    local config_file="deploy/aws/infrastructure-${ENVIRONMENT}.json"
    cat > "$config_file" << EOF
{
  "environment": "$ENVIRONMENT",
  "region": "$AWS_REGION",
  "vpc_id": "$VPC_ID",
  "public_subnets": ["$PUBLIC_SUBNET_1_ID", "$PUBLIC_SUBNET_2_ID"],
  "private_subnets": ["$PRIVATE_SUBNET_1_ID", "$PRIVATE_SUBNET_2_ID"],
  "security_group_id": "$SG_ID",
  "ecs_cluster": "$CLUSTER_NAME",
  "internet_gateway_id": "$IGW_ID",
  "nat_gateway_id": "$NAT_GW_ID"
}
EOF
    
    print_status "Configuration saved to: $config_file"
    
    print_header "Next Steps"
    print_status "1. Update OpenAI API key in AWS Systems Manager:"
    print_status "   aws ssm put-parameter --name '/aura/${ENVIRONMENT}/openai-api-key' --value 'your_actual_api_key' --type 'SecureString' --overwrite --region $AWS_REGION"
    print_status ""
    print_status "2. Deploy the application:"
    print_status "   ./deploy/scripts/deploy.sh $ENVIRONMENT aws"
    print_status ""
    print_status "3. Monitor deployment in AWS Console:"
    print_status "   ECS: https://${AWS_REGION}.console.aws.amazon.com/ecs/home?region=${AWS_REGION}#/clusters"
    print_status "   CloudWatch: https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups"
}

# Main script logic
main() {
    local environment="${1:-dev}"
    
    # Validate environment
    case $environment in
        "dev"|"staging"|"prod")
            ;;
        *)
            print_error "Invalid environment: $environment"
            show_usage
            ;;
    esac
    
    print_header "AWS Infrastructure Setup for Aura Project"
    print_status "Environment: $environment"
    print_status "Region: $AWS_REGION"
    
    # Check prerequisites
    check_prerequisites
    
    # Create infrastructure components
    create_vpc
    create_subnets
    create_internet_gateway
    create_nat_gateway
    create_route_tables
    create_security_groups
    create_ecs_cluster
    create_iam_roles
    create_ssm_parameters
    create_cloudwatch_log_group
    
    # Output results
    output_configuration
}

# Run main function with all arguments
main "$@"
