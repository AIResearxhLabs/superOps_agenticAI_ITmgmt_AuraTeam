#!/bin/bash
# Master script to populate all synthetic data for Aura application
# This script coordinates the generation of all required test data

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}➜${NC} $1"
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

print_header "Aura Synthetic Data Population"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3.8 or higher."
    exit 1
fi

print_success "Python 3 found: $(python3 --version)"

# Check if required dependencies are installed
print_info "Checking dependencies..."
if ! python3 -c "import faker" 2>/dev/null; then
    print_info "Installing faker library..."
    pip3 install faker --quiet || pip install faker --quiet
fi
print_success "All dependencies available"

echo ""
print_header "Step 1: Generate Enhanced Tickets"
print_info "Generating 50-75 tickets with realistic data..."

if [ -f "generate_enhanced_tickets.py" ]; then
    python3 generate_enhanced_tickets.py
    print_success "Tickets generated"
else
    print_error "generate_enhanced_tickets.py not found, skipping..."
fi

echo ""
print_header "Step 2: Generate Infrastructure Data"
print_info "Creating agent profiles, performance metrics, and workload data..."

if [ -f "generate_infrastructure_data.py" ]; then
    python3 generate_infrastructure_data.py
    print_success "Infrastructure data generated"
else
    print_error "generate_infrastructure_data.py not found, skipping..."
fi

echo ""
print_header "Step 3: Generate Security Data"
print_info "Creating security incidents, scores, and alerts..."

if [ -f "generate_security_data.py" ]; then
    python3 generate_security_data.py
    print_success "Security data generated"
else
    print_error "generate_security_data.py not found, skipping..."
fi

echo ""
print_header "Step 4: Populate Knowledge Base"
print_info "Creating knowledge base articles..."

if [ -f "populate_knowledge_base.py" ]; then
    python3 populate_knowledge_base.py
    print_success "Knowledge base populated"
else
    print_error "populate_knowledge_base.py not found, skipping..."
fi

echo ""
print_header "Data Generation Summary"

# Count generated files
FILES_GENERATED=0
[ -f "sample_tickets.json" ] && FILES_GENERATED=$((FILES_GENERATED + 1)) && print_success "Tickets: sample_tickets.json"
[ -f "infrastructure_data.json" ] && FILES_GENERATED=$((FILES_GENERATED + 1)) && print_success "Infrastructure: infrastructure_data.json"
[ -f "security_data.json" ] && FILES_GENERATED=$((FILES_GENERATED + 1)) && print_success "Security: security_data.json"

echo ""
print_info "Total data files generated: $FILES_GENERATED"

# Check if data needs to be loaded into database
echo ""
print_header "Database Loading"
print_info "To load this data into the database:"
print_info "  1. Start the application containers"
print_info "  2. Data will be automatically loaded on first startup"
print_info "  3. Or manually load using the service-desk-host API"

echo ""
print_success "Data population complete!"
print_info "All synthetic data is ready for development and testing."
