#!/bin/bash
# AWS Demo Infrastructure Setup Script for Aura Team Project
# Cost-optimized setup for demonstration purposes using public subnets
# Estimated cost: ~$15-20/month vs $50/month for full production setup

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

print_cost_saving() {
    echo -e "${GREEN}[COST-SAVING]${NC} $1"
}

# Configuration
AWS_REGION="${AWS_REGION:-us-east-2}"
PROJECT_NAME="aura"
ENVIRONMENT="${1:-dev}"

# Derived names
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
SECURITY_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-demo-sg"

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
    echo "  $0 dev      # Setup cost-optimized AWS demo infrastructure"
    echo "  $0 staging  # Setup staging demo infrastructure"
    echo ""
    echo "COST-OPTIMIZED DEMO SETUP:"
    echo "  - Uses AWS Default VPC (no custom VPC creation)"
    echo "  - Public subnets only (no NAT Gateway = saves ~$32/month)"
    echo "  - Minimal security groups"
    echo "  - Essential components only"
    echo "  - Remote access from anywhere enabled"
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
    
    print_cost_saving "Using cost-optimized demo setup (saves ~$32/month)"
}

# Function to get default VPC information
get_default_vpc_info() {
    print_header "Using AWS Default VPC (Cost Optimization)"
    
    # Get default VPC ID
    DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --region "$AWS_REGION")
    
    if [[ "$DEFAULT_VPC_ID" == "None" || "$DEFAULT_VPC_ID" == "null" ]]; then
        print_error "No default VPC found. Creating one..."
        aws ec2 create-default-vpc --region "$AWS_REGION"
        DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
            --filters "Name=is-default,Values=true" \
            --query 'Vpcs[0].VpcId' \
            --output text \
            --region "$AWS_REGION")
    fi
    
    print_status "Using Default VPC: $DEFAULT_VPC_ID"
    print_cost_saving "Skipping custom VPC creation (saves setup complexity)"
    
    # Get default subnets (all are public by default)
    DEFAULT_SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" "Name=default-for-az,Values=true" \
        --query 'Subnets[*].SubnetId' \
        --output text \
        --region "$AWS_REGION")
    
    # Convert to array
    PUBLIC_SUBNETS=($DEFAULT_SUBNETS)
    
    if [[ ${#PUBLIC_SUBNETS[@]} -lt 2 ]]; then
        print_error "Need at least 2 subnets for ECS service. Found: ${#PUBLIC_SUBNETS[@]}"
        exit 1
    fi
    
    print_status "Using Default Public Subnets: ${PUBLIC_SUBNETS[0]}, ${PUBLIC_SUBNETS[1]}"
    print_cost_saving "No NAT Gateway needed (saves ~$32/month)"
}

# Function to create security group
create_security_group() {
    print_header "Creating Demo Security Group"
    
    # Check if security group already exists
    local existing_sg=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "None")
    
    if [[ "$existing_sg" != "None" && "$existing_sg" != "null" ]]; then
        print_status "Security group already exists: $existing_sg"
        SG_ID="$existing_sg"
        return 0
    fi
    
    # Create security group
    print_status "Creating security group: $SECURITY_GROUP_NAME"
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "Demo security group for Aura ECS tasks - allows remote access" \
        --vpc-id "$DEFAULT_VPC_ID" \
        --query 'GroupId' \
        --output text \
        --region "$AWS_REGION")
    
    # Tag security group
    aws ec2 create-tags \
        --resources "$SG_ID" \
        --tags Key=Name,Value="$SECURITY_GROUP_NAME" Key=Environment,Value="$ENVIRONMENT" Key=Purpose,Value="Demo" \
        --region "$AWS_REGION"
    
    # Add ingress rules for remote access
    print_status "Configuring security group for remote access..."
    
    # Function to add security group rule if it doesn't exist
    add_sg_rule_if_not_exists() {
        local group_id="$1"
        local protocol="$2"
        local port="$3"
        local cidr="$4"
        local source_group="$5"
        
        # Check if rule already exists
        if [[ -n "$source_group" ]]; then
            # Rule with source security group
            local existing_rule=$(aws ec2 describe-security-groups \
                --group-ids "$group_id" \
                --query "SecurityGroups[0].IpPermissions[?IpProtocol=='$protocol' && FromPort==$port && ToPort==$port && UserIdGroupPairs[0].GroupId=='$source_group']" \
                --output text \
                --region "$AWS_REGION" 2>/dev/null)
        else
            # Rule with CIDR
            local existing_rule=$(aws ec2 describe-security-groups \
                --group-ids "$group_id" \
                --query "SecurityGroups[0].IpPermissions[?IpProtocol=='$protocol' && FromPort==$port && ToPort==$port && IpRanges[0].CidrIp=='$cidr']" \
                --output text \
                --region "$AWS_REGION" 2>/dev/null)
        fi
        
        if [[ -z "$existing_rule" || "$existing_rule" == "None" ]]; then
            # Rule doesn't exist, add it
            if [[ -n "$source_group" ]]; then
                print_status "Adding rule: $protocol/$port from security group $source_group"
                aws ec2 authorize-security-group-ingress \
                    --group-id "$group_id" \
                    --protocol "$protocol" \
                    --port "$port" \
                    --source-group "$source_group" \
                    --region "$AWS_REGION" >/dev/null 2>&1
            else
                print_status "Adding rule: $protocol/$port from $cidr"
                aws ec2 authorize-security-group-ingress \
                    --group-id "$group_id" \
                    --protocol "$protocol" \
                    --port "$port" \
                    --cidr "$cidr" \
                    --region "$AWS_REGION" >/dev/null 2>&1
            fi
        else
            print_status "Rule already exists: $protocol/$port"
        fi
    }
    
    # API Gateway (8000) - accessible from anywhere
    add_sg_rule_if_not_exists "$SG_ID" "tcp" "8000" "0.0.0.0/0" ""
    
    # Service Desk (8001) - accessible from anywhere  
    add_sg_rule_if_not_exists "$SG_ID" "tcp" "8001" "0.0.0.0/0" ""
    
    # HTTPS (443) - for SSL if needed
    add_sg_rule_if_not_exists "$SG_ID" "tcp" "443" "0.0.0.0/0" ""
    
    # Internal communication between containers (same security group)
    for port in 5432 6379 27017; do
        add_sg_rule_if_not_exists "$SG_ID" "tcp" "$port" "" "$SG_ID"
    done
    
    print_status "Security group created: $SG_ID"
    print_status "Remote access enabled on ports 8000 (API Gateway) and 8001 (Service Desk)"
}

