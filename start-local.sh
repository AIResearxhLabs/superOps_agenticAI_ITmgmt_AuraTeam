#!/bin/bash
# Quick Start Script for Local Development
# This script provides a simple way to start the entire application locally

set -e

# Color codes for output
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

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_header "🌟 Aura Team - Local Development Startup"

print_status "Starting local development environment..."

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Use the new deployment script for local environment
if [[ -f "deploy/scripts/deploy.sh" ]]; then
    print_status "Using new deployment system..."
    ./deploy/scripts/deploy.sh local
else
    print_warning "New deployment system not found. Using legacy method..."
    
    # Legacy method - use existing docker-compose
    if [[ -f "aura-backend/docker-compose.yml" ]]; then
        cd aura-backend
        print_status "Starting services with Docker Compose..."
        docker-compose up -d --build
        cd ..
        
        print_status "Waiting for services to be ready..."
        sleep 30
        
        print_status "Services started! You can now:"
        print_status "1. Start the frontend: cd aura-frontend && npm install && npm start"
        print_status "2. Access API Gateway: http://localhost:8000"
        print_status "3. Access Service Desk: http://localhost:8001"
        print_status "4. View API Documentation: http://localhost:8000/docs"
    else
        echo "❌ No docker-compose.yml found. Please check your project structure."
        exit 1
    fi
fi

print_status "🎉 Local development environment is ready!"
print_status ""
print_status "Next steps:"
print_status "1. Start the frontend in a new terminal:"
print_status "   cd aura-frontend"
print_status "   npm install"
print_status "   npm start"
print_status ""
print_status "2. Access your application:"
print_status "   - Frontend: http://localhost:3000"
print_status "   - API Gateway: http://localhost:8000"
print_status "   - API Documentation: http://localhost:8000/docs"
print_status ""
print_status "3. To stop all services:"
print_status "   ./deploy/scripts/deploy.sh cleanup local"
