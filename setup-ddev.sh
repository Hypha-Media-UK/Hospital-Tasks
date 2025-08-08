#!/bin/bash

# ============================================================================
# Hospital Tasks - DDEV Setup Script
# ============================================================================

set -e  # Exit on any error

echo "🏥 Hospital Tasks - DDEV Setup"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if DDEV is installed
if ! command -v ddev &> /dev/null; then
    print_error "DDEV not found. Please install DDEV first."
    print_status "Visit: https://ddev.readthedocs.io/en/stable/#installation"
    exit 1
fi

print_status "DDEV found: $(ddev version | head -n1)"

# Stop any existing DDEV project
print_status "Stopping any existing DDEV project..."
ddev stop || true

# Start DDEV
print_status "Starting DDEV..."
ddev start

if [ $? -eq 0 ]; then
    print_success "DDEV started successfully"
else
    print_error "Failed to start DDEV"
    exit 1
fi

# Add Node.js support using DDEV add-on
print_status "Adding Node.js support..."
ddev get ddev/ddev-nodejs || print_warning "Node.js add-on installation failed, will install manually"

# Restart DDEV to apply changes
print_status "Restarting DDEV to apply Node.js support..."
ddev restart

# Install Node.js manually if add-on failed
print_status "Ensuring Node.js is available..."
ddev exec "curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs" || print_warning "Manual Node.js installation failed"

# Verify Node.js installation
NODE_VERSION=$(ddev exec "node --version" 2>/dev/null || echo "not installed")
NPM_VERSION=$(ddev exec "npm --version" 2>/dev/null || echo "not installed")

if [[ "$NODE_VERSION" == "not installed" ]]; then
    print_error "Node.js installation failed"
    print_status "Trying alternative installation method..."
    
    # Alternative: Install Node.js using package manager
    ddev exec "apt-get update && apt-get install -y nodejs npm"
    
    NODE_VERSION=$(ddev exec "node --version" 2>/dev/null || echo "still not installed")
    if [[ "$NODE_VERSION" == "still not installed" ]]; then
        print_error "Could not install Node.js. Please install manually."
        exit 1
    fi
fi

print_success "Node.js version: $NODE_VERSION"
print_success "NPM version: $NPM_VERSION"

# Create database
print_status "Setting up MySQL database..."
ddev mysql -e "DROP DATABASE IF EXISTS hospital_tasks; CREATE DATABASE hospital_tasks CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

if [ $? -eq 0 ]; then
    print_success "Database created successfully"
else
    print_error "Failed to create database"
    exit 1
fi

# Install frontend dependencies
print_status "Installing frontend dependencies..."
ddev exec "npm install"

if [ $? -eq 0 ]; then
    print_success "Frontend dependencies installed"
else
    print_warning "Frontend dependency installation failed"
fi

# Install API dependencies
if [ -f "api/package.json" ]; then
    print_status "Installing API dependencies..."
    ddev exec "cd api && npm install"
    
    if [ $? -eq 0 ]; then
        print_success "API dependencies installed"
    else
        print_warning "API dependency installation failed"
    fi
else
    print_warning "API package.json not found, skipping API dependencies"
fi

# Test database connection
print_status "Testing database connection..."
TABLE_COUNT=$(ddev mysql -e "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'hospital_tasks';" -s -N)

if [ "$TABLE_COUNT" = "1" ]; then
    print_success "Database connection test passed"
else
    print_error "Database connection test failed"
    exit 1
fi

# Final summary
echo ""
print_success "🎉 DDEV setup completed successfully!"
echo "=================================="
echo ""
print_success "✅ DDEV environment is running"
print_success "✅ Node.js and NPM are installed"
print_success "✅ MySQL database created"
print_success "✅ Dependencies installed"
echo ""
echo "🔗 URLs:"
echo "   Frontend: https://hospital-tasks.ddev.site"
echo "   Database: accessible via 'ddev mysql'"
echo ""
echo "🚀 Next steps:"
echo "   1. Import schema: ddev mysql hospital_tasks < mysql-schema.sql"
echo "   2. Import data: ddev mysql hospital_tasks < mysql-data.sql"
echo "   3. Start API: ddev exec 'cd api && npm run dev'"
echo "   4. Start frontend: ddev exec 'npm run dev'"
echo ""
echo "📚 Useful commands:"
echo "   ddev logs -f          # View logs"
echo "   ddev mysql            # Access MySQL"
echo "   ddev ssh              # SSH into container"
echo "   ddev stop             # Stop environment"
