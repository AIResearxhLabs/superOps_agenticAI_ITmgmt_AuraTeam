#!/bin/bash
# Development Environment Setup Script
# Comprehensive setup for local development

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local prerequisites_met=true
    
    # Check Node.js
    if command_exists node; then
        node_version=$(node --version)
        print_status "Node.js version: $node_version"
        
        # Check if version is 18 or higher
        major_version=$(echo $node_version | sed 's/v//' | cut -d. -f1)
        if [ "$major_version" -lt 18 ]; then
            print_error "Node.js version 18 or higher is required. Current: $node_version"
            prerequisites_met=false
        fi
    else
        print_error "Node.js is not installed. Please install Node.js 18 or higher."
        prerequisites_met=false
    fi
    
    # Check npm
    if command_exists npm; then
        npm_version=$(npm --version)
        print_status "npm version: $npm_version"
    else
        print_error "npm is not installed. Please install npm."
        prerequisites_met=false
    fi
    
    # Check Python
    if command_exists python3; then
        python_version=$(python3 --version)
        print_status "Python version: $python_version"
    elif command_exists python; then
        python_version=$(python --version)
        print_status "Python version: $python_version"
    else
        print_error "Python is not installed. Please install Python 3.8 or higher."
        prerequisites_met=false
    fi
    
    # Check Docker
    if command_exists docker; then
        docker_version=$(docker --version)
        print_status "Docker version: $docker_version"
        
        # Check if Docker daemon is running
        if ! docker info >/dev/null 2>&1; then
            print_error "Docker daemon is not running. Please start Docker Desktop."
            prerequisites_met=false
        fi
    else
        print_error "Docker is not installed. Please install Docker."
        prerequisites_met=false
    fi
    
    # Check Docker Compose
    if command_exists docker-compose; then
        compose_version=$(docker-compose --version)
        print_status "Docker Compose version: $compose_version"
    else
        print_error "Docker Compose is not installed. Please install Docker Compose."
        prerequisites_met=false
    fi
    
    # Check Git
    if command_exists git; then
        git_version=$(git --version)
        print_status "Git version: $git_version"
    else
        print_error "Git is not installed. Please install Git."
        prerequisites_met=false
    fi
    
    if [ "$prerequisites_met" = false ]; then
        print_error "Prerequisites not met. Please install the required software."
        exit 1
    fi
    
    print_status "All prerequisites met ✓"
}

# Function to setup Python virtual environment
setup_python_env() {
    print_header "Setting up Python Environment"
    
    cd aura-backend
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        print_status "Creating Python virtual environment..."
        python3 -m venv venv || python -m venv venv
    else
        print_status "Python virtual environment already exists"
    fi
    
    # Activate virtual environment
    print_status "Activating virtual environment..."
    source venv/bin/activate
    
    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip
    
    # Install dependencies
    print_status "Installing Python dependencies..."
    pip install -r api-gateway/requirements.txt
    pip install -r service-desk-host/requirements.txt
    
    # Install development dependencies
    print_status "Installing development dependencies..."
    pip install flake8 black isort pytest pytest-cov safety mypy
    
    cd ..
    print_status "Python environment setup complete ✓"
}

# Function to setup Node.js environment
setup_node_env() {
    print_header "Setting up Node.js Environment"
    
    cd aura-frontend
    
    # Install dependencies
    print_status "Installing Node.js dependencies..."
    npm install
    
    # Install global development tools
    print_status "Installing global development tools..."
    npm install -g concurrently cross-env
    
    cd ..
    print_status "Node.js environment setup complete ✓"
}

# Function to setup environment files
setup_env_files() {
    print_header "Setting up Environment Files"
    
    # Backend environment file
    if [ ! -f "aura-backend/.env" ]; then
        print_status "Creating backend .env file from template..."
        cp aura-backend/.env.example aura-backend/.env
        print_warning "Please update aura-backend/.env with your OpenAI API key"
    else
        print_status "Backend .env file already exists"
    fi
    
    # Create development environment files
    mkdir -p deploy/environments/dev
    if [ ! -f "deploy/environments/dev/.env" ]; then
        print_status "Creating development environment file..."
        cat > deploy/environments/dev/.env << EOF
# Development Environment Configuration
ENVIRONMENT=dev
OPENAI_API_KEY=your_openai_api_key_here
DATABASE_URL=postgresql://aura_user:aura_password@localhost:5432/aura_servicedesk
MONGODB_URL=mongodb://localhost:27017/aura_servicedesk
REDIS_URL=redis://localhost:6379
API_GATEWAY_URL=http://localhost:8000
SERVICE_DESK_URL=http://localhost:8001
FRONTEND_URL=http://localhost:3000
JWT_SECRET=your_jwt_secret_here
LOG_LEVEL=INFO
EOF
        print_warning "Please update deploy/environments/dev/.env with your actual configuration"
    fi
    
    print_status "Environment files setup complete ✓"
}

