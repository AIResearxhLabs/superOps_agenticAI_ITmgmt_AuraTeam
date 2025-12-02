#!/bin/bash

# Aura IT Management System - Local Docker Deployment Script
# This script builds and deploys the complete stack with linux/amd64 architecture for AWS compatibility

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    print_status "Checking Docker availability..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Function to check if Docker Compose is available
check_docker_compose() {
    print_status "Checking Docker Compose availability..."
    if ! docker compose version > /dev/null 2>&1; then
        print_error "Docker Compose is not available. Please install Docker Compose and try again."
        exit 1
    fi
    print_success "Docker Compose is available"
}

# Function to create .env file if it doesn't exist
create_env_file() {
    print_status "Setting up environment variables..."
    
    if [ ! -f ".env" ]; then
        print_warning ".env file not found. Creating default .env file..."
        cat > .env << EOF
# OpenAI API Configuration
OPENAI_API_KEY=your_openai_api_key_here

# Database Configuration
POSTGRES_USER=aura_user
POSTGRES_PASSWORD=aura_password
POSTGRES_DB=aura_servicedesk

# Redis Configuration
REDIS_URL=redis://redis:6379

# RabbitMQ Configuration
RABBITMQ_DEFAULT_USER=guest
RABBITMQ_DEFAULT_PASS=guest

# Application Configuration
ENVIRONMENT=local
DEBUG=true
AI_CATEGORIZATION_ENABLED=true

# CORS Configuration
CORS_ORIGINS=http://localhost:3000,http://frontend:80
EOF
        print_warning "Please update the OPENAI_API_KEY in .env file for AI features to work properly"
    else
        print_success ".env file already exists"
    fi
}

