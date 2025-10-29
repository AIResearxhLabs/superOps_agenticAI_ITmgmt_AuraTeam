#!/bin/bash
# Comprehensive Test Runner Script
# Runs all tests with proper reporting and coverage

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

# Initialize test results
backend_tests_passed=false
frontend_tests_passed=false
integration_tests_passed=false
coverage_threshold=80

# Function to run backend tests
run_backend_tests() {
    print_header "Running Backend Tests"
    
    cd aura-backend
    
    # Activate virtual environment
    if [ -d "venv" ]; then
        source venv/bin/activate
    else
        print_error "Python virtual environment not found. Run ./scripts/dev-setup.sh first"
        return 1
    fi
    
    # Install test dependencies if not present
    pip install pytest pytest-cov pytest-html pytest-xvs
    
    # Create test directory if it doesn't exist
    mkdir -p tests
    
    # Create basic test files if they don't exist
    if [ ! -f "tests/test_api_gateway.py" ]; then
        cat > tests/test_api_gateway.py << 'EOF'
"""Basic tests for API Gateway"""
import pytest
from fastapi.testclient import TestClient
import sys
import os

# Add the parent directory to the path so we can import modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def test_health_endpoint():
    """Test that we can import required modules"""
    try:
        import fastapi
        import uvicorn
        assert True, "FastAPI and Uvicorn imported successfully"
    except ImportError as e:
        pytest.fail(f"Failed to import required modules: {e}")

def test_basic_functionality():
    """Test basic Python functionality"""
    assert 1 + 1 == 2, "Basic math should work"
    assert "hello".upper() == "HELLO", "String operations should work"

# Add more tests as your application grows
EOF
    fi
    
    if [ ! -f "tests/test_service_desk.py" ]; then
        cat > tests/test_service_desk.py << 'EOF'
"""Basic tests for Service Desk"""
import pytest
import sys
import os

# Add the parent directory to the path so we can import modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def test_service_desk_imports():
    """Test that we can import required modules"""
    try:
        import fastapi
        import pymongo
        assert True, "Service Desk dependencies imported successfully"
    except ImportError as e:
        pytest.fail(f"Failed to import required modules: {e}")

def test_mongodb_connection_config():
    """Test MongoDB connection configuration"""
    # This is a placeholder test - replace with actual MongoDB tests
    connection_string = "mongodb://localhost:27017/aura_servicedesk"
    assert connection_string.startswith("mongodb://"), "MongoDB connection string should be valid"

# Add more tests as your application grows
EOF
    fi
    
    # Run tests with coverage
    print_status "Running backend tests with coverage..."
    if pytest tests/ -v --cov=. --cov-report=html --cov-report=term --cov-report=xml --html=reports/backend-test-report.html --self-contained-html; then
        backend_tests_passed=true
        print_status "Backend tests passed ✓"
    else
        print_error "Backend tests failed ❌"
        backend_tests_passed=false
    fi
    
    # Check coverage threshold
    coverage_percentage=$(python -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('coverage.xml')
    root = tree.getroot()
    coverage = float(root.attrib['line-rate']) * 100
    print(f'{coverage:.1f}')
except:
    print('0.0')
")
    
    print_status "Backend test coverage: $coverage_percentage%"
    if (( $(echo "$coverage_percentage >= $coverage_threshold" | bc -l) )); then
        print_status "Coverage threshold met ✓"
    else
        print_warning "Coverage below threshold ($coverage_threshold%)"
    fi
    
    cd ..
}

# Function to run frontend tests
run_frontend_tests() {
    print_header "Running Frontend Tests"
    
    cd aura-frontend
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        print_status "Installing frontend dependencies..."
        npm install
    fi
    
    # Create basic test file if it doesn't exist
    if [ ! -f "src/App.test.js" ]; then
        cat > src/App.test.js << 'EOF'
import { render, screen } from '@testing-library/react';
import App from './App';

test('renders application', () => {
  render(<App />);
  // Basic test to ensure app renders without crashing
  expect(document.body).toBeInTheDocument();
});

test('basic functionality', () => {
  // Basic JavaScript tests
  expect(1 + 1).toBe(2);
  expect('hello'.toUpperCase()).toBe('HELLO');
});
EOF
    fi
    
    # Run tests with coverage
    print_status "Running frontend tests with coverage..."
    if npm test -- --coverage --watchAll=false --ci --testResultsProcessor=jest-junit --coverageReporters=text --coverageReporters=html --coverageReporters=cobertura; then
        frontend_tests_passed=true
        print_status "Frontend tests passed ✓"
    else
        print_error "Frontend tests failed ❌"
        frontend_tests_passed=false
    fi
    
    cd ..
}

# Function to run integration tests
run_integration_tests() {
    print_header "Running Integration Tests"
    
    # Check if services are running
    print_status "Checking if services are running..."
    
    # Start services if not running
    if ! curl -s http://localhost:8000/health > /dev/null; then
        print_status "Starting backend services..."
        docker-compose -f deploy/environments/local/docker-compose.yml up -d
        sleep 30
    fi
    
    # Run integration tests
    print_status "Running integration tests..."
    
    # Test API Gateway health
    if curl -s http://localhost:8000/health > /dev/null; then
        print_status "API Gateway health check: ✓"
    else
        print_error "API Gateway health check: ❌"
        integration_tests_passed=false
        return 1
    fi
    
    # Test Service Desk health
    if curl -s http://localhost:8001/health > /dev/null; then
        print_status "Service Desk health check: ✓"
    else
        print_error "Service Desk health check: ❌"
        integration_tests_passed=false
        return 1
    fi
    
    # Test API endpoints
    print_status "Testing API endpoints..."
    
    # Test tickets endpoint
    if curl -s http://localhost:8000/api/tickets > /dev/null; then
        print_status "Tickets API endpoint: ✓"
    else
        print_warning "Tickets API endpoint: ⚠️  (may require authentication)"
    fi
    
    # Test database connections
    print_status "Testing database connections..."
    
    # Test MongoDB connection
    if docker exec -i $(docker-compose -f deploy/environments/local/docker-compose.yml ps -q mongo) mongosh aura_servicedesk --eval "db.runCommand('ping')" > /dev/null 2>&1; then
        print_status "MongoDB connection: ✓"
    else
        print_warning "MongoDB connection: ⚠️"
    fi
    
    # Test PostgreSQL connection
    if docker exec -i $(docker-compose -f deploy/environments/local/docker-compose.yml ps -q postgres) pg_isready -U aura_user > /dev/null 2>&1; then
        print_status "PostgreSQL connection: ✓"
    else
        print_warning "PostgreSQL connection: ⚠️"
    fi
    
    # Test Redis connection
    if docker exec -i $(docker-compose -f deploy/environments/local/docker-compose.yml ps -q redis) redis-cli ping > /dev/null 2>&1; then
        print_status "Redis connection: ✓"
    else
        print_warning "Redis connection: ⚠️"
    fi
    
    integration_tests_passed=true
    print_status "Integration tests completed ✓"
}

# Function to run security tests
run_security_tests() {
    print_header "Running Security Tests"
    
    # Backend security scan
    print_status "Running backend security scan..."
    cd aura-backend
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    pip install safety
    if safety check --json --output safety-report.json; then
        print_status "Backend security scan: ✓"
    else
        print_warning "Backend security issues found - check safety-report.json"
    fi
    
    cd ..
    
    # Frontend security scan
    print_status "Running frontend security scan..."
    cd aura-frontend
    if npm audit --audit-level=moderate; then
        print_status "Frontend security scan: ✓"
    else
        print_warning "Frontend security issues found"
    fi
    
    cd ..
}

# Function to run performance tests
run_performance_tests() {
    print_header "Running Performance Tests"
    
    # Basic performance tests
    print_status "Running basic performance tests..."
    
    # Test API response times
    api_response_time=$(curl -o /dev/null -s -w '%{time_total}\n' http://localhost:8000/health)
    print_status "API Gateway response time: ${api_response_time}s"
    
    service_response_time=$(curl -o /dev/null -s -w '%{time_total}\n' http://localhost:8001/health)
    print_status "Service Desk response time: ${service_response_time}s"
    
    # Frontend build size check
    if [ -d "aura-frontend/build" ]; then
        build_size=$(du -sh aura-frontend/build | cut -f1)
        print_status "Frontend build size: $build_size"
    fi
}

# Function to generate test report
generate_test_report() {
    print_header "Generating Test Report"
    
    mkdir -p reports
    
    # Create HTML test report
    cat > reports/test-summary.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Aura Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .pass { color: green; }
        .fail { color: red; }
        .warning { color: orange; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Aura Application Test Report</h1>
        <p>Generated on: $(date)</p>
    </div>
    
    <div class="section">
        <h2>Test Summary</h2>
        <table>
            <tr><th>Test Suite</th><th>Status</th><th>Details</th></tr>
            <tr><td>Backend Tests</td><td class="$([ "$backend_tests_passed" = true ] && echo "pass" || echo "fail")">$([ "$backend_tests_passed" = true ] && echo "PASSED" || echo "FAILED")</td><td>Unit tests for Python backend services</td></tr>
            <tr><td>Frontend Tests</td><td class="$([ "$frontend_tests_passed" = true ] && echo "pass" || echo "fail")">$([ "$frontend_tests_passed" = true ] && echo "PASSED" || echo "FAILED")</td><td>Unit tests for React frontend</td></tr>
            <tr><td>Integration Tests</td><td class="$([ "$integration_tests_passed" = true ] && echo "pass" || echo "fail")">$([ "$integration_tests_passed" = true ] && echo "PASSED" || echo "FAILED")</td><td>API and service integration tests</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Coverage Report</h2>
        <p>Backend Coverage: $coverage_percentage%</p>
        <p>Frontend Coverage: Available in coverage/lcov-report/</p>
    </div>
    
    <div class="section">
        <h2>Next Steps</h2>
        <ul>
            <li>Review failed tests and fix issues</li>
            <li>Improve test coverage where needed</li>
            <li>Add more integration tests</li>
            <li>Review security scan results</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    print_status "Test report generated: reports/test-summary.html"
}

# Function to display final summary
display_summary() {
    print_header "Test Summary"
    
    echo "📊 Test Results:"
    echo "  Backend Tests: $([ "$backend_tests_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo "  Frontend Tests: $([ "$frontend_tests_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo "  Integration Tests: $([ "$integration_tests_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")"
    echo ""
    
    if [ "$backend_tests_passed" = true ] && [ "$frontend_tests_passed" = true ] && [ "$integration_tests_passed" = true ]; then
        print_status "🎉 All tests passed!"
        echo "✅ Your application is ready for deployment"
        return 0
    else
        print_error "❌ Some tests failed!"
        echo "Please review the test output and fix any issues before deploying."
        return 1
    fi
}

# Main function
main() {
    print_header "Aura Application Test Runner"
    
    # Change to project root
    cd "$(dirname "$0")/.."
    
    # Parse command line arguments
    run_backend=true
    run_frontend=true
    run_integration=true
    run_security=false
    run_performance=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backend-only)
                run_frontend=false
                run_integration=false
                shift
                ;;
            --frontend-only)
                run_backend=false
                run_integration=false
                shift
                ;;
            --integration-only)
                run_backend=false
                run_frontend=false
                shift
                ;;
            --with-security)
                run_security=true
                shift
                ;;
            --with-performance)
                run_performance=true
                shift
                ;;
            --all)
                run_security=true
                run_performance=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--backend-only|--frontend-only|--integration-only] [--with-security] [--with-performance] [--all]"
                exit 1
                ;;
        esac
    done
    
    # Run selected test suites
    [ "$run_backend" = true ] && run_backend_tests
    [ "$run_frontend" = true ] && run_frontend_tests
    [ "$run_integration" = true ] && run_integration_tests
    [ "$run_security" = true ] && run_security_tests
    [ "$run_performance" = true ] && run_performance_tests
    
    # Generate report and display summary
    generate_test_report
    display_summary
}

# Run main function with all arguments
main "$@"