# Function to setup Docker environment
setup_docker_env() {
    print_header "Setting up Docker Environment"
    
    # Pull base images
    print_status "Pulling required Docker images..."
    docker pull postgres:13
    docker pull mongo:5
    docker pull redis:7
    docker pull rabbitmq:3-management
    
    # Build local images
    print_status "Building application Docker images..."
    docker-compose -f deploy/environments/local/docker-compose.yml build
    
    print_status "Docker environment setup complete ✓"
}

# Function to run initial tests
run_initial_tests() {
    print_header "Running Initial Tests"
    
    # Test Python environment
    print_status "Testing Python environment..."
    cd aura-backend
    source venv/bin/activate
    python -c "import fastapi; import uvicorn; print('Backend dependencies OK')"
    
    # Test Node.js environment
    print_status "Testing Node.js environment..."
    cd ../aura-frontend
    npm run build
    print_status "Frontend build successful"
    
    cd ..
    print_status "Initial tests complete ✓"
}

# Function to create helpful scripts
create_helper_scripts() {
    print_header "Creating Helper Scripts"
    
    mkdir -p scripts
    
    # Quick start script
    cat > scripts/quick-start.sh << 'EOF'
#!/bin/bash
# Quick Start Script - Start all services

echo "🚀 Starting Aura Development Environment..."

# Start Docker services
echo "📦 Starting Docker services..."
docker-compose -f deploy/environments/local/docker-compose.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to initialize..."
sleep 30

# Check health
echo "🔍 Checking service health..."
curl -s http://localhost:8000/health && echo " - API Gateway: ✓"
curl -s http://localhost:8001/health && echo " - Service Desk: ✓"

echo "✅ All services are running!"
echo "🌐 Access the application:"
echo "  - Frontend: http://localhost:3000 (start with: npm start)"
echo "  - API Docs: http://localhost:8000/docs"
echo "  - API Gateway: http://localhost:8000"
echo "  - Service Desk: http://localhost:8001"
EOF

    # Stop script
    cat > scripts/stop-all.sh << 'EOF'
#!/bin/bash
# Stop All Services Script

echo "🛑 Stopping all Aura services..."

# Stop Docker services
docker-compose -f deploy/environments/local/docker-compose.yml down

# Kill any remaining processes
pkill -f "python.*main.py" || true
pkill -f "npm start" || true

echo "✅ All services stopped!"
EOF

    # Health check script
    cat > scripts/health-check.sh << 'EOF'
#!/bin/bash
# Health Check Script

echo "🔍 Checking Aura service health..."

# Check API Gateway
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ API Gateway: Healthy"
else
    echo "❌ API Gateway: Not responding"
fi

# Check Service Desk
if curl -s http://localhost:8001/health > /dev/null; then
    echo "✅ Service Desk: Healthy"
else
    echo "❌ Service Desk: Not responding"
fi

# Check Frontend (if running)
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ Frontend: Running"
else
    echo "ℹ️  Frontend: Not running (start with: npm start)"
fi

# Check Docker services
echo ""
echo "📦 Docker Services Status:"
docker-compose -f deploy/environments/local/docker-compose.yml ps
EOF

    # Make scripts executable
    chmod +x scripts/*.sh
    
    print_status "Helper scripts created ✓"
}

# Function to display next steps
display_next_steps() {
    print_header "Setup Complete!"
    
    print_status "🎉 Development environment setup successful!"
    echo ""
    print_status "📋 Next Steps:"
    echo "  1. Update your OpenAI API key in aura-backend/.env"
    echo "  2. Start the development environment:"
    echo "     ./scripts/quick-start.sh"
    echo "  3. Start the frontend (in a new terminal):"
    echo "     npm start"
    echo "  4. Access the application at http://localhost:3000"
    echo ""
    print_status "🛠️  Useful Commands:"
    echo "  - Quick start: ./scripts/quick-start.sh"
    echo "  - Health check: ./scripts/health-check.sh"
    echo "  - Stop all: ./scripts/stop-all.sh"
    echo "  - Run tests: npm test"
    echo "  - Lint code: npm run lint"
    echo "  - View logs: npm run dev:logs"
    echo ""
    print_status "📚 Documentation:"
    echo "  - Main README: README.md"
    echo "  - Backend docs: aura-backend/README_STARTUP.md"
    echo "  - API docs: http://localhost:8000/docs (after starting)"
}

# Main function
main() {
    print_header "Aura Development Environment Setup"
    
    # Change to project root
    cd "$(dirname "$0")/.."
    
    # Run setup steps
    check_prerequisites
    setup_python_env
    setup_node_env
    setup_env_files
    setup_docker_env
    run_initial_tests
    create_helper_scripts
    display_next_steps
}

# Run main function
main "$@"