# Function to clean up previous containers and images
cleanup() {
    print_status "Cleaning up previous containers and images..."
    
    # Stop and remove containers from current compose file
    docker compose -f deploy/environments/local/docker-compose.yml down --remove-orphans 2>/dev/null || true
    
    # Stop and remove any conflicting containers that might be using the same ports
    print_status "Stopping conflicting containers on required ports..."
    
    # Find and stop containers using our required ports
    local ports_to_check=(3000 5432 5672 6379 8000 8001 15672 27017)
    
    for port in "${ports_to_check[@]}"; do
        local container_ids=$(docker ps --filter "publish=$port" --format "{{.ID}}" 2>/dev/null || true)
        if [ ! -z "$container_ids" ]; then
            print_warning "Found containers using port $port, stopping them..."
            echo "$container_ids" | xargs -r docker stop 2>/dev/null || true
            echo "$container_ids" | xargs -r docker rm 2>/dev/null || true
        fi
    done
    
    # Also stop any containers with aura-backend prefix (old deployment)
    local aura_containers=$(docker ps -a --filter "name=aura-backend" --format "{{.ID}}" 2>/dev/null || true)
    if [ ! -z "$aura_containers" ]; then
        print_warning "Found old aura-backend containers, stopping and removing them..."
        echo "$aura_containers" | xargs -r docker stop 2>/dev/null || true
        echo "$aura_containers" | xargs -r docker rm 2>/dev/null || true
    fi
    
    # Clean up any dangling networks
    docker network prune -f 2>/dev/null || true
    
    # Remove unused images (optional - comment out if you want to keep images for faster rebuilds)
    # docker image prune -f 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Function to build images
build_images() {
    print_status "Building Docker images with linux/amd64 architecture..."
    
    # Build images with explicit platform specification (without --no-cache for better network resilience)
    docker compose -f deploy/environments/local/docker-compose.yml build \
        --build-arg BUILDPLATFORM=linux/amd64 \
        --build-arg TARGETPLATFORM=linux/amd64
    
    print_success "All images built successfully"
}

# Function to start services
start_services() {
    print_status "Starting all services..."
    
    # Start services in the correct order
    docker compose -f deploy/environments/local/docker-compose.yml up -d
    
    print_success "All services started"
}

# Function to wait for services to be healthy
wait_for_services() {
    print_status "Waiting for services to become healthy..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Health check attempt $attempt/$max_attempts..."
        
        # Check if all services are healthy
        local healthy_services=$(docker compose -f deploy/environments/local/docker-compose.yml ps --format json | jq -r 'select(.Health == "healthy") | .Name' | wc -l)
        local total_services=$(docker compose -f deploy/environments/local/docker-compose.yml ps --format json | jq -r '.Name' | wc -l)
        
        if [ "$healthy_services" -eq "$total_services" ] && [ "$total_services" -gt 0 ]; then
            print_success "All services are healthy!"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Services did not become healthy within expected time"
            print_status "Checking service status..."
            docker compose -f deploy/environments/local/docker-compose.yml ps
            exit 1
        fi
        
        sleep 10
        ((attempt++))
    done
}

# Function to show service status
show_status() {
    print_status "Service Status:"
    docker compose -f deploy/environments/local/docker-compose.yml ps
    
    echo ""
    print_status "Service URLs:"
    echo "🌐 Frontend (React):     http://localhost:3000"
    echo "🔧 API Gateway:          http://localhost:8000"
    echo "🎫 Service Desk API:     http://localhost:8001"
    echo "🗄️  PostgreSQL:          localhost:5432"
    echo "📊 MongoDB:              localhost:27017"
    echo "⚡ Redis:                localhost:6379"
    echo "🐰 RabbitMQ Management:  http://localhost:15672 (guest/guest)"
    echo ""
    print_status "Health Check URLs:"
    echo "🔧 API Gateway Health:   http://localhost:8000/health"
    echo "🎫 Service Desk Health:  http://localhost:8001/health"
}

# Function to run tests
run_tests() {
    print_status "Running basic connectivity tests..."
    
    # Test API Gateway
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        print_success "✅ API Gateway is responding"
    else
        print_error "❌ API Gateway is not responding"
    fi
    
    # Test Service Desk
    if curl -f http://localhost:8001/health > /dev/null 2>&1; then
        print_success "✅ Service Desk is responding"
    else
        print_error "❌ Service Desk is not responding"
    fi
    
    # Test Frontend
    if curl -f http://localhost:3000 > /dev/null 2>&1; then
        print_success "✅ Frontend is responding"
    else
        print_error "❌ Frontend is not responding"
    fi
}

# Function to show logs
show_logs() {
    print_status "Recent logs from all services:"
    docker compose -f deploy/environments/local/docker-compose.yml logs --tail=50
}

# Function to start services in dev mode (with hot-reload)
start_dev_mode() {
    print_status "Starting services in DEVELOPMENT MODE with hot-reload..."
    print_warning "This mode is for active development. Use 'deploy' for production testing."
    
    # Stop any production mode containers first
    docker compose -f deploy/environments/local/docker-compose.yml down 2>/dev/null || true
    
    # Start dev mode services
    docker compose -f deploy/environments/local/docker-compose.dev.yml up -d
    
    print_success "All services started in development mode"
    
    echo ""
    print_status "🔥 HOT-RELOAD ENABLED:"
    echo "   • Frontend: Changes to aura-frontend/src/ will auto-reload"
    echo "   • Backend: Changes to aura-backend/ will auto-reload"
    echo "   • No rebuild needed for code changes!"
    echo ""
}

# Function to stop dev mode
stop_dev_mode() {
    print_status "Stopping development mode services..."
    docker compose -f deploy/environments/local/docker-compose.dev.yml down
    print_success "Development mode services stopped"
}

# Function to show dev mode status
show_dev_status() {
    print_status "Development Mode Service Status:"
    docker compose -f deploy/environments/local/docker-compose.dev.yml ps
    
    echo ""
    print_status "Development Mode URLs:"
    echo "🔥 Frontend (React Dev):  http://localhost:3000  [HOT-RELOAD ENABLED]"
    echo "🔧 API Gateway:           http://localhost:8000  [HOT-RELOAD ENABLED]"
    echo "🎫 Service Desk API:      http://localhost:8001  [HOT-RELOAD ENABLED]"
    echo "🗄️  PostgreSQL:           localhost:5432"
    echo "📊 MongoDB:               localhost:27017"
    echo "⚡ Redis:                 localhost:6379"
    echo "🐰 RabbitMQ Management:   http://localhost:15672 (guest/guest)"
    echo ""
    print_status "💡 Tip: Edit files in your local editor and see changes instantly!"
}

# Main deployment function
main() {
    echo "🚀 Aura IT Management System - Local Deployment"
    echo "================================================"
    echo ""
    
    # Parse command line arguments
    case "${1:-deploy}" in
        "dev")
            check_docker
            check_docker_compose
            create_env_file
            cleanup
            start_dev_mode
            sleep 5  # Give services a moment to start
            show_dev_status
            
            echo ""
            print_success "🎉 Development mode started successfully!"
            print_status "Edit your code and see changes instantly without rebuilding!"
            print_status "Use './deploy-local.sh logs' to follow logs"
            print_status "Use './deploy-local.sh stop' to stop all services"
            ;;
        "deploy")
            check_docker
            check_docker_compose
            create_env_file
            cleanup
            build_images
            start_services
            wait_for_services
            show_status
            run_tests
            
            echo ""
            print_success "🎉 Deployment completed successfully!"
            print_status "You can now access the application at http://localhost:3000"
            print_status "Use 'docker compose -f deploy/environments/local/docker-compose.yml logs -f' to follow logs"
            ;;
        "stop")
            print_status "Stopping all services..."
            docker compose -f deploy/environments/local/docker-compose.yml down 2>/dev/null || true
            docker compose -f deploy/environments/local/docker-compose.dev.yml down 2>/dev/null || true
            print_success "All services stopped"
            ;;
        "restart")
            print_status "Restarting all services..."
            # Check which mode is running
            if docker compose -f deploy/environments/local/docker-compose.dev.yml ps --quiet 2>/dev/null | grep -q .; then
                print_status "Detected development mode, restarting in dev mode..."
                docker compose -f deploy/environments/local/docker-compose.dev.yml restart
                show_dev_status
            else
                print_status "Detected production mode, restarting in production mode..."
                docker compose -f deploy/environments/local/docker-compose.yml restart
                wait_for_services
                show_status
            fi
            print_success "All services restarted"
            ;;
        "status")
            # Check which mode is running
            if docker compose -f deploy/environments/local/docker-compose.dev.yml ps --quiet 2>/dev/null | grep -q .; then
                show_dev_status
            else
                show_status
            fi
            ;;
        "logs")
            # Check which mode is running and show appropriate logs
            if docker compose -f deploy/environments/local/docker-compose.dev.yml ps --quiet 2>/dev/null | grep -q .; then
                print_status "Development mode logs:"
                docker compose -f deploy/environments/local/docker-compose.dev.yml logs --tail=50 -f
            else
                print_status "Production mode logs:"
                docker compose -f deploy/environments/local/docker-compose.yml logs --tail=50 -f
            fi
            ;;
        "test")
            run_tests
            ;;
        "clean")
            cleanup
            print_success "Cleanup completed"
            ;;
        *)
            echo "Usage: $0 [dev|deploy|stop|restart|status|logs|test|clean]"
            echo ""
            echo "Commands:"
            echo "  dev      - Start in DEVELOPMENT mode with hot-reload (fast iteration)"
            echo "  deploy   - Build and deploy in PRODUCTION mode (final testing)"
            echo "  stop     - Stop all services (both dev and production)"
            echo "  restart  - Restart services (auto-detects current mode)"
            echo "  status   - Show service status and URLs"
            echo "  logs     - Show and follow logs from all services"
            echo "  test     - Run basic connectivity tests"
            echo "  clean    - Clean up containers and images"
            echo ""
            echo "Quick Start:"
            echo "  For development:  ./deploy-local.sh dev"
            echo "  For testing:      ./deploy-local.sh deploy"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