# Function to create ECS service-linked role
create_ecs_service_linked_role() {
    print_header "Creating ECS Service-Linked Role"
    
    # Check if ECS service-linked role already exists
    if aws iam get-role --role-name AWSServiceRoleForECS &>/dev/null; then
        print_status "ECS service-linked role already exists"
        return 0
    fi
    
    print_status "Creating ECS service-linked role (required for new AWS accounts)"
    
    # Create ECS service-linked role
    if aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com --region "$AWS_REGION" 2>/dev/null; then
        print_status "ECS service-linked role created successfully"
        
        # Wait a moment for role to propagate
        print_status "Waiting for role to propagate..."
        sleep 10
    else
        # Role might already exist or be in process of creation
        print_status "ECS service-linked role creation skipped (may already exist)"
    fi
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
    
    # Ensure ECS service-linked role exists
    create_ecs_service_linked_role
    
    # Create ECS cluster
    print_status "Creating ECS cluster: $CLUSTER_NAME"
    aws ecs create-cluster \
        --cluster-name "$CLUSTER_NAME" \
        --capacity-providers FARGATE \
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
        --tags key=Environment,value="$ENVIRONMENT" key=Purpose,value="Demo" \
        --region "$AWS_REGION" \
        --output text > /dev/null
    
    print_status "ECS cluster created: $CLUSTER_NAME"
    print_cost_saving "Using Fargate (pay-per-use, no EC2 instances to manage)"
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
            --tags Key=Environment,Value="$ENVIRONMENT" Key=Purpose,Value="Demo" \
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
        
        # Create log group first
        aws logs create-log-group \
            --log-group-name "$log_group" \
            --region "$AWS_REGION"
        
        # Set retention policy separately
        aws logs put-retention-policy \
            --log-group-name "$log_group" \
            --retention-in-days 7 \
            --region "$AWS_REGION"
        
        print_status "CloudWatch log group created with 7-day retention"
    else
        print_status "CloudWatch log group already exists"
    fi
}

