#!/bin/bash
# Pre-commit Hook Script
# Runs code quality checks before allowing commits

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

# Function to check staged files
check_staged_files() {
    print_header "Pre-commit Code Quality Checks"
    
    # Get staged files
    staged_files=($(git diff --cached --name-only))
    
    if [ ${#staged_files[@]} -eq 0 ]; then
        print_warning "No staged files found"
        return 0
    fi
    
    print_status "Checking ${#staged_files[@]} staged files..."
    
    # Check for Python files
    python_files=($(printf '%s\n' "${staged_files[@]}" | grep '\.py$' || true))
    # Check for JavaScript/TypeScript files
    js_files=($(printf '%s\n' "${staged_files[@]}" | grep -E '\.(js|jsx|ts|tsx)$' || true))
    # Check for sensitive files
    sensitive_files=($(printf '%s\n' "${staged_files[@]}" | grep -E '\.(env|key|pem|p12|pfx)$' || true))
    
    # Block sensitive files
    if [ ${#sensitive_files[@]} -gt 0 ]; then
        print_error "Sensitive files detected in commit:"
        for file in "${sensitive_files[@]}"; do
            echo "  - $file"
        done
        print_error "Please remove sensitive files before committing"
        exit 1
    fi
    
    echo "Files to be committed:"
    for file in "${staged_files[@]}"; do
        echo "  - $file"
    done
}

# Function to run Python checks
run_python_checks() {
    if [ ${#python_files[@]} -eq 0 ]; then
        return 0
    fi
    
    print_header "Python Code Quality Checks"
    
    cd aura-backend
    
    # Activate virtual environment if it exists
    if [ -d "venv" ]; then
        source venv/bin/activate
    else
        print_warning "Python virtual environment not found. Some checks may fail."
    fi
    
    # Check if required tools are installed
    command -v black >/dev/null 2>&1 || pip install black
    command -v isort >/dev/null 2>&1 || pip install isort
    command -v flake8 >/dev/null 2>&1 || pip install flake8
    
    local python_checks_passed=true
    
    # Run Black formatter check
    print_status "Running Black formatter check..."
    if ! black --check --diff "${python_files[@]/#/../}"; then
        print_error "Black formatting issues found. Run 'black .' to fix."
        python_checks_passed=false
    fi
    
    # Run isort import sorting check
    print_status "Running isort import sorting check..."
    if ! isort --check-only --diff "${python_files[@]/#/../}"; then
        print_error "Import sorting issues found. Run 'isort .' to fix."
        python_checks_passed=false
    fi
    
    # Run Flake8 linting
    print_status "Running Flake8 linting..."
    if ! flake8 "${python_files[@]/#/../}" --max-line-length=88 --extend-ignore=E203,W503; then
        print_error "Flake8 linting issues found."
        python_checks_passed=false
    fi
    
    cd ..
    
    if [ "$python_checks_passed" = false ]; then
        print_error "Python code quality checks failed!"
        print_status "Fix the issues above or run: npm run lint:backend:fix"
        exit 1
    fi
    
    print_status "Python code quality checks passed ✓"
}

# Function to run JavaScript/TypeScript checks
run_js_checks() {
    if [ ${#js_files[@]} -eq 0 ]; then
        return 0
    fi
    
    print_header "JavaScript/TypeScript Code Quality Checks"
    
    cd aura-frontend
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        print_status "Installing frontend dependencies..."
        npm install
    fi
    
    local js_checks_passed=true
    
    # Run ESLint
    print_status "Running ESLint..."
    if ! npm run lint -- --max-warnings=0 "${js_files[@]/#/../}"; then
        print_error "ESLint issues found."
        print_status "Try running: npm run lint:fix"
        js_checks_passed=false
    fi
    
    # Check TypeScript compilation (if applicable)
    if [ -f "tsconfig.json" ]; then
        print_status "Checking TypeScript compilation..."
        if ! npx tsc --noEmit; then
            print_error "TypeScript compilation errors found."
            js_checks_passed=false
        fi
    fi
    
    cd ..
    
    if [ "$js_checks_passed" = false ]; then
        print_error "JavaScript/TypeScript code quality checks failed!"
        print_status "Fix the issues above or run: npm run lint:frontend:fix"
        exit 1
    fi
    
    print_status "JavaScript/TypeScript code quality checks passed ✓"
}

# Function to run security checks
run_security_checks() {
    print_header "Security Checks"
    
    # Check for potential secrets in staged files
    print_status "Scanning for potential secrets..."
    
    local secrets_found=false
    
    for file in "${staged_files[@]}"; do
        if [ -f "$file" ]; then
            # Check for common secret patterns
            if grep -qE "(api_key|password|secret|token|private_key)" "$file" 2>/dev/null; then
                # Skip if it's in a test file or example file
                if [[ ! "$file" =~ (test|spec|example|sample) ]]; then
                    print_warning "Potential secret found in $file"
                    grep -n -E "(api_key|password|secret|token|private_key)" "$file" || true
                    secrets_found=true
                fi
            fi
            
            # Check for hardcoded URLs or IPs
            if grep -qE "https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" "$file" 2>/dev/null; then
                print_warning "Hardcoded IP address found in $file"
            fi
        fi
    done
    
    if [ "$secrets_found" = true ]; then
        print_warning "Potential secrets detected. Please review before committing."
        print_status "If these are false positives, you can proceed with commit."
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Commit aborted by user"
            exit 1
        fi
    fi
}

# Function to run basic tests
run_basic_tests() {
    print_header "Basic Tests"
    
    # Only run if test files are staged or core files changed
    local should_run_tests=false
    
    for file in "${staged_files[@]}"; do
        if [[ "$file" =~ (test|spec)\.py$ ]] || [[ "$file" =~ (test|spec)\.(js|jsx|ts|tsx)$ ]]; then
            should_run_tests=true
            break
        fi
        if [[ "$file" =~ (main\.py|App\.(js|jsx|ts|tsx))$ ]]; then
            should_run_tests=true
            break
        fi
    done
    
    if [ "$should_run_tests" = false ]; then
        print_status "Skipping tests (no test files or core files changed)"
        return 0
    fi
    
    # Run quick Python tests if Python files changed
    if [ ${#python_files[@]} -gt 0 ]; then
        print_status "Running quick Python tests..."
        cd aura-backend
        if [ -d "venv" ]; then
            source venv/bin/activate
        fi
        
        # Install pytest if not present
        command -v pytest >/dev/null 2>&1 || pip install pytest
        
        # Run tests with timeout
        if timeout 60 pytest tests/ -v --tb=short -x; then
            print_status "Python tests passed ✓"
        else
            print_warning "Python tests failed or timed out ⚠️"
            read -p "Continue with commit anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        cd ..
    fi
    
    # Run quick JavaScript tests if JS files changed
    if [ ${#js_files[@]} -gt 0 ]; then
        print_status "Running quick JavaScript tests..."
        cd aura-frontend
        
        # Run tests with timeout
        if timeout 60 npm test -- --watchAll=false --passWithNoTests; then
            print_status "JavaScript tests passed ✓"
        else
            print_warning "JavaScript tests failed or timed out ⚠️"
            read -p "Continue with commit anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        cd ..
    fi
}

# Function to check commit message
check_commit_message() {
    print_header "Commit Message Check"
    
    # Get commit message
    commit_msg_file="$1"
    if [ -z "$commit_msg_file" ] || [ ! -f "$commit_msg_file" ]; then
        print_status "Commit message check skipped (not available in this context)"
        return 0
    fi
    
    commit_msg=$(cat "$commit_msg_file")
    
    # Check for conventional commit format
    if [[ ! "$commit_msg" =~ ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?:\ .+ ]]; then
        print_warning "Commit message doesn't follow conventional commit format"
        print_status "Expected format: type(scope): description"
        print_status "Examples:"
        print_status "  feat(auth): add OAuth integration"
        print_status "  fix(api): resolve timeout issue"
        print_status "  docs: update README with deployment steps"
        
        read -p "Continue with current message? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Please update your commit message and try again"
            exit 1
        fi
    fi
}

# Main function
main() {
    cd "$(git rev-parse --show-toplevel)"
    
    check_staged_files
    run_security_checks
    run_python_checks
    run_js_checks
    run_basic_tests
    check_commit_message "$1"
    
    print_header "Pre-commit Checks Complete"
    print_status "🎉 All checks passed! Ready to commit."
}

# Run main function
main "$@"