# Function to output configuration
output_configuration() {
    print_header "Demo Infrastructure Setup Complete"
    
    print_status "AWS Demo Infrastructure Summary:"
    print_status "  Default VPC ID: $DEFAULT_VPC_ID"
    print_status "  Public Subnets: ${PUBLIC_SUBNETS[0]}, ${PUBLIC_SUBNETS[1]}"
    print_status "  Security Group: $SG_ID"
    print_status "  ECS Cluster: $CLUSTER_NAME"
    print_status "  Region: $AWS_REGION"
    
    # Save configuration to file
    local config_file="deploy/aws/infrastructure-demo-${ENVIRONMENT}.json"
    cat > "$config_file" << EOF
{
  "setup_type": "demo",
  "environment": "$ENVIRONMENT",
  "region": "$AWS_REGION",
  "vpc_id": "$DEFAULT_VPC_ID",
  "public_subnets": ["${PUBLIC_SUBNETS[0]}", "${PUBLIC_SUBNETS[1]}"],
  "security_group_id": "$SG_ID",
  "ecs_cluster": "$CLUSTER_NAME",
  "cost_optimized": true,
  "remote_access_enabled": true
}
EOF
    
    print_status "Configuration saved to: $config_file"
    
    print_header "Cost Savings Summary"
    print_cost_saving "💰 NAT Gateway: Saved ~$32/month (using public subnets)"
    print_cost_saving "💰 Custom VPC: Saved setup complexity (using default VPC)"
    print_cost_saving "💰 Estimated monthly cost: $15-20 vs $50 for full production setup"
    print_cost_saving "🌐 Remote access: Enabled from anywhere on internet"
    
    print_header "Next Steps"
    print_status "1. Update OpenAI API key in AWS Systems Manager:"
    print_status "   aws ssm put-parameter --name '/aura/${ENVIRONMENT}/openai-api-key' --value 'your_actual_api_key' --type 'SecureString' --overwrite --region $AWS_REGION"
    print_status ""
    print_status "2. Deploy the application:"
    print_status "   ./deploy/scripts/deploy.sh $ENVIRONMENT aws"
    print_status ""
    print_status "3. Access your application remotely:"
    print_status "   API Gateway: http://<public-ip>:8000"
    print_status "   Service Desk: http://<public-ip>:8001"
    print_status "   API Docs: http://<public-ip>:8000/docs"
    print_status ""
    print_status "4. Monitor deployment in AWS Console:"
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
    
    print_header "AWS Demo Infrastructure Setup for Aura Project"
    print_status "Environment: $environment"
    print_status "Region: $AWS_REGION"
    print_cost_saving "Cost-optimized setup for demonstration purposes"
    
    # Check prerequisites
    check_prerequisites
    
    # Create infrastructure components (cost-optimized)
    get_default_vpc_info
    create_security_group
    create_ecs_cluster
    create_iam_roles
    create_ssm_parameters
    create_cloudwatch_log_group
    
    # Output results
    output_configuration
}

# Run main function with all arguments
main "$@"
